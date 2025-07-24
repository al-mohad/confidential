/// Platform-aware configuration for dart-confidential.
///
/// This module provides configuration that adapts to different platforms
/// and provides appropriate security settings and warnings.
library;

import 'package:confidential/src/extensions/encryption_extensions.dart';

import 'platform_support.dart';
import 'web_aware_obfuscated.dart';

/// Platform-specific configuration for dart-confidential.
class PlatformAwareConfig {
  /// Configuration for web platform.
  final WebAwareConfig webConfig;

  /// Whether to automatically detect platform and apply appropriate settings.
  final bool autoDetectPlatform;

  /// Whether to show platform security information on startup.
  final bool showPlatformInfo;

  /// Whether to enforce platform-specific security policies.
  final bool enforcePlatformSecurity;

  /// Custom platform overrides for testing.
  final Map<ConfidentialPlatform, WebAwareConfig> platformOverrides;

  const PlatformAwareConfig({
    this.webConfig = const WebAwareConfig(),
    this.autoDetectPlatform = true,
    this.showPlatformInfo = false,
    this.enforcePlatformSecurity = true,
    this.platformOverrides = const {},
  });

  /// Configuration optimized for production environments.
  factory PlatformAwareConfig.production() {
    return PlatformAwareConfig(
      webConfig: WebAwareConfig.webWithWarnings(),
      autoDetectPlatform: true,
      showPlatformInfo: false,
      enforcePlatformSecurity: true,
      platformOverrides: const {
        ConfidentialPlatform.web: WebAwareConfig(
          showWebWarnings: true,
          disableSecretsOnWeb: false,
          useFallbackOnWeb: false,
          logPlatformWarnings: true,
        ),
      },
    );
  }

  /// Configuration optimized for development environments.
  factory PlatformAwareConfig.development() {
    return PlatformAwareConfig(
      webConfig: WebAwareConfig.webWithWarnings(),
      autoDetectPlatform: true,
      showPlatformInfo: true,
      enforcePlatformSecurity: false,
      platformOverrides: const {
        ConfidentialPlatform.web: WebAwareConfig(
          showWebWarnings: true,
          disableSecretsOnWeb: false,
          useFallbackOnWeb: false,
          logPlatformWarnings: true,
        ),
      },
    );
  }

  /// Configuration that disables secrets on web platform.
  factory PlatformAwareConfig.webSecure() {
    return PlatformAwareConfig(
      webConfig: WebAwareConfig.webDisabled(),
      autoDetectPlatform: true,
      showPlatformInfo: true,
      enforcePlatformSecurity: true,
      platformOverrides: const {
        ConfidentialPlatform.web: WebAwareConfig(
          showWebWarnings: true,
          disableSecretsOnWeb: true,
          useFallbackOnWeb: true,
          logPlatformWarnings: true,
        ),
      },
    );
  }

  /// Gets the appropriate web-aware config for the current platform.
  WebAwareConfig getConfigForPlatform([ConfidentialPlatform? platform]) {
    platform ??= PlatformDetector.detectPlatform();

    // Check for platform-specific overrides
    if (platformOverrides.containsKey(platform)) {
      return platformOverrides[platform]!;
    }

    // Return web config for web platform
    if (platform == ConfidentialPlatform.web) {
      return webConfig;
    }

    // For other platforms, use a default config based on security level
    final securityInfo = PlatformDetector.getSecurityInfo(platform);
    return _getDefaultConfigForSecurityLevel(securityInfo.securityLevel);
  }

  WebAwareConfig _getDefaultConfigForSecurityLevel(
    SecurityLevel securityLevel,
  ) {
    switch (securityLevel) {
      case SecurityLevel.high:
        return const WebAwareConfig(
          showWebWarnings: false,
          disableSecretsOnWeb: false,
          useFallbackOnWeb: false,
          logPlatformWarnings: false,
        );

      case SecurityLevel.medium:
        return const WebAwareConfig(
          showWebWarnings: false,
          disableSecretsOnWeb: false,
          useFallbackOnWeb: false,
          logPlatformWarnings: true,
        );

      case SecurityLevel.low:
        return const WebAwareConfig(
          showWebWarnings: true,
          disableSecretsOnWeb: false,
          useFallbackOnWeb: false,
          logPlatformWarnings: true,
        );

      case SecurityLevel.none:
        return webConfig; // Use web config for no security
    }
  }
}

/// Platform-aware secret manager.
class PlatformAwareSecretManager {
  final PlatformAwareConfig _config;
  final Map<String, dynamic> _secrets = {};
  bool _hasShownPlatformInfo = false;

  PlatformAwareSecretManager({
    PlatformAwareConfig config = const PlatformAwareConfig(),
  }) : _config = config {
    if (_config.showPlatformInfo && !_hasShownPlatformInfo) {
      _showPlatformInfo();
      _hasShownPlatformInfo = true;
    }
  }

  /// Registers a secret with platform-aware handling.
  void registerSecret<T>(
    String name,
    T value, {
    String algorithm = 'aes-256-gcm',
    T? fallbackValue,
    WebAwareConfig? customConfig,
  }) {
    // Create obfuscated value
    final obfuscatedValue = value.toString().obfuscate(algorithm: algorithm);

    // Get platform-appropriate config
    final platformConfig = customConfig ?? _config.getConfigForPlatform();

    // Create web-aware wrapper
    final webAwareValue = obfuscatedValue.webAware(
      name,
      fallbackValue: fallbackValue?.toString(),
      config: platformConfig,
    );

    _secrets[name] = webAwareValue;
  }

  /// Gets a secret value by name.
  T? getSecret<T>(String name) {
    final secret = _secrets[name];
    if (secret == null) return null;

    if (secret is WebAwareObfuscatedValue<String>) {
      final value = secret.value;
      return _convertValue<T>(value);
    }

    return null;
  }

  /// Gets all registered secret names.
  List<String> get secretNames => _secrets.keys.toList();

  /// Gets the count of registered secrets.
  int get secretCount => _secrets.length;

  /// Gets platform information.
  PlatformSecurityInfo get platformInfo => PlatformDetector.getSecurityInfo();

  /// Checks if secrets are secure on the current platform.
  bool get areSecretsSecure => PlatformDetector.areSecretsSecure;

  /// Gets the current platform.
  ConfidentialPlatform get currentPlatform => PlatformDetector.detectPlatform();

  T? _convertValue<T>(String value) {
    if (T == String) return value as T;
    if (T == int) return int.tryParse(value) as T?;
    if (T == bool) return (value.toLowerCase() == 'true') as T;
    if (T == double) return double.tryParse(value) as T?;

    // For other types, return null or throw
    return null;
  }

  void _showPlatformInfo() {
    final platform = PlatformDetector.detectPlatform();
    final securityInfo = PlatformDetector.getSecurityInfo(platform);

    print('🔒 Dart Confidential - Platform Security Information');
    print('   Platform: ${platform.name}');
    print('   Security Level: ${securityInfo.securityLevel.name}');
    print('   Description: ${securityInfo.description}');

    if (securityInfo.warnings.isNotEmpty) {
      print('   ⚠️  Warnings:');
      for (final warning in securityInfo.warnings.take(2)) {
        print('      - $warning');
      }
    }

    if (securityInfo.recommendations.isNotEmpty) {
      print('   💡 Recommendations:');
      for (final rec in securityInfo.recommendations.take(2)) {
        print('      - $rec');
      }
    }

    print('');
  }

  /// Clears all secrets.
  void clearSecrets() {
    _secrets.clear();
  }
}

/// Global platform-aware configuration.
class GlobalPlatformConfig {
  static PlatformAwareConfig? _globalConfig;
  static PlatformAwareSecretManager? _globalManager;

  /// Sets the global platform configuration.
  static void setGlobalConfig(PlatformAwareConfig config) {
    _globalConfig = config;
    _globalManager = null; // Reset manager to use new config
  }

  /// Gets the global platform configuration.
  static PlatformAwareConfig getGlobalConfig() {
    return _globalConfig ?? PlatformAwareConfig.production();
  }

  /// Gets the global platform-aware secret manager.
  static PlatformAwareSecretManager getGlobalManager() {
    return _globalManager ??= PlatformAwareSecretManager(
      config: getGlobalConfig(),
    );
  }

  /// Initializes platform-aware configuration based on environment.
  static void initializeForEnvironment({
    bool isProduction = true,
    bool showPlatformInfo = false,
    WebAwareConfig? customWebConfig,
  }) {
    final config = isProduction
        ? PlatformAwareConfig.production()
        : PlatformAwareConfig.development();

    final finalConfig = PlatformAwareConfig(
      webConfig: customWebConfig ?? config.webConfig,
      autoDetectPlatform: config.autoDetectPlatform,
      showPlatformInfo: showPlatformInfo,
      enforcePlatformSecurity: config.enforcePlatformSecurity,
      platformOverrides: config.platformOverrides,
    );

    setGlobalConfig(finalConfig);
  }

  /// Shows current platform security information.
  static void showPlatformSecurityInfo() {
    final platform = PlatformDetector.detectPlatform();
    final securityInfo = PlatformDetector.getSecurityInfo(platform);

    print('🔒 Platform Security Assessment');
    print('=' * 40);
    print('Platform: ${platform.name}');
    print('Security Level: ${securityInfo.securityLevel.name}');
    print('Description: ${securityInfo.description}');
    print('');

    if (securityInfo.warnings.isNotEmpty) {
      print('⚠️  Security Warnings:');
      for (final warning in securityInfo.warnings) {
        print('  - $warning');
      }
      print('');
    }

    if (securityInfo.recommendations.isNotEmpty) {
      print('💡 Security Recommendations:');
      for (final rec in securityInfo.recommendations) {
        print('  - $rec');
      }
      print('');
    }

    print(
      'Secrets Secure: ${PlatformDetector.areSecretsSecure ? 'Yes' : 'No'}',
    );
    print(
      'Should Show Warnings: ${securityInfo.shouldShowWarnings ? 'Yes' : 'No'}',
    );
    print(
      'Should Disable Secrets: ${securityInfo.shouldDisableSecrets ? 'Yes' : 'No'}',
    );
  }
}
