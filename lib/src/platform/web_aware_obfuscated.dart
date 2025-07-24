/// Web-aware obfuscated values with platform-specific handling.
/// 
/// This module provides obfuscated values that automatically handle
/// web platform limitations and provide appropriate warnings.
library;

import 'dart:typed_data';

import '../obfuscation/obfuscated.dart';
import '../obfuscation/secret.dart';
import 'platform_support.dart';

/// Configuration for web-aware behavior.
class WebAwareConfig {
  /// Whether to show warnings on web platform.
  final bool showWebWarnings;
  
  /// Whether to disable secrets on web platform.
  final bool disableSecretsOnWeb;
  
  /// Whether to use fallback values on web platform.
  final bool useFallbackOnWeb;
  
  /// Custom warning message for web platform.
  final String? customWebWarning;
  
  /// Whether to log platform warnings.
  final bool logPlatformWarnings;

  const WebAwareConfig({
    this.showWebWarnings = true,
    this.disableSecretsOnWeb = false,
    this.useFallbackOnWeb = false,
    this.customWebWarning,
    this.logPlatformWarnings = true,
  });

  /// Configuration that shows warnings but allows secrets on web.
  factory WebAwareConfig.webWithWarnings() {
    return const WebAwareConfig(
      showWebWarnings: true,
      disableSecretsOnWeb: false,
      useFallbackOnWeb: false,
      logPlatformWarnings: true,
    );
  }

  /// Configuration that disables secrets on web platform.
  factory WebAwareConfig.webDisabled() {
    return const WebAwareConfig(
      showWebWarnings: true,
      disableSecretsOnWeb: true,
      useFallbackOnWeb: true,
      logPlatformWarnings: true,
    );
  }

  /// Configuration that silently allows secrets (not recommended for web).
  factory WebAwareConfig.silent() {
    return const WebAwareConfig(
      showWebWarnings: false,
      disableSecretsOnWeb: false,
      useFallbackOnWeb: false,
      logPlatformWarnings: false,
    );
  }
}

/// Exception thrown when secrets are disabled on the current platform.
class PlatformSecurityException implements Exception {
  final String message;
  final ConfidentialPlatform platform;
  final SecurityLevel securityLevel;

  const PlatformSecurityException(
    this.message,
    this.platform,
    this.securityLevel,
  );

  @override
  String toString() {
    return 'PlatformSecurityException: $message (Platform: $platform, Security: $securityLevel)';
  }
}

/// A web-aware obfuscated value that handles platform-specific security concerns.
class WebAwareObfuscatedValue<T> implements ObfuscatedValue<T> {
  final ObfuscatedValue<T> _wrapped;
  final T? _fallbackValue;
  final WebAwareConfig _config;
  final String _secretName;
  
  static bool _hasShownWebWarning = false;
  static final List<String> _loggedWarnings = [];

  WebAwareObfuscatedValue(
    this._wrapped,
    this._secretName, {
    T? fallbackValue,
    WebAwareConfig config = const WebAwareConfig(),
  }) : _fallbackValue = fallbackValue,
       _config = config;

  @override
  T get value {
    final platform = PlatformDetector.detectPlatform();
    final securityInfo = PlatformDetector.getSecurityInfo(platform);

    // Handle web platform specifically
    if (platform == ConfidentialPlatform.web) {
      return _handleWebAccess(securityInfo);
    }

    // Handle other platforms with warnings if needed
    if (securityInfo.shouldShowWarnings && _config.logPlatformWarnings) {
      _logPlatformWarning(platform, securityInfo);
    }

    if (securityInfo.shouldDisableSecrets && _config.disableSecretsOnWeb) {
      throw PlatformSecurityException(
        'Secrets are disabled on platform: $platform',
        platform,
        securityInfo.securityLevel,
      );
    }

    return _wrapped.value;
  }

  T _handleWebAccess(PlatformSecurityInfo securityInfo) {
    // Show web warning if configured
    if (_config.showWebWarnings && !_hasShownWebWarning) {
      _showWebWarning(securityInfo);
      _hasShownWebWarning = true;
    }

    // Disable secrets on web if configured
    if (_config.disableSecretsOnWeb) {
      if (_config.useFallbackOnWeb && _fallbackValue != null) {
        return _fallbackValue!;
      }
      
      throw PlatformSecurityException(
        'Secrets are disabled on web platform for security reasons',
        ConfidentialPlatform.web,
        SecurityLevel.none,
      );
    }

    // Use fallback if configured and available
    if (_config.useFallbackOnWeb && _fallbackValue != null) {
      return _fallbackValue!;
    }

    // Return the actual secret value (with warning already shown)
    return _wrapped.value;
  }

  void _showWebWarning(PlatformSecurityInfo securityInfo) {
    final warning = _config.customWebWarning ?? _buildDefaultWebWarning(securityInfo);
    
    if (_config.logPlatformWarnings) {
      print('⚠️  SECURITY WARNING: $warning');
      print('   Secret: $_secretName');
      print('   Platform: ${securityInfo.platform.name}');
      print('   Security Level: ${securityInfo.securityLevel.name}');
      
      if (securityInfo.recommendations.isNotEmpty) {
        print('   Recommendations:');
        for (final rec in securityInfo.recommendations.take(3)) {
          print('   - $rec');
        }
      }
    }
  }

  void _logPlatformWarning(ConfidentialPlatform platform, PlatformSecurityInfo securityInfo) {
    final warningKey = '${platform.name}_${_secretName}';
    if (_loggedWarnings.contains(warningKey)) return;
    
    _loggedWarnings.add(warningKey);
    
    if (securityInfo.warnings.isNotEmpty) {
      print('⚠️  Platform Security Notice for $_secretName:');
      print('   Platform: ${platform.name}');
      print('   Security Level: ${securityInfo.securityLevel.name}');
      print('   Warning: ${securityInfo.warnings.first}');
    }
  }

  String _buildDefaultWebWarning(PlatformSecurityInfo securityInfo) {
    return 'Secrets on web platform are not secure and can be easily extracted. '
           'Consider using server-side APIs for sensitive operations.';
  }

  @override
  T get $ => value;

  @override
  Secret get secret => _wrapped.secret;

  @override
  T Function(Uint8List, int) get deobfuscate => _wrapped.deobfuscate;

  /// Gets the fallback value if available.
  T? get fallbackValue => _fallbackValue;

  /// Gets the configuration.
  WebAwareConfig get config => _config;

  /// Gets the secret name.
  String get secretName => _secretName;

  /// Gets the wrapped obfuscated value.
  ObfuscatedValue<T> get wrapped => _wrapped;

  /// Checks if this secret is secure on the current platform.
  bool get isSecureOnCurrentPlatform {
    return PlatformDetector.areSecretsSecure;
  }

  /// Gets the current platform.
  ConfidentialPlatform get currentPlatform {
    return PlatformDetector.detectPlatform();
  }

  /// Gets security information for the current platform.
  PlatformSecurityInfo get platformSecurityInfo {
    return PlatformDetector.getSecurityInfo();
  }

  /// Resets the web warning state (useful for testing).
  static void resetWarningState() {
    _hasShownWebWarning = false;
    _loggedWarnings.clear();
  }

  @override
  String toString() {
    return 'WebAwareObfuscatedValue<$T>($_secretName, platform: ${currentPlatform.name})';
  }
}

/// Factory for creating web-aware obfuscated values.
class WebAwareObfuscatedFactory {
  final WebAwareConfig _defaultConfig;

  const WebAwareObfuscatedFactory({
    WebAwareConfig defaultConfig = const WebAwareConfig(),
  }) : _defaultConfig = defaultConfig;

  /// Creates a web-aware obfuscated string.
  WebAwareObfuscatedValue<String> string(
    String secretName,
    ObfuscatedValue<String> obfuscatedValue, {
    String? fallbackValue,
    WebAwareConfig? config,
  }) {
    return WebAwareObfuscatedValue<String>(
      obfuscatedValue,
      secretName,
      fallbackValue: fallbackValue,
      config: config ?? _defaultConfig,
    );
  }

  /// Creates a web-aware obfuscated integer.
  WebAwareObfuscatedValue<int> integer(
    String secretName,
    ObfuscatedValue<int> obfuscatedValue, {
    int? fallbackValue,
    WebAwareConfig? config,
  }) {
    return WebAwareObfuscatedValue<int>(
      obfuscatedValue,
      secretName,
      fallbackValue: fallbackValue,
      config: config ?? _defaultConfig,
    );
  }

  /// Creates a web-aware obfuscated boolean.
  WebAwareObfuscatedValue<bool> boolean(
    String secretName,
    ObfuscatedValue<bool> obfuscatedValue, {
    bool? fallbackValue,
    WebAwareConfig? config,
  }) {
    return WebAwareObfuscatedValue<bool>(
      obfuscatedValue,
      secretName,
      fallbackValue: fallbackValue,
      config: config ?? _defaultConfig,
    );
  }

  /// Creates a web-aware obfuscated value of any type.
  WebAwareObfuscatedValue<T> generic<T>(
    String secretName,
    ObfuscatedValue<T> obfuscatedValue, {
    T? fallbackValue,
    WebAwareConfig? config,
  }) {
    return WebAwareObfuscatedValue<T>(
      obfuscatedValue,
      secretName,
      fallbackValue: fallbackValue,
      config: config ?? _defaultConfig,
    );
  }

  /// Wraps an existing obfuscated value with web-aware functionality.
  WebAwareObfuscatedValue<T> wrap<T>(
    String secretName,
    ObfuscatedValue<T> obfuscatedValue, {
    T? fallbackValue,
    WebAwareConfig? config,
  }) {
    return WebAwareObfuscatedValue<T>(
      obfuscatedValue,
      secretName,
      fallbackValue: fallbackValue,
      config: config ?? _defaultConfig,
    );
  }
}

/// Extension methods for adding web-aware functionality to existing obfuscated values.
extension ObfuscatedValueWebAwareExtension<T> on ObfuscatedValue<T> {
  /// Wraps this obfuscated value with web-aware functionality.
  WebAwareObfuscatedValue<T> webAware(
    String secretName, {
    T? fallbackValue,
    WebAwareConfig config = const WebAwareConfig(),
  }) {
    return WebAwareObfuscatedValue<T>(
      this,
      secretName,
      fallbackValue: fallbackValue,
      config: config,
    );
  }

  /// Wraps this obfuscated value with web warnings enabled.
  WebAwareObfuscatedValue<T> withWebWarnings(String secretName) {
    return webAware(
      secretName,
      config: WebAwareConfig.webWithWarnings(),
    );
  }

  /// Wraps this obfuscated value with web secrets disabled.
  WebAwareObfuscatedValue<T> webDisabled(
    String secretName, {
    required T fallbackValue,
  }) {
    return webAware(
      secretName,
      fallbackValue: fallbackValue,
      config: WebAwareConfig.webDisabled(),
    );
  }
}
