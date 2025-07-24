import 'package:confidential/src/extensions/encryption_extensions.dart';
import 'package:confidential/src/platform/platform_support.dart';
import 'package:test/test.dart';

void main() {
  group('Platform Support Tests', () {
    setUp(() {
      // Clear platform detection cache before each test
      PlatformDetector.clearCache();
    });

    group('Platform Detection', () {
      test('detects platform consistently', () {
        final platform1 = PlatformDetector.detectPlatform();
        final platform2 = PlatformDetector.detectPlatform();

        expect(platform1, equals(platform2));
        expect(platform1, isA<ConfidentialPlatform>());
      });

      test('platform enum has expected values', () {
        expect(
          ConfidentialPlatform.values,
          contains(ConfidentialPlatform.android),
        );
        expect(ConfidentialPlatform.values, contains(ConfidentialPlatform.ios));
        expect(ConfidentialPlatform.values, contains(ConfidentialPlatform.web));
        expect(
          ConfidentialPlatform.values,
          contains(ConfidentialPlatform.unknown),
        );
      });

      test('platform names are correct', () {
        expect(ConfidentialPlatform.android.name, equals('android'));
        expect(ConfidentialPlatform.ios.name, equals('ios'));
        expect(ConfidentialPlatform.web.name, equals('web'));
        expect(ConfidentialPlatform.unknown.name, equals('unknown'));
      });

      test('can check platform capabilities', () {
        final platform = PlatformDetector.detectPlatform();

        // These should not throw
        expect(() => platform.toString(), returnsNormally);
        expect(platform.name, isA<String>());
      });
    });

    group('Basic Obfuscation', () {
      test('creates obfuscated value', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');

        expect(originalValue.value, equals('test-secret'));
      });

      test('works with different algorithms', () {
        final aesValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final chachaValue = 'test-secret'.obfuscate(
          algorithm: 'chacha20-poly1305',
        );

        expect(aesValue.value, equals('test-secret'));
        expect(chachaValue.value, equals('test-secret'));
      });

      test('handles encryption and decryption', () {
        final encrypted = 'test-secret'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final decrypted = encrypted.decrypt<String>(algorithm: 'aes-256-gcm');

        expect(decrypted, equals('test-secret'));
      });

      test('works with different data types', () {
        final stringValue = 'test-string'.obfuscate(algorithm: 'aes-256-gcm');

        expect(stringValue.value, equals('test-string'));
      });
    });

    group('Platform Security', () {
      test('platform detection does not crash', () {
        expect(() => PlatformDetector.detectPlatform(), returnsNormally);
      });

      test('can clear platform cache', () {
        final platform1 = PlatformDetector.detectPlatform();
        PlatformDetector.clearCache();
        final platform2 = PlatformDetector.detectPlatform();

        // Should still be the same platform
        expect(platform1, equals(platform2));
      });

      test('platform detection is deterministic', () {
        final platforms = List.generate(
          5,
          (_) => PlatformDetector.detectPlatform(),
        );

        // All should be the same
        for (int i = 1; i < platforms.length; i++) {
          expect(platforms[i], equals(platforms[0]));
        }
      });
    });

    group('Error Handling', () {
      test('handles invalid algorithms gracefully', () {
        expect(
          () => 'test'.obfuscate(algorithm: 'invalid-algorithm'),
          throwsA(isA<Exception>()),
        );
      });

      test('handles empty strings', () {
        final empty = ''.obfuscate(algorithm: 'aes-256-gcm');
        expect(empty.value, equals(''));
      });

      test('handles special characters', () {
        final special = 'test@#\$%^&*()'.obfuscate(algorithm: 'aes-256-gcm');
        expect(special.value, equals('test@#\$%^&*()'));
      });
    });

    group('Platform Information', () {
      test('can get platform information', () {
        final platform = PlatformDetector.detectPlatform();

        expect(platform, isA<ConfidentialPlatform>());
        expect(platform.name, isA<String>());
      });

      test('platform detection is consistent', () {
        final platform1 = PlatformDetector.detectPlatform();
        final platform2 = PlatformDetector.detectPlatform();

        expect(platform1, equals(platform2));
      });

      test('platform has valid name', () {
        final platform = PlatformDetector.detectPlatform();

        expect(platform.name, isNotEmpty);
        expect([
          'android',
          'ios',
          'web',
          'macos',
          'windows',
          'linux',
          'unknown',
        ], contains(platform.name));
      });
    });
  });
}
