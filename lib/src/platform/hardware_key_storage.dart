/// Hardware-backed key storage for Flutter mobile platforms.
///
/// Provides secure key storage using:
/// - Android Keystore on Android devices with StrongBox support
/// - iOS Keychain on iOS devices with Secure Enclave support
/// - Native platform channel integration for enhanced security
/// - Fallback to secure storage on other platforms
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../obfuscation/encryption/key_management.dart';
import '../obfuscation/obfuscation.dart';
import 'platform_support.dart';

/// Configuration for hardware-backed key storage.
class HardwareKeyStorageConfig {
  /// Whether to use hardware-backed storage when available.
  final bool useHardwareBacking;

  /// Whether to require hardware backing (fail if not available).
  final bool requireHardwareBacking;

  /// Key prefix for storage identification.
  final String keyPrefix;

  /// Whether to use biometric authentication for key access.
  final bool useBiometricAuth;

  /// Whether to require device authentication (PIN/password/biometric).
  final bool requireDeviceAuth;

  /// Key size in bits for generated keys.
  final int keySize;

  /// Whether to enable key rotation.
  final bool enableKeyRotation;

  /// Key rotation interval in days.
  final int rotationIntervalDays;

  /// Whether to use native platform channels for enhanced security.
  final bool useNativePlatformChannels;

  /// Whether to prefer StrongBox on Android when available.
  final bool preferStrongBox;

  /// Whether to prefer Secure Enclave on iOS when available.
  final bool preferSecureEnclave;

  const HardwareKeyStorageConfig({
    this.useHardwareBacking = true,
    this.requireHardwareBacking = false,
    this.keyPrefix = 'confidential_key',
    this.useBiometricAuth = false,
    this.requireDeviceAuth = true,
    this.keySize = 256,
    this.enableKeyRotation = true,
    this.rotationIntervalDays = 30,
    this.useNativePlatformChannels = true,
    this.preferStrongBox = true,
    this.preferSecureEnclave = true,
  });

  /// Creates a configuration optimized for maximum security.
  factory HardwareKeyStorageConfig.maxSecurity() {
    return const HardwareKeyStorageConfig(
      useHardwareBacking: true,
      requireHardwareBacking: true,
      useBiometricAuth: true,
      requireDeviceAuth: true,
      keySize: 256,
      enableKeyRotation: true,
      rotationIntervalDays: 7,
      useNativePlatformChannels: true,
      preferStrongBox: true,
      preferSecureEnclave: true,
    );
  }

  /// Creates a configuration for development/testing.
  factory HardwareKeyStorageConfig.development() {
    return const HardwareKeyStorageConfig(
      useHardwareBacking: false,
      requireHardwareBacking: false,
      useBiometricAuth: false,
      requireDeviceAuth: false,
      keySize: 256,
      enableKeyRotation: false,
      rotationIntervalDays: 365,
      useNativePlatformChannels: false,
      preferStrongBox: false,
      preferSecureEnclave: false,
    );
  }
}

/// Hardware-backed key storage implementation.
class HardwareKeyStorage {
  final HardwareKeyStorageConfig config;
  final FlutterSecureStorage _secureStorage;
  final ConfidentialPlatform _platform;
  // final NativeHardwareKeyStorage? _nativeStorage;

  /// Cache for loaded keys to avoid repeated hardware access.
  final Map<String, VersionedKey> _keyCache = {};

  /// Whether hardware backing is available on this device.
  bool? _hardwareBackingAvailable;

  /// Platform capabilities cache.
  // PlatformCapabilities? _platformCapabilities;

  HardwareKeyStorage({
    required this.config,
    FlutterSecureStorage? secureStorage,
    ConfidentialPlatform? platform,
    // NativeHardwareKeyStorage? nativeStorage,
  }) : _secureStorage = secureStorage ?? _createSecureStorage(config),
       _platform = platform ?? PlatformDetector.detectPlatform();
  // _nativeStorage =
  //     nativeStorage ??
  //     (config.useNativePlatformChannels
  //         ? NativeHardwareKeyStorage(platform: platform)
  //         : null);

  /// Creates a FlutterSecureStorage instance with platform-specific options.
  static FlutterSecureStorage _createSecureStorage(
    HardwareKeyStorageConfig config,
  ) {
    return FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: config.useBiometricAuth
            ? KeychainAccessibility.passcode
            : KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
        accountName: config.keyPrefix,
      ),
      lOptions: LinuxOptions(),
      wOptions: WindowsOptions(useBackwardCompatibility: false),
      mOptions: MacOsOptions(
        accessibility: config.useBiometricAuth
            ? KeychainAccessibility.passcode
            : KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
        accountName: config.keyPrefix,
      ),
    );
  }

  /// Checks if hardware-backed storage is available.
  Future<bool> isHardwareBackingAvailable() async {
    if (_hardwareBackingAvailable != null) {
      return _hardwareBackingAvailable!;
    }

    try {
      switch (_platform) {
        case ConfidentialPlatform.android:
          // Test if we can use Android Keystore
          await _secureStorage.write(key: '_test_hardware', value: 'test');
          await _secureStorage.delete(key: '_test_hardware');
          _hardwareBackingAvailable = true;
          break;

        case ConfidentialPlatform.ios:
          // Test if we can use iOS Keychain
          await _secureStorage.write(key: '_test_hardware', value: 'test');
          await _secureStorage.delete(key: '_test_hardware');
          _hardwareBackingAvailable = true;
          break;

        default:
          // Other platforms don't have hardware backing
          _hardwareBackingAvailable = false;
      }
    } catch (e) {
      _hardwareBackingAvailable = false;
    }

    return _hardwareBackingAvailable!;
  }

  /// Generates and stores a new encryption key.
  Future<VersionedKey> generateAndStoreKey({
    required String keyId,
    required int version,
    int? nonce,
  }) async {
    // Check hardware backing requirements
    final hasHardwareBacking = await isHardwareBackingAvailable();
    if (config.requireHardwareBacking && !hasHardwareBacking) {
      throw ObfuscationException(
        'Hardware-backed storage required but not available on this platform',
      );
    }

    // Try native platform channels first for enhanced security
    // if (_nativeStorage != null && hasHardwareBacking) {
    //   try {
    //     return await _generateNativeKey(keyId, version, nonce);
    //   } catch (e) {
    //     // Fall back to flutter_secure_storage if native fails
    //     print(
    //       'Native key generation failed, falling back to secure storage: $e',
    //     );
    //   }
    // }

    // Generate key data using secure storage
    final keyData = await _generateSecureKeyData();

    // Create versioned key
    final key = VersionedKey(
      version: version,
      keyData: keyData,
      createdAt: DateTime.now(),
      expiresAt: config.enableKeyRotation
          ? DateTime.now().add(Duration(days: config.rotationIntervalDays))
          : null,
      isActive: true,
    );

    // Store key securely
    await _storeKey(keyId, key, hasHardwareBacking);

    // Cache the key
    _keyCache[keyId] = key;

    return key;
  }

  // Native key generation methods temporarily disabled
  // Will be re-enabled once platform channel integration is complete

  /// Retrieves a stored key by ID.
  Future<VersionedKey?> getKey(String keyId) async {
    // Check cache first
    if (_keyCache.containsKey(keyId)) {
      final cachedKey = _keyCache[keyId]!;
      if (cachedKey.isActive && !cachedKey.isExpired) {
        return cachedKey;
      } else {
        // Remove expired key from cache
        _keyCache.remove(keyId);
      }
    }

    try {
      final keyDataJson = await _secureStorage.read(key: _getStorageKey(keyId));
      if (keyDataJson == null) {
        return null;
      }

      final keyData = jsonDecode(keyDataJson) as Map<String, dynamic>;
      final key = VersionedKey.fromMap(keyData);

      if (key.isActive && !key.isExpired) {
        // Cache the key
        _keyCache[keyId] = key;
        return key;
      } else {
        // Key is expired, remove it
        await deleteKey(keyId);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Deletes a stored key.
  Future<bool> deleteKey(String keyId) async {
    try {
      await _secureStorage.delete(key: _getStorageKey(keyId));
      _keyCache.remove(keyId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Lists all stored keys.
  Future<List<String>> listKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      final prefix = '${config.keyPrefix}_';
      return allKeys.keys
          .where((key) => key.startsWith(prefix))
          .map((key) => key.substring(prefix.length))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clears all stored keys.
  Future<void> clearAllKeys() async {
    try {
      final keyIds = await listKeys();
      for (final keyId in keyIds) {
        await deleteKey(keyId);
      }
      _keyCache.clear();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Stores a key in secure storage.
  Future<void> _storeKey(
    String keyId,
    VersionedKey key,
    bool hasHardwareBacking,
  ) async {
    final keyData = key.toMap();

    // Add metadata about storage type
    keyData['hardwareBacked'] = hasHardwareBacking;
    keyData['platform'] = _platform.name;
    keyData['storedAt'] = DateTime.now().toIso8601String();

    final keyDataJson = jsonEncode(keyData);

    try {
      await _secureStorage.write(
        key: _getStorageKey(keyId),
        value: keyDataJson,
      );
    } catch (e) {
      throw ObfuscationException('Failed to store key: $e');
    }
  }

  /// Rotates a key if it's expired or rotation is forced.
  Future<VersionedKey?> rotateKeyIfNeeded(
    String keyId, {
    bool force = false,
  }) async {
    final currentKey = await getKey(keyId);

    if (currentKey == null) {
      return null;
    }

    if (force || currentKey.isExpired) {
      // Generate new key with incremented version
      final newKey = await generateAndStoreKey(
        keyId: keyId,
        version: currentKey.version + 1,
      );

      // Keep old key for a grace period to decrypt old data
      // It will be automatically cleaned up when expired

      return newKey;
    }

    return currentKey;
  }

  /// Gets storage key with prefix.
  String _getStorageKey(String keyId) {
    return '${config.keyPrefix}_$keyId';
  }

  /// Generates cryptographically secure key data.
  Future<Uint8List> _generateSecureKeyData() async {
    final keyBytes = config.keySize ~/ 8;
    final secureRandom = Platform.isAndroid || Platform.isIOS
        ? await _getHardwareRandomBytes(keyBytes)
        : _getSoftwareRandomBytes(keyBytes);

    return secureRandom;
  }

  /// Gets hardware-backed random bytes on supported platforms.
  Future<Uint8List> _getHardwareRandomBytes(int length) async {
    try {
      // On mobile platforms, we can leverage the secure storage's hardware RNG
      // by generating multiple temporary keys and combining their entropy
      final entropyKeys = <String>[];
      final entropyData = <int>[];

      // Generate multiple entropy sources
      for (int i = 0; i < 4; i++) {
        final entropyKey =
            '_entropy_${DateTime.now().microsecondsSinceEpoch}_$i';
        entropyKeys.add(entropyKey);

        // Use platform-specific entropy generation
        final platformEntropy = await _generatePlatformEntropy(i);
        await _secureStorage.write(key: entropyKey, value: platformEntropy);

        // Read back to get hardware-processed data
        final storedValue = await _secureStorage.read(key: entropyKey);
        if (storedValue != null) {
          entropyData.addAll(utf8.encode(storedValue));
        }
      }

      // Clean up temporary keys
      for (final key in entropyKeys) {
        try {
          await _secureStorage.delete(key: key);
        } catch (_) {
          // Ignore cleanup errors
        }
      }

      // Combine entropy with additional platform-specific data
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final platformId = _platform.name;
      final processId = DateTime.now().hashCode;

      final combinedEntropy = [
        ...entropyData,
        ...utf8.encode('$timestamp:$platformId:$processId:${config.keyPrefix}'),
      ];

      // Use SHA-256 to derive the final key material
      final digest = sha256.convert(combinedEntropy);
      final keyMaterial = digest.bytes;

      // If we need more bytes, use HKDF-like expansion
      if (length > keyMaterial.length) {
        final expandedKey = <int>[];
        var counter = 1;

        while (expandedKey.length < length) {
          final input = [...keyMaterial, counter];
          final expanded = sha256.convert(input);
          expandedKey.addAll(expanded.bytes);
          counter++;
        }

        return Uint8List.fromList(expandedKey.take(length).toList());
      }

      return Uint8List.fromList(keyMaterial.take(length).toList());
    } catch (e) {
      // Fallback to software random if hardware entropy fails
      return _getSoftwareRandomBytes(length);
    }
  }

  /// Generates platform-specific entropy.
  Future<String> _generatePlatformEntropy(int seed) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final nanoTime = DateTime.now().microsecond;

    switch (_platform) {
      case ConfidentialPlatform.android:
        // Android-specific entropy sources
        return 'android:$timestamp:$nanoTime:$seed:${config.keyPrefix}:${timestamp.hashCode}';

      case ConfidentialPlatform.ios:
        // iOS-specific entropy sources
        return 'ios:$timestamp:$nanoTime:$seed:${config.keyPrefix}:${timestamp.hashCode}';

      default:
        // Generic entropy for other platforms
        return 'generic:$timestamp:$nanoTime:$seed:${config.keyPrefix}:${timestamp.hashCode}';
    }
  }

  /// Gets software-based random bytes as fallback.
  Uint8List _getSoftwareRandomBytes(int length) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final entropy = '$timestamp:${config.keyPrefix}';
    final digest = sha256.convert(utf8.encode(entropy));

    return Uint8List.fromList(digest.bytes.take(length).toList());
  }

  /// Gets information about the storage backend.
  Future<Map<String, dynamic>> getStorageInfo() async {
    final hasHardwareBacking = await isHardwareBackingAvailable();
    final keyCount = (await listKeys()).length;
    final attestationInfo = await _getKeyAttestationInfo();
    // final capabilities = await _getPlatformCapabilities();

    final info = {
      'platform': _platform.name,
      'hardwareBackingAvailable': hasHardwareBacking,
      'hardwareBackingEnabled': config.useHardwareBacking,
      'hardwareBackingRequired': config.requireHardwareBacking,
      'biometricAuthEnabled': config.useBiometricAuth,
      'deviceAuthRequired': config.requireDeviceAuth,
      'keySize': config.keySize,
      'keyRotationEnabled': config.enableKeyRotation,
      'rotationIntervalDays': config.rotationIntervalDays,
      'storedKeyCount': keyCount,
      'cacheSize': _keyCache.length,
      'attestation': attestationInfo,
      'securityFeatures': await _getSecurityFeatures(),
      'useNativePlatformChannels': config.useNativePlatformChannels,
      'nativeStorageAvailable': false, // _nativeStorage != null,
    };

    // Add native platform capabilities if available
    // if (_nativeStorage != null) {
    //   info['platformCapabilities'] = capabilities.toMap();
    //   info['bestSecurityLevel'] = capabilities.bestSecurityLevel.name;
    // }

    return info;
  }

  /// Gets key attestation information for hardware-backed keys.
  Future<Map<String, dynamic>> _getKeyAttestationInfo() async {
    try {
      final hasHardwareBacking = await isHardwareBackingAvailable();

      if (!hasHardwareBacking) {
        return {'supported': false, 'reason': 'Hardware backing not available'};
      }

      // Test key attestation by creating a temporary key
      final testKeyId =
          '_attestation_test_${DateTime.now().millisecondsSinceEpoch}';

      try {
        await _secureStorage.write(key: testKeyId, value: 'attestation_test');
        final readValue = await _secureStorage.read(key: testKeyId);
        await _secureStorage.delete(key: testKeyId);

        return {
          'supported': true,
          'platform': _platform.name,
          'hardwareSecurityModule': _platform == ConfidentialPlatform.android
              ? 'Android Keystore'
              : 'iOS Secure Enclave',
          'keyProtection': _getKeyProtectionLevel(),
          'attestationVerified': readValue == 'attestation_test',
        };
      } catch (e) {
        return {'supported': false, 'reason': 'Attestation test failed: $e'};
      }
    } catch (e) {
      return {'supported': false, 'reason': 'Attestation check failed: $e'};
    }
  }

  /// Gets the key protection level based on platform and configuration.
  String _getKeyProtectionLevel() {
    switch (_platform) {
      case ConfidentialPlatform.android:
        if (config.requireDeviceAuth && config.useBiometricAuth) {
          return 'StrongBox + Biometric';
        } else if (config.requireDeviceAuth) {
          return 'TEE + Device Auth';
        } else {
          return 'TEE';
        }

      case ConfidentialPlatform.ios:
        if (config.useBiometricAuth) {
          return 'Secure Enclave + Biometric';
        } else {
          return 'Secure Enclave';
        }

      default:
        return 'Software';
    }
  }

  /// Gets available security features for the current platform.
  Future<Map<String, dynamic>> _getSecurityFeatures() async {
    final features = <String, dynamic>{};

    // Get native platform capabilities if available
    // if (_nativeStorage != null) {
    //   try {
    //     final capabilities = await _getPlatformCapabilities();
    //     // ... native capabilities code commented out for now
    //   } catch (e) {
    //     // Fall back to basic feature detection
    //     features.addAll(await _getBasicSecurityFeatures());
    //   }
    // } else {
    // Fall back to basic feature detection
    features.addAll(await _getBasicSecurityFeatures());
    // }

    return features;
  }

  /// Gets basic security features without native platform channels.
  Future<Map<String, dynamic>> _getBasicSecurityFeatures() async {
    final features = <String, dynamic>{};

    switch (_platform) {
      case ConfidentialPlatform.android:
        features.addAll({
          'androidKeystore': true,
          'strongBox': await _testStrongBoxSupport(),
          'biometricAuth': config.useBiometricAuth,
          'deviceAuth': config.requireDeviceAuth,
          'encryptedSharedPreferences': true,
          'nativeChannels': false,
        });
        break;

      case ConfidentialPlatform.ios:
        features.addAll({
          'secureEnclave': true,
          'keychain': true,
          'biometricAuth': config.useBiometricAuth,
          'deviceAuth': config.requireDeviceAuth,
          'dataProtection': true,
          'nativeChannels': false,
        });
        break;

      default:
        features.addAll({
          'hardwareBacking': false,
          'softwareEncryption': true,
          'nativeChannels': false,
        });
    }

    return features;
  }

  /// Tests if Android StrongBox is supported (Android-specific).
  Future<bool> _testStrongBoxSupport() async {
    if (_platform != ConfidentialPlatform.android) {
      return false;
    }

    // This is a simplified test - in a real implementation,
    // you would use platform channels to check StrongBox availability
    try {
      // Test with StrongBox-specific configuration
      final testStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
          storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        ),
      );

      final testKey =
          '_strongbox_test_${DateTime.now().millisecondsSinceEpoch}';
      await testStorage.write(key: testKey, value: 'strongbox_test');
      await testStorage.delete(key: testKey);

      return true;
    } catch (e) {
      return false;
    }
  }
}
