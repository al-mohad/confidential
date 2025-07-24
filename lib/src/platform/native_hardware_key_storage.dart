/// Native platform channel integration for hardware-backed key storage.
///
/// Provides direct access to platform-specific hardware security features:
/// - Android Keystore with StrongBox support
/// - iOS Keychain with Secure Enclave support
/// - Enhanced biometric authentication
/// - Hardware key attestation
library;

import 'package:flutter/services.dart';

import '../obfuscation/obfuscation.dart';
import 'platform_support.dart';

/// Native hardware key storage implementation using platform channels.
class NativeHardwareKeyStorage {
  static const MethodChannel _channel = MethodChannel(
    'com.confidential.hardware_key_storage',
  );

  final ConfidentialPlatform _platform;

  /// Cache for hardware capability checks.
  bool? _hardwareBackingAvailable;
  bool? _strongBoxAvailable;
  bool? _secureEnclaveAvailable;
  bool? _biometricAvailable;

  NativeHardwareKeyStorage({ConfidentialPlatform? platform})
    : _platform = platform ?? PlatformDetector.detectPlatform();

  /// Checks if hardware-backed key storage is available.
  Future<bool> isHardwareBackingAvailable() async {
    if (_hardwareBackingAvailable != null) {
      return _hardwareBackingAvailable!;
    }

    try {
      _hardwareBackingAvailable =
          await _channel.invokeMethod<bool>('isHardwareBackingAvailable') ??
          false;
      return _hardwareBackingAvailable!;
    } catch (e) {
      _hardwareBackingAvailable = false;
      return false;
    }
  }

  /// Checks if Android StrongBox is available (Android only).
  Future<bool> isStrongBoxAvailable() async {
    if (_platform != ConfidentialPlatform.android) {
      return false;
    }

    if (_strongBoxAvailable != null) {
      return _strongBoxAvailable!;
    }

    try {
      _strongBoxAvailable =
          await _channel.invokeMethod<bool>('isStrongBoxAvailable') ?? false;
      return _strongBoxAvailable!;
    } catch (e) {
      _strongBoxAvailable = false;
      return false;
    }
  }

  /// Checks if iOS Secure Enclave is available (iOS only).
  Future<bool> isSecureEnclaveAvailable() async {
    if (_platform != ConfidentialPlatform.ios) {
      return false;
    }

    if (_secureEnclaveAvailable != null) {
      return _secureEnclaveAvailable!;
    }

    try {
      _secureEnclaveAvailable =
          await _channel.invokeMethod<bool>('isSecureEnclaveAvailable') ??
          false;
      return _secureEnclaveAvailable!;
    } catch (e) {
      _secureEnclaveAvailable = false;
      return false;
    }
  }

  /// Checks if biometric authentication is available.
  Future<bool> isBiometricAvailable() async {
    if (_biometricAvailable != null) {
      return _biometricAvailable!;
    }

    try {
      _biometricAvailable =
          await _channel.invokeMethod<bool>('isBiometricAvailable') ?? false;
      return _biometricAvailable!;
    } catch (e) {
      _biometricAvailable = false;
      return false;
    }
  }

  /// Generates a hardware-backed encryption key.
  Future<NativeKeyInfo> generateHardwareKey({
    required String keyAlias,
    int keySize = 256,
    bool useStrongBox = false,
    bool useSecureEnclave = false,
    bool requireAuth = false,
    bool requireBiometric = false,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'keyAlias': keyAlias,
        'keySize': keySize,
        'requireAuth': requireAuth,
        'requireBiometric': requireBiometric,
      };

      // Platform-specific arguments
      if (_platform == ConfidentialPlatform.android) {
        args['useStrongBox'] = useStrongBox;
      } else if (_platform == ConfidentialPlatform.ios) {
        args['useSecureEnclave'] = useSecureEnclave;
      }

      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'generateHardwareKey',
        args,
      );

      if (result == null) {
        throw ObfuscationException(
          'Failed to generate hardware key: null result',
        );
      }

      return NativeKeyInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw ObfuscationException('Failed to generate hardware key: $e');
    }
  }

  /// Generates a Secure Enclave key (iOS only).
  Future<NativeKeyInfo> generateSecureEnclaveKey({
    required String keyAlias,
    bool requireBiometric = true,
  }) async {
    if (_platform != ConfidentialPlatform.ios) {
      throw ObfuscationException(
        'Secure Enclave keys are only available on iOS',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'generateSecureEnclaveKey',
        {'keyAlias': keyAlias, 'requireBiometric': requireBiometric},
      );

      if (result == null) {
        throw ObfuscationException(
          'Failed to generate Secure Enclave key: null result',
        );
      }

      return NativeKeyInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw ObfuscationException('Failed to generate Secure Enclave key: $e');
    }
  }

  /// Gets detailed information about a stored key.
  Future<NativeKeyInfo?> getKeyInfo(String keyAlias) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getKeyInfo',
        {'keyAlias': keyAlias},
      );

      if (result == null) {
        return null;
      }

      final keyInfo = NativeKeyInfo.fromMap(Map<String, dynamic>.from(result));
      return keyInfo.exists ? keyInfo : null;
    } catch (e) {
      return null;
    }
  }

  /// Deletes a stored key.
  Future<bool> deleteKey(String keyAlias) async {
    try {
      return await _channel.invokeMethod<bool>('deleteKey', {
            'keyAlias': keyAlias,
          }) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Lists all stored keys.
  Future<List<String>> listKeys() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('listKeys');
      return result?.cast<String>() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Performs key attestation to verify hardware backing.
  Future<KeyAttestationResult> attestKey(String keyAlias) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'attestKey',
        {'keyAlias': keyAlias},
      );

      if (result == null) {
        return KeyAttestationResult(
          verified: false,
          error: 'Attestation failed: null result',
        );
      }

      return KeyAttestationResult.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      return KeyAttestationResult(
        verified: false,
        error: 'Attestation failed: $e',
      );
    }
  }

  /// Authenticates user with biometric.
  Future<BiometricAuthResult> authenticateWithBiometric({
    String? title,
    String? subtitle,
    String? negativeButtonText,
    String? reason,
    String? fallbackTitle,
  }) async {
    try {
      final Map<String, dynamic> args = {};

      // Platform-specific arguments
      if (_platform == ConfidentialPlatform.android) {
        args['title'] = title ?? 'Authenticate';
        args['subtitle'] = subtitle ?? 'Use your biometric to authenticate';
        args['negativeButtonText'] = negativeButtonText ?? 'Cancel';
      } else if (_platform == ConfidentialPlatform.ios) {
        args['reason'] = reason ?? 'Authenticate to access secure key';
        args['fallbackTitle'] = fallbackTitle ?? 'Use Passcode';
      }

      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'authenticateWithBiometric',
        args,
      );

      if (result == null) {
        return BiometricAuthResult(
          authenticated: false,
          error: 'Authentication failed: null result',
        );
      }

      return BiometricAuthResult.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      return BiometricAuthResult(
        authenticated: false,
        error: 'Authentication failed: $e',
      );
    }
  }

  /// Gets the security level of a key.
  Future<SecurityLevelResult> getSecurityLevel(String keyAlias) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSecurityLevel',
        {'keyAlias': keyAlias},
      );

      if (result == null) {
        return SecurityLevelResult(
          securityLevel: HardwareSecurityLevel.unknown,
          error: 'Failed to get security level: null result',
        );
      }

      return SecurityLevelResult.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      return SecurityLevelResult(
        securityLevel: HardwareSecurityLevel.unknown,
        error: 'Failed to get security level: $e',
      );
    }
  }

  /// Gets comprehensive platform capabilities.
  Future<PlatformCapabilities> getPlatformCapabilities() async {
    final hardwareBacking = await isHardwareBackingAvailable();
    final strongBox = await isStrongBoxAvailable();
    final secureEnclave = await isSecureEnclaveAvailable();
    final biometric = await isBiometricAvailable();

    return PlatformCapabilities(
      platform: _platform,
      hardwareBackingAvailable: hardwareBacking,
      strongBoxAvailable: strongBox,
      secureEnclaveAvailable: secureEnclave,
      biometricAvailable: biometric,
    );
  }
}

/// Information about a native hardware key.
class NativeKeyInfo {
  final bool exists;
  final String? keyAlias;
  final int? keySize;
  final bool created;
  final Map<String, dynamic> keyInfo;

  const NativeKeyInfo({
    required this.exists,
    this.keyAlias,
    this.keySize,
    this.created = false,
    this.keyInfo = const {},
  });

  factory NativeKeyInfo.fromMap(Map<String, dynamic> map) {
    return NativeKeyInfo(
      exists: map['exists'] as bool? ?? map.containsKey('keyAlias'),
      keyAlias: map['keyAlias'] as String?,
      keySize: map['keySize'] as int?,
      created: map['created'] as bool? ?? false,
      keyInfo: Map<String, dynamic>.from(map['keyInfo'] as Map? ?? {}),
    );
  }

  /// Whether the key is hardware-backed.
  bool get isHardwareBacked {
    return keyInfo['isInsideSecureHardware'] as bool? ??
        keyInfo['isSecureEnclave'] as bool? ??
        false;
  }

  /// Whether the key is StrongBox-backed (Android).
  bool get isStrongBoxBacked {
    return keyInfo['isStrongBoxBacked'] as bool? ?? false;
  }

  /// Whether the key is Secure Enclave-backed (iOS).
  bool get isSecureEnclaveBacked {
    return keyInfo['isSecureEnclave'] as bool? ?? false;
  }

  /// Whether the key requires authentication.
  bool get requiresAuthentication {
    return keyInfo['userAuthenticationRequired'] as bool? ?? false;
  }
}

/// Result of key attestation.
class KeyAttestationResult {
  final bool verified;
  final bool? hardwareBacked;
  final bool? strongBoxBacked;
  final String? error;
  final Map<String, dynamic> keyInfo;

  const KeyAttestationResult({
    required this.verified,
    this.hardwareBacked,
    this.strongBoxBacked,
    this.error,
    this.keyInfo = const {},
  });

  factory KeyAttestationResult.fromMap(Map<String, dynamic> map) {
    return KeyAttestationResult(
      verified: map['verified'] as bool? ?? false,
      hardwareBacked: map['hardwareBacked'] as bool?,
      strongBoxBacked: map['strongBoxBacked'] as bool?,
      error: map['error'] as String?,
      keyInfo: Map<String, dynamic>.from(map['keyInfo'] as Map? ?? {}),
    );
  }
}

/// Result of biometric authentication.
class BiometricAuthResult {
  final bool authenticated;
  final String? error;
  final int? errorCode;

  const BiometricAuthResult({
    required this.authenticated,
    this.error,
    this.errorCode,
  });

  factory BiometricAuthResult.fromMap(Map<String, dynamic> map) {
    return BiometricAuthResult(
      authenticated: map['authenticated'] as bool? ?? false,
      error: map['error'] as String?,
      errorCode: map['errorCode'] as int?,
    );
  }
}

/// Security levels for hardware keys.
enum HardwareSecurityLevel {
  unknown,
  software,
  tee,
  strongBox,
  keychain,
  secureEnclave,
}

/// Result of security level check.
class SecurityLevelResult {
  final HardwareSecurityLevel securityLevel;
  final String? error;
  final Map<String, dynamic> keyInfo;

  const SecurityLevelResult({
    required this.securityLevel,
    this.error,
    this.keyInfo = const {},
  });

  factory SecurityLevelResult.fromMap(Map<String, dynamic> map) {
    final levelString = map['securityLevel'] as String? ?? 'UNKNOWN';
    final securityLevel = _parseSecurityLevel(levelString);

    return SecurityLevelResult(
      securityLevel: securityLevel,
      error: map['error'] as String?,
      keyInfo: Map<String, dynamic>.from(map['keyInfo'] as Map? ?? {}),
    );
  }

  static HardwareSecurityLevel _parseSecurityLevel(String level) {
    switch (level.toUpperCase()) {
      case 'SOFTWARE':
        return HardwareSecurityLevel.software;
      case 'TEE':
        return HardwareSecurityLevel.tee;
      case 'STRONGBOX':
        return HardwareSecurityLevel.strongBox;
      case 'KEYCHAIN':
        return HardwareSecurityLevel.keychain;
      case 'SECURE_ENCLAVE':
        return HardwareSecurityLevel.secureEnclave;
      default:
        return HardwareSecurityLevel.unknown;
    }
  }
}

/// Platform capabilities information.
class PlatformCapabilities {
  final ConfidentialPlatform platform;
  final bool hardwareBackingAvailable;
  final bool strongBoxAvailable;
  final bool secureEnclaveAvailable;
  final bool biometricAvailable;

  const PlatformCapabilities({
    required this.platform,
    required this.hardwareBackingAvailable,
    required this.strongBoxAvailable,
    required this.secureEnclaveAvailable,
    required this.biometricAvailable,
  });

  /// Gets the best available security level.
  HardwareSecurityLevel get bestSecurityLevel {
    if (strongBoxAvailable) return HardwareSecurityLevel.strongBox;
    if (secureEnclaveAvailable) return HardwareSecurityLevel.secureEnclave;
    if (hardwareBackingAvailable) {
      return platform == ConfidentialPlatform.android
          ? HardwareSecurityLevel.tee
          : HardwareSecurityLevel.keychain;
    }
    return HardwareSecurityLevel.software;
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform.name,
      'hardwareBackingAvailable': hardwareBackingAvailable,
      'strongBoxAvailable': strongBoxAvailable,
      'secureEnclaveAvailable': secureEnclaveAvailable,
      'biometricAvailable': biometricAvailable,
      'bestSecurityLevel': bestSecurityLevel.name,
    };
  }
}
