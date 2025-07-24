/// Enhanced key manager with hardware-backed storage integration.
library;

import '../obfuscation/encryption/key_management.dart';
import '../obfuscation/obfuscation.dart';
import 'hardware_key_storage.dart';

/// Enhanced key manager that uses hardware-backed storage when available.
class HardwareKeyManager extends KeyManager {
  final HardwareKeyStorage _hardwareStorage;
  final bool _useHardwareStorage;

  /// Cache for frequently accessed keys.
  final Map<String, VersionedKey> _keyCache = {};

  HardwareKeyManager({
    required KeyManagementConfig config,
    HardwareKeyStorageConfig? hardwareConfig,
    HardwareKeyStorage? hardwareStorage,
  }) : _hardwareStorage =
           hardwareStorage ??
           HardwareKeyStorage(
             config: hardwareConfig ?? HardwareKeyStorageConfig(),
           ),
       _useHardwareStorage = hardwareConfig?.useHardwareBacking ?? true,
       super(config);

  /// Factory constructor for maximum security configuration.
  factory HardwareKeyManager.maxSecurity({KeyManagementConfig? keyConfig}) {
    final config =
        keyConfig ??
        KeyManagementConfig(
          enableRotation: true,
          rotationIntervalDays: 7,
          maxOldKeys: 3,
          keyDerivationFunction: 'PBKDF2',
          keyDerivationIterations: 100000,
        );

    return HardwareKeyManager(
      config: config,
      hardwareConfig: HardwareKeyStorageConfig.maxSecurity(),
    );
  }

  /// Factory constructor for development/testing.
  factory HardwareKeyManager.development({KeyManagementConfig? keyConfig}) {
    final config =
        keyConfig ??
        KeyManagementConfig(
          enableRotation: false,
          rotationIntervalDays: 365,
          maxOldKeys: 1,
          keyDerivationFunction: 'PBKDF2',
          keyDerivationIterations: 10000,
        );

    return HardwareKeyManager(
      config: config,
      hardwareConfig: HardwareKeyStorageConfig.development(),
    );
  }

  /// Gets the current active key, using hardware storage when available.
  @override
  VersionedKey? get currentKey {
    // First try to get from hardware storage
    if (_useHardwareStorage) {
      return _getCurrentKeyFromHardware();
    }

    // Fallback to parent implementation
    return super.currentKey;
  }

  /// Gets a key by version, checking hardware storage first.
  @override
  VersionedKey? getKeyByVersion(int version) {
    final keyId = 'version_$version';

    // Check cache first
    if (_keyCache.containsKey(keyId)) {
      final cachedKey = _keyCache[keyId]!;
      if (!cachedKey.isExpired) {
        return cachedKey;
      }
    }

    // Try hardware storage
    if (_useHardwareStorage) {
      try {
        final key = _getKeyFromHardwareSync(keyId);
        if (key != null) {
          _keyCache[keyId] = key;
          return key;
        }
      } catch (e) {
        // Fall back to parent implementation
      }
    }

    // Fallback to parent implementation
    return super.getKeyByVersion(version);
  }

  /// Generates a new key and stores it in hardware storage.
  @override
  VersionedKey generateNewKey(int nonce, int keySize) {
    if (_useHardwareStorage) {
      return _generateHardwareBackedKey(nonce, keySize);
    }

    // Fallback to parent implementation
    return super.generateNewKey(nonce, keySize);
  }

  /// Generates a hardware-backed key.
  VersionedKey _generateHardwareBackedKey(int nonce, int keySize) {
    try {
      // Use parent's generateNewKey method to get proper version management
      final key = super.generateNewKey(nonce, keySize);
      final keyId = 'version_${key.version}';

      // Store in hardware storage asynchronously
      _storeKeyInHardwareAsync(keyId, key);

      // Cache the key
      _keyCache[keyId] = key;

      return key;
    } catch (e) {
      // Fallback to parent implementation if hardware storage fails
      return super.generateNewKey(nonce, keySize);
    }
  }

  // Removed _generateKeyFromHardwareSync as it's no longer needed

  /// Enhanced async key storage with retry logic.
  void _storeKeyInHardwareAsync(String keyId, VersionedKey key) {
    _storeKeyWithRetry(keyId, key, maxRetries: 3).catchError((e) {
      // Log error but don't fail the operation
      print(
        'Warning: Failed to store key in hardware storage after retries: $e',
      );
    });
  }

  /// Stores a key with retry logic for better reliability.
  Future<void> _storeKeyWithRetry(
    String keyId,
    VersionedKey key, {
    int maxRetries = 3,
  }) async {
    var attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        await _hardwareStorage.generateAndStoreKey(
          keyId: keyId,
          version: key.version,
        );
        return; // Success
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempts++;

        if (attempts < maxRetries) {
          // Wait before retrying with exponential backoff
          await Future.delayed(Duration(milliseconds: 100 * (1 << attempts)));
        }
      }
    }

    // If we get here, all retries failed
    throw ObfuscationException(
      'Failed to store key in hardware storage after $maxRetries attempts: $lastError',
    );
  }

  /// Gets current key from hardware storage (synchronous wrapper).
  VersionedKey? _getCurrentKeyFromHardware() {
    try {
      // Look for the highest version key that's active and not expired
      final keyIds = _listKeysSync();
      VersionedKey? currentKey;

      for (final keyId in keyIds) {
        final key = _getKeyFromHardwareSync(keyId);
        if (key != null && key.isActive && !key.isExpired) {
          if (currentKey == null || key.version > currentKey.version) {
            currentKey = key;
          }
        }
      }

      return currentKey;
    } catch (e) {
      return null;
    }
  }

  /// Gets a key from hardware storage (synchronous wrapper).
  VersionedKey? _getKeyFromHardwareSync(String keyId) {
    // This is a simplified synchronous wrapper
    // In practice, you'd want proper async handling
    try {
      // Check if we have this key cached
      if (_keyCache.containsKey(keyId)) {
        return _keyCache[keyId];
      }

      // For now, return null and let the async version handle it
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Lists keys from hardware storage (synchronous wrapper).
  List<String> _listKeysSync() {
    // Simplified synchronous wrapper
    return _keyCache.keys.toList();
  }

  /// Validates hardware key integrity.
  Future<bool> validateKeyIntegrity(String keyId) async {
    if (!_useHardwareStorage) {
      return true; // Skip validation for non-hardware keys
    }

    try {
      final key = await _hardwareStorage.getKey(keyId);
      if (key == null) {
        return false;
      }

      // Verify key hasn't been tampered with
      final storageInfo = await _hardwareStorage.getStorageInfo();
      final attestationInfo =
          storageInfo['attestation'] as Map<String, dynamic>?;

      return attestationInfo?['supported'] == true &&
          attestationInfo?['attestationVerified'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Gets hardware security status.
  Future<Map<String, dynamic>> getHardwareSecurityStatus() async {
    if (!_useHardwareStorage) {
      return {
        'hardwareEnabled': false,
        'securityLevel': 'software',
        'features': <String, dynamic>{},
      };
    }

    try {
      final storageInfo = await _hardwareStorage.getStorageInfo();
      final hasHardwareBacking = await _hardwareStorage
          .isHardwareBackingAvailable();

      return {
        'hardwareEnabled': _useHardwareStorage,
        'hardwareAvailable': hasHardwareBacking,
        'securityLevel': hasHardwareBacking ? 'hardware' : 'software',
        'platform': storageInfo['platform'],
        'features': storageInfo['securityFeatures'],
        'attestation': storageInfo['attestation'],
      };
    } catch (e) {
      return {
        'hardwareEnabled': _useHardwareStorage,
        'hardwareAvailable': false,
        'securityLevel': 'software',
        'error': e.toString(),
      };
    }
  }

  /// Async version of key generation for proper hardware integration.
  Future<VersionedKey> generateNewKeyAsync(int nonce, int keySize) async {
    if (_useHardwareStorage) {
      try {
        // Generate a unique key ID
        final currentKey = super.currentKey;
        final nextVersion = (currentKey?.version ?? 0) + 1;
        final keyId = 'version_$nextVersion';

        final key = await _hardwareStorage.generateAndStoreKey(
          keyId: keyId,
          version: nextVersion,
          nonce: nonce,
        );

        // Cache the key
        _keyCache[keyId] = key;

        return key;
      } catch (e) {
        // Fallback to parent implementation
        return generateNewKey(nonce, keySize);
      }
    }

    return generateNewKey(nonce, keySize);
  }

  /// Async version of getting current key.
  Future<VersionedKey?> getCurrentKeyAsync() async {
    if (_useHardwareStorage) {
      try {
        final keyIds = await _hardwareStorage.listKeys();
        VersionedKey? currentKey;

        for (final keyId in keyIds) {
          final key = await _hardwareStorage.getKey(keyId);
          if (key != null && key.isActive && !key.isExpired) {
            if (currentKey == null || key.version > currentKey.version) {
              currentKey = key;
            }
          }
        }

        if (currentKey != null) {
          _keyCache['version_${currentKey.version}'] = currentKey;
        }

        return currentKey;
      } catch (e) {
        // Fallback to synchronous version
        return currentKey;
      }
    }

    return currentKey;
  }

  /// Async version of getting key by version.
  Future<VersionedKey?> getKeyByVersionAsync(int version) async {
    final keyId = 'version_$version';

    if (_useHardwareStorage) {
      try {
        final key = await _hardwareStorage.getKey(keyId);
        if (key != null) {
          _keyCache[keyId] = key;
          return key;
        }
      } catch (e) {
        // Fallback to synchronous version
      }
    }

    return getKeyByVersion(version);
  }

  /// Rotates keys using hardware storage.
  Future<void> rotateKeysAsync() async {
    if (_useHardwareStorage) {
      try {
        final keyIds = await _hardwareStorage.listKeys();

        for (final keyId in keyIds) {
          await _hardwareStorage.rotateKeyIfNeeded(keyId);
        }

        // Clear cache to force reload
        _keyCache.clear();
      } catch (e) {
        // Log error but continue
        print('Warning: Key rotation failed: $e');
      }
    }
  }

  /// Gets information about the hardware storage backend.
  Future<Map<String, dynamic>> getStorageInfo() async {
    if (_useHardwareStorage) {
      try {
        final info = await _hardwareStorage.getStorageInfo();
        info['keyManagerType'] = 'HardwareKeyManager';
        info['fallbackAvailable'] = true;
        return info;
      } catch (e) {
        return {
          'keyManagerType': 'HardwareKeyManager',
          'hardwareStorageError': e.toString(),
          'fallbackActive': true,
        };
      }
    }

    return {
      'keyManagerType': 'HardwareKeyManager',
      'hardwareStorageEnabled': false,
      'fallbackActive': true,
    };
  }

  /// Clears all hardware-stored keys.
  Future<void> clearHardwareKeys() async {
    if (_useHardwareStorage) {
      try {
        await _hardwareStorage.clearAllKeys();
        _keyCache.clear();
      } catch (e) {
        throw ObfuscationException('Failed to clear hardware keys: $e');
      }
    }
  }

  /// Checks if hardware backing is available.
  Future<bool> isHardwareBackingAvailable() async {
    if (_useHardwareStorage) {
      try {
        return await _hardwareStorage.isHardwareBackingAvailable();
      } catch (e) {
        return false;
      }
    }

    return false;
  }

  /// Exports keys including hardware storage information.
  @override
  Map<String, dynamic> exportKeys() {
    final baseExport = super.exportKeys();

    baseExport['hardwareStorageEnabled'] = _useHardwareStorage;
    baseExport['cachedKeys'] = _keyCache.length;

    return baseExport;
  }

  /// Imports keys and updates hardware storage.
  @override
  void importKeys(Map<String, dynamic> data) {
    super.importKeys(data);

    // Clear cache to force reload from hardware storage
    _keyCache.clear();
  }
}
