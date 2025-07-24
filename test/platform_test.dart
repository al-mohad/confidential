import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:confidential/confidential.dart';

void main() {
  group('Platform Support Tests', () {
    setUp(() {
      // Clear platform detection cache before each test
      PlatformDetector.clearCache();
      WebAwareObfuscatedValue.resetWarningState();
    });

    group('Platform Detection', () {
      test('detects platform consistently', () {
        final platform1 = PlatformDetector.detectPlatform();
        final platform2 = PlatformDetector.detectPlatform();
        
        expect(platform1, equals(platform2));
        expect(platform1, isA<ConfidentialPlatform>());
      });

      test('provides security information for all platforms', () {
        for (final platform in ConfidentialPlatform.values) {
          final securityInfo = PlatformDetector.getSecurityInfo(platform);
          
          expect(securityInfo.platform, equals(platform));
          expect(securityInfo.securityLevel, isA<SecurityLevel>());
          expect(securityInfo.description, isNotEmpty);
        }
      });

      test('web platform has correct security characteristics', () {
        final webInfo = PlatformDetector.getSecurityInfo(ConfidentialPlatform.web);
        
        expect(webInfo.securityLevel, equals(SecurityLevel.none));
        expect(webInfo.shouldShowWarnings, isTrue);
        expect(webInfo.warnings, isNotEmpty);
        expect(webInfo.recommendations, isNotEmpty);
      });

      test('mobile platforms have medium to high security', () {
        final androidInfo = PlatformDetector.getSecurityInfo(ConfidentialPlatform.android);
        final iosInfo = PlatformDetector.getSecurityInfo(ConfidentialPlatform.ios);
        
        expect(androidInfo.securityLevel, equals(SecurityLevel.medium));
        expect(iosInfo.securityLevel, equals(SecurityLevel.high));
      });

      test('platform detection helpers work correctly', () {
        // These tests depend on the actual platform, so we test the logic
        final platform = PlatformDetector.detectPlatform();
        
        expect(PlatformDetector.isWeb, equals(platform == ConfidentialPlatform.web));
        expect(PlatformDetector.isMobile, equals(
          platform == ConfidentialPlatform.android || platform == ConfidentialPlatform.ios
        ));
        expect(PlatformDetector.isDesktop, equals(
          platform == ConfidentialPlatform.macos || 
          platform == ConfidentialPlatform.windows || 
          platform == ConfidentialPlatform.linux
        ));
        expect(PlatformDetector.isServer, equals(platform == ConfidentialPlatform.server));
      });
    });

    group('WebAwareConfig', () {
      test('factory constructors create correct configurations', () {
        final webWithWarnings = WebAwareConfig.webWithWarnings();
        expect(webWithWarnings.showWebWarnings, isTrue);
        expect(webWithWarnings.disableSecretsOnWeb, isFalse);
        
        final webDisabled = WebAwareConfig.webDisabled();
        expect(webDisabled.showWebWarnings, isTrue);
        expect(webDisabled.disableSecretsOnWeb, isTrue);
        expect(webDisabled.useFallbackOnWeb, isTrue);
        
        final silent = WebAwareConfig.silent();
        expect(silent.showWebWarnings, isFalse);
        expect(silent.logPlatformWarnings, isFalse);
      });
    });

    group('WebAwareObfuscatedValue', () {
      test('wraps obfuscated values correctly', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareValue = originalValue.webAware('testSecret');
        
        expect(webAwareValue.secretName, equals('testSecret'));
        expect(webAwareValue.wrapped, equals(originalValue));
        expect(webAwareValue.secret, equals(originalValue.secret));
      });

      test('provides platform information', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareValue = originalValue.webAware('testSecret');
        
        expect(webAwareValue.currentPlatform, isA<ConfidentialPlatform>());
        expect(webAwareValue.platformSecurityInfo, isA<PlatformSecurityInfo>());
        expect(webAwareValue.isSecureOnCurrentPlatform, isA<bool>());
      });

      test('handles fallback values', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareValue = originalValue.webAware(
          'testSecret',
          fallbackValue: 'fallback-value',
        );
        
        expect(webAwareValue.fallbackValue, equals('fallback-value'));
      });

      test('extension methods work correctly', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        
        final withWarnings = originalValue.withWebWarnings('testSecret');
        expect(withWarnings.config.showWebWarnings, isTrue);
        
        final webDisabled = originalValue.webDisabled(
          'testSecret',
          fallbackValue: 'fallback',
        );
        expect(webDisabled.config.disableSecretsOnWeb, isTrue);
        expect(webDisabled.fallbackValue, equals('fallback'));
      });

      test('throws exception when secrets are disabled', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareValue = originalValue.webAware(
          'testSecret',
          config: const WebAwareConfig(
            disableSecretsOnWeb: true,
            useFallbackOnWeb: false,
          ),
        );
        
        // This test depends on the platform - if we're on web, it should throw
        // For non-web platforms, it should work normally
        final platform = PlatformDetector.detectPlatform();
        if (platform == ConfidentialPlatform.web) {
          expect(() => webAwareValue.value, throwsA(isA<PlatformSecurityException>()));
        } else {
          expect(webAwareValue.value, equals('test-secret'));
        }
      });

      test('uses fallback value when configured', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareValue = originalValue.webAware(
          'testSecret',
          fallbackValue: 'fallback-value',
          config: const WebAwareConfig(
            useFallbackOnWeb: true,
          ),
        );
        
        // This test depends on the platform
        final platform = PlatformDetector.detectPlatform();
        if (platform == ConfidentialPlatform.web) {
          expect(webAwareValue.value, equals('fallback-value'));
        } else {
          expect(webAwareValue.value, equals('test-secret'));
        }
      });
    });

    group('WebAwareObfuscatedFactory', () {
      test('creates different types of web-aware values', () {
        const factory = WebAwareObfuscatedFactory();
        
        final stringValue = 'test'.obfuscate(algorithm: 'aes-256-gcm');
        final intValue = 42.obfuscate(algorithm: 'aes-256-gcm');
        final boolValue = true.obfuscate(algorithm: 'aes-256-gcm');
        
        final webAwareString = factory.string('testString', stringValue);
        final webAwareInt = factory.integer('testInt', intValue);
        final webAwareBool = factory.boolean('testBool', boolValue);
        
        expect(webAwareString.secretName, equals('testString'));
        expect(webAwareInt.secretName, equals('testInt'));
        expect(webAwareBool.secretName, equals('testBool'));
      });

      test('applies default configuration', () {
        const config = WebAwareConfig(showWebWarnings: false);
        const factory = WebAwareObfuscatedFactory(defaultConfig: config);
        
        final stringValue = 'test'.obfuscate(algorithm: 'aes-256-gcm');
        final webAwareString = factory.string('testString', stringValue);
        
        expect(webAwareString.config.showWebWarnings, isFalse);
      });
    });

    group('PlatformAwareConfig', () {
      test('factory constructors create appropriate configurations', () {
        final production = PlatformAwareConfig.production();
        expect(production.enforcePlatformSecurity, isTrue);
        expect(production.autoDetectPlatform, isTrue);
        
        final development = PlatformAwareConfig.development();
        expect(development.showPlatformInfo, isTrue);
        expect(development.enforcePlatformSecurity, isFalse);
        
        final webSecure = PlatformAwareConfig.webSecure();
        expect(webSecure.webConfig.disableSecretsOnWeb, isTrue);
      });

      test('gets appropriate config for different platforms', () {
        final config = PlatformAwareConfig.production();
        
        final webConfig = config.getConfigForPlatform(ConfidentialPlatform.web);
        expect(webConfig, isA<WebAwareConfig>());
        
        final iosConfig = config.getConfigForPlatform(ConfidentialPlatform.ios);
        expect(iosConfig, isA<WebAwareConfig>());
      });

      test('respects platform overrides', () {
        const customWebConfig = WebAwareConfig(showWebWarnings: false);
        final config = PlatformAwareConfig(
          platformOverrides: {
            ConfidentialPlatform.web: customWebConfig,
          },
        );
        
        final webConfig = config.getConfigForPlatform(ConfidentialPlatform.web);
        expect(webConfig.showWebWarnings, isFalse);
      });
    });

    group('PlatformAwareSecretManager', () {
      test('registers and retrieves secrets', () {
        final manager = PlatformAwareSecretManager();
        
        manager.registerSecret('testSecret', 'test-value');
        
        expect(manager.secretCount, equals(1));
        expect(manager.secretNames, contains('testSecret'));
        
        final value = manager.getSecret<String>('testSecret');
        expect(value, equals('test-value'));
      });

      test('handles different value types', () {
        final manager = PlatformAwareSecretManager();
        
        manager.registerSecret('stringSecret', 'test-string');
        manager.registerSecret('intSecret', 42);
        manager.registerSecret('boolSecret', true);
        
        expect(manager.getSecret<String>('stringSecret'), equals('test-string'));
        expect(manager.getSecret<int>('intSecret'), equals(42));
        expect(manager.getSecret<bool>('boolSecret'), isTrue);
      });

      test('provides platform information', () {
        final manager = PlatformAwareSecretManager();
        
        expect(manager.currentPlatform, isA<ConfidentialPlatform>());
        expect(manager.platformInfo, isA<PlatformSecurityInfo>());
        expect(manager.areSecretsSecure, isA<bool>());
      });

      test('handles fallback values', () {
        final manager = PlatformAwareSecretManager();
        
        manager.registerSecret(
          'testSecret',
          'real-value',
          fallbackValue: 'fallback-value',
        );
        
        expect(manager.secretCount, equals(1));
        // The actual value depends on platform and configuration
        final value = manager.getSecret<String>('testSecret');
        expect(value, isNotNull);
      });
    });

    group('GlobalPlatformConfig', () {
      test('manages global configuration', () {
        final config = PlatformAwareConfig.development();
        GlobalPlatformConfig.setGlobalConfig(config);
        
        final retrievedConfig = GlobalPlatformConfig.getGlobalConfig();
        expect(retrievedConfig.showPlatformInfo, equals(config.showPlatformInfo));
      });

      test('provides global manager', () {
        final manager1 = GlobalPlatformConfig.getGlobalManager();
        final manager2 = GlobalPlatformConfig.getGlobalManager();
        
        expect(manager1, same(manager2)); // Should be the same instance
      });

      test('initializes for different environments', () {
        GlobalPlatformConfig.initializeForEnvironment(
          isProduction: false,
          showPlatformInfo: true,
        );
        
        final config = GlobalPlatformConfig.getGlobalConfig();
        expect(config.showPlatformInfo, isTrue);
      });
    });

    group('PlatformSecurityException', () {
      test('creates exception with correct information', () {
        const exception = PlatformSecurityException(
          'Test message',
          ConfidentialPlatform.web,
          SecurityLevel.none,
        );
        
        expect(exception.message, equals('Test message'));
        expect(exception.platform, equals(ConfidentialPlatform.web));
        expect(exception.securityLevel, equals(SecurityLevel.none));
        expect(exception.toString(), contains('Test message'));
        expect(exception.toString(), contains('web'));
      });
    });
  });
}
