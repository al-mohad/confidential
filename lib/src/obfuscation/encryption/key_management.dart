/// Key management and rotation system for dart-confidential.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../obfuscation.dart';

/// Configuration for key management.
class KeyManagementConfig {
  /// Whether key rotation is enabled.
  final bool enableRotation;

  /// Key rotation interval in days.
  final int rotationIntervalDays;

  /// Maximum number of old keys to keep for backward compatibility.
  final int maxOldKeys;

  /// Key derivation function to use.
  final String keyDerivationFunction;

  /// Number of iterations for key derivation.
  final int keyDerivationIterations;

  /// Salt for key derivation.
  final String? salt;

  const KeyManagementConfig({
    this.enableRotation = false,
    this.rotationIntervalDays = 30,
    this.maxOldKeys = 3,
    this.keyDerivationFunction = 'PBKDF2',
    this.keyDerivationIterations = 100000,
    this.salt,
  });

  /// Creates configuration from a map.
  factory KeyManagementConfig.fromMap(Map<String, dynamic> map) {
    return KeyManagementConfig(
      enableRotation: map['enableRotation'] as bool? ?? false,
      rotationIntervalDays: map['rotationIntervalDays'] as int? ?? 30,
      maxOldKeys: map['maxOldKeys'] as int? ?? 3,
      keyDerivationFunction:
          map['keyDerivationFunction'] as String? ?? 'PBKDF2',
      keyDerivationIterations: map['keyDerivationIterations'] as int? ?? 100000,
      salt: map['salt'] as String?,
    );
  }

  /// Converts configuration to a map.
  Map<String, dynamic> toMap() {
    return {
      'enableRotation': enableRotation,
      'rotationIntervalDays': rotationIntervalDays,
      'maxOldKeys': maxOldKeys,
      'keyDerivationFunction': keyDerivationFunction,
      'keyDerivationIterations': keyDerivationIterations,
      if (salt != null) 'salt': salt,
    };
  }
}

/// Represents a versioned encryption key.
class VersionedKey {
  /// The key version.
  final int version;

  /// The key data.
  final Uint8List keyData;

  /// When the key was created.
  final DateTime createdAt;

  /// When the key expires (optional).
  final DateTime? expiresAt;

  /// Whether this key is active for encryption.
  final bool isActive;

  const VersionedKey({
    required this.version,
    required this.keyData,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  /// Creates a key from a map.
  factory VersionedKey.fromMap(Map<String, dynamic> map) {
    return VersionedKey(
      version: map['version'] as int,
      keyData: Uint8List.fromList((map['keyData'] as List).cast<int>()),
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Converts key to a map.
  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'keyData': keyData.toList(),
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Checks if the key is expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

/// Key manager for handling key rotation and versioning.
class KeyManager {
  final KeyManagementConfig config;
  final Map<int, VersionedKey> _keys = {};
  int _currentVersion = 1;

  KeyManager(this.config);

  /// Gets the current active key for encryption.
  VersionedKey? get currentKey {
    return _keys.values
        .where((key) => key.isActive && !key.isExpired)
        .fold<VersionedKey?>(null, (current, key) {
          if (current == null || key.version > current.version) {
            return key;
          }
          return current;
        });
  }

  /// Gets a key by version for decryption.
  VersionedKey? getKeyByVersion(int version) {
    return _keys[version];
  }

  /// Generates a new key version.
  VersionedKey generateNewKey(int nonce, int keySize) {
    final keyData = _deriveKey(nonce, keySize, _currentVersion);

    final expiresAt = config.enableRotation
        ? DateTime.now().add(Duration(days: config.rotationIntervalDays))
        : null;

    final key = VersionedKey(
      version: _currentVersion,
      keyData: keyData,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      isActive: true,
    );

    _keys[_currentVersion] = key;
    _currentVersion++;

    // Clean up old keys if needed
    _cleanupOldKeys();

    return key;
  }

  /// Rotates keys if needed.
  bool rotateIfNeeded(int nonce, int keySize) {
    if (!config.enableRotation) return false;

    final current = currentKey;
    if (current == null) {
      generateNewKey(nonce, keySize);
      return true;
    }

    // Check if rotation is needed
    final rotationThreshold = DateTime.now().subtract(
      Duration(days: config.rotationIntervalDays),
    );

    if (current.createdAt.isBefore(rotationThreshold)) {
      // Deactivate current key
      _keys[current.version] = VersionedKey(
        version: current.version,
        keyData: current.keyData,
        createdAt: current.createdAt,
        expiresAt: current.expiresAt,
        isActive: false,
      );

      // Generate new key
      generateNewKey(nonce, keySize);
      return true;
    }

    return false;
  }

  /// Derives a key using the configured KDF.
  Uint8List _deriveKey(int nonce, int keySize, int version) {
    final password = _generatePassword(nonce, version);
    final salt = _getSalt();

    switch (config.keyDerivationFunction.toUpperCase()) {
      case 'PBKDF2':
        return _pbkdf2(password, salt, keySize);
      case 'SCRYPT':
        return _scrypt(password, salt, keySize);
      default:
        throw ObfuscationException(
          'Unsupported key derivation function: ${config.keyDerivationFunction}',
        );
    }
  }

  Uint8List _generatePassword(int nonce, int version) {
    // Combine nonce and version to create a unique password
    final combined = '$nonce:$version';
    return Uint8List.fromList(utf8.encode(combined));
  }

  Uint8List _getSalt() {
    if (config.salt != null) {
      return Uint8List.fromList(utf8.encode(config.salt!));
    }

    // Generate a deterministic salt
    const defaultSalt = 'dart-confidential-default-salt';
    return Uint8List.fromList(utf8.encode(defaultSalt));
  }

  Uint8List _pbkdf2(Uint8List password, Uint8List salt, int keySize) {
    final keyBytes = keySize ~/ 8;
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));

    pbkdf2.init(
      Pbkdf2Parameters(salt, config.keyDerivationIterations, keyBytes),
    );

    return pbkdf2.process(password);
  }

  Uint8List _scrypt(Uint8List password, Uint8List salt, int keySize) {
    final keyBytes = keySize ~/ 8;
    final scrypt = Scrypt();

    // Use reasonable scrypt parameters
    scrypt.init(ScryptParameters(16384, 8, 1, keyBytes, salt));

    return scrypt.process(password);
  }

  void _cleanupOldKeys() {
    if (_keys.length <= config.maxOldKeys + 1) return;

    // Sort keys by version and keep only the most recent ones
    final sortedVersions = _keys.keys.toList()..sort();
    final toRemove = sortedVersions.length - config.maxOldKeys - 1;

    for (int i = 0; i < toRemove; i++) {
      _keys.remove(sortedVersions[i]);
    }
  }

  /// Exports key data for backup/storage.
  Map<String, dynamic> exportKeys() {
    return {
      'currentVersion': _currentVersion,
      'keys': _keys.map(
        (version, key) => MapEntry(version.toString(), key.toMap()),
      ),
      'config': config.toMap(),
    };
  }

  /// Imports key data from backup/storage.
  void importKeys(Map<String, dynamic> data) {
    _currentVersion = data['currentVersion'] as int;

    final keysData = data['keys'] as Map<String, dynamic>;
    _keys.clear();

    for (final entry in keysData.entries) {
      final version = int.parse(entry.key);
      final keyData = entry.value as Map<String, dynamic>;
      _keys[version] = VersionedKey.fromMap(keyData);
    }
  }
}
