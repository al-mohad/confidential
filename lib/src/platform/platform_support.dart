/// Platform-specific support and web handling for dart-confidential.
/// 
/// This module provides platform detection, web-specific fallbacks,
/// and security warnings for different deployment environments.
library;

// Conditional imports for platform detection
import 'platform_web.dart' if (dart.library.io) 'platform_io.dart' as platform_impl;

/// Supported platforms for dart-confidential.
enum ConfidentialPlatform {
  /// Web platform (JavaScript compilation).
  web,
  
  /// Android mobile platform.
  android,
  
  /// iOS mobile platform.
  ios,
  
  /// macOS desktop platform.
  macos,
  
  /// Windows desktop platform.
  windows,
  
  /// Linux desktop platform.
  linux,
  
  /// Dart server/CLI environment.
  server,
  
  /// Unknown or unsupported platform.
  unknown,
}

/// Security levels for different platforms.
enum SecurityLevel {
  /// High security - secrets are well protected.
  high,
  
  /// Medium security - some protection but with limitations.
  medium,
  
  /// Low security - minimal protection, warnings recommended.
  low,
  
  /// No security - secrets are exposed, should not be used.
  none,
}

/// Platform-specific security information.
class PlatformSecurityInfo {
  /// The platform this info applies to.
  final ConfidentialPlatform platform;
  
  /// Security level for this platform.
  final SecurityLevel securityLevel;
  
  /// Human-readable description of security characteristics.
  final String description;
  
  /// Specific warnings for this platform.
  final List<String> warnings;
  
  /// Recommended practices for this platform.
  final List<String> recommendations;
  
  /// Whether secrets should be disabled on this platform.
  final bool shouldDisableSecrets;
  
  /// Whether to show warnings when using secrets on this platform.
  final bool shouldShowWarnings;

  const PlatformSecurityInfo({
    required this.platform,
    required this.securityLevel,
    required this.description,
    this.warnings = const [],
    this.recommendations = const [],
    this.shouldDisableSecrets = false,
    this.shouldShowWarnings = false,
  });
}

/// Platform detection and security assessment.
class PlatformDetector {
  static ConfidentialPlatform? _cachedPlatform;
  static PlatformSecurityInfo? _cachedSecurityInfo;

  /// Detects the current platform.
  static ConfidentialPlatform detectPlatform() {
    if (_cachedPlatform != null) return _cachedPlatform!;

    _cachedPlatform = platform_impl.detectPlatform();
    return _cachedPlatform!;
  }

  /// Gets security information for the current platform.
  static PlatformSecurityInfo getSecurityInfo([ConfidentialPlatform? platform]) {
    platform ??= detectPlatform();
    
    if (_cachedSecurityInfo?.platform == platform) {
      return _cachedSecurityInfo!;
    }

    _cachedSecurityInfo = _getSecurityInfoForPlatform(platform);
    return _cachedSecurityInfo!;
  }

  /// Checks if the current platform is web.
  static bool get isWeb => detectPlatform() == ConfidentialPlatform.web;

  /// Checks if the current platform is mobile.
  static bool get isMobile {
    final platform = detectPlatform();
    return platform == ConfidentialPlatform.android || 
           platform == ConfidentialPlatform.ios;
  }

  /// Checks if the current platform is desktop.
  static bool get isDesktop {
    final platform = detectPlatform();
    return platform == ConfidentialPlatform.macos || 
           platform == ConfidentialPlatform.windows || 
           platform == ConfidentialPlatform.linux;
  }

  /// Checks if the current platform is server/CLI.
  static bool get isServer => detectPlatform() == ConfidentialPlatform.server;

  /// Checks if secrets are secure on the current platform.
  static bool get areSecretsSecure {
    final securityInfo = getSecurityInfo();
    return securityInfo.securityLevel == SecurityLevel.high ||
           securityInfo.securityLevel == SecurityLevel.medium;
  }

  /// Checks if warnings should be shown for the current platform.
  static bool get shouldShowWarnings {
    return getSecurityInfo().shouldShowWarnings;
  }

  /// Checks if secrets should be disabled on the current platform.
  static bool get shouldDisableSecrets {
    return getSecurityInfo().shouldDisableSecrets;
  }

  static PlatformSecurityInfo _getSecurityInfoForPlatform(ConfidentialPlatform platform) {
    switch (platform) {
      case ConfidentialPlatform.web:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.web,
          securityLevel: SecurityLevel.none,
          description: 'Web platform compiles to JavaScript where secrets cannot be truly hidden',
          warnings: [
            'Secrets are compiled to JavaScript and can be easily extracted',
            'Browser developer tools can inspect all code and data',
            'Source maps may expose obfuscated code structure',
            'Client-side secrets are fundamentally insecure',
          ],
          recommendations: [
            'Use server-side API endpoints for sensitive operations',
            'Implement proper authentication and authorization',
            'Use environment variables on the server side',
            'Consider using public API keys with proper restrictions',
            'Implement rate limiting and request validation',
          ],
          shouldDisableSecrets: false, // Allow with warnings
          shouldShowWarnings: true,
        );

      case ConfidentialPlatform.android:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.android,
          securityLevel: SecurityLevel.medium,
          description: 'Android provides moderate protection through APK obfuscation and runtime security',
          warnings: [
            'APK files can be reverse engineered with tools like jadx or apktool',
            'Rooted devices may have reduced security',
            'Debug builds are less secure than release builds',
          ],
          recommendations: [
            'Use ProGuard/R8 obfuscation in release builds',
            'Enable code shrinking and minification',
            'Consider using Android Keystore for sensitive keys',
            'Implement certificate pinning for network security',
            'Use runtime application self-protection (RASP) techniques',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.ios:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.ios,
          securityLevel: SecurityLevel.high,
          description: 'iOS provides strong protection through app sandboxing and code signing',
          warnings: [
            'Jailbroken devices may have reduced security',
            'Debug builds are less secure than release builds',
          ],
          recommendations: [
            'Use iOS Keychain for sensitive data storage',
            'Enable app transport security (ATS)',
            'Implement certificate pinning',
            'Use secure enclave when available',
            'Enable data protection classes',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.macos:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.macos,
          securityLevel: SecurityLevel.high,
          description: 'macOS provides strong protection through code signing and sandboxing',
          warnings: [
            'Debug builds are less secure than release builds',
            'Admin access may allow memory inspection',
          ],
          recommendations: [
            'Use macOS Keychain for sensitive data storage',
            'Enable hardened runtime and library validation',
            'Implement code signing and notarization',
            'Use secure storage APIs when available',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.windows:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.windows,
          securityLevel: SecurityLevel.medium,
          description: 'Windows provides moderate protection through various security features',
          warnings: [
            'Debug builds are less secure than release builds',
            'Admin access may allow memory inspection',
            'Various reverse engineering tools are available',
          ],
          recommendations: [
            'Use Windows Credential Manager for sensitive data',
            'Enable control flow guard and other security features',
            'Consider using Windows Hello for authentication',
            'Implement proper access controls',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.linux:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.linux,
          securityLevel: SecurityLevel.medium,
          description: 'Linux provides moderate protection through various security mechanisms',
          warnings: [
            'Debug builds are less secure than release builds',
            'Root access may allow memory inspection',
            'Various debugging and analysis tools are available',
          ],
          recommendations: [
            'Use system keyring services (GNOME Keyring, KWallet)',
            'Implement proper file permissions and access controls',
            'Consider using SELinux or AppArmor policies',
            'Use secure storage mechanisms when available',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.server:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.server,
          securityLevel: SecurityLevel.high,
          description: 'Server environments can provide strong protection with proper configuration',
          warnings: [
            'Server security depends on proper configuration',
            'Debug builds should not be used in production',
          ],
          recommendations: [
            'Use environment variables for configuration',
            'Implement proper access controls and authentication',
            'Use secure secret management services (HashiCorp Vault, etc.)',
            'Enable logging and monitoring for security events',
            'Use encrypted storage and secure communication',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: false,
        );

      case ConfidentialPlatform.unknown:
        return const PlatformSecurityInfo(
          platform: ConfidentialPlatform.unknown,
          securityLevel: SecurityLevel.low,
          description: 'Unknown platform - security characteristics cannot be determined',
          warnings: [
            'Platform security characteristics are unknown',
            'Secrets may not be properly protected',
          ],
          recommendations: [
            'Verify platform security before using in production',
            'Consider alternative secret management approaches',
            'Implement additional security measures',
          ],
          shouldDisableSecrets: false,
          shouldShowWarnings: true,
        );
    }
  }

  /// Clears the platform detection cache (useful for testing).
  static void clearCache() {
    _cachedPlatform = null;
    _cachedSecurityInfo = null;
  }
}
