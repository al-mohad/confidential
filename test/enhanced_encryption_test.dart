import 'dart:convert';
import 'dart:typed_data';

import 'package:confidential/src/obfuscation/encryption/encryption.dart';
import 'package:confidential/src/obfuscation/encryption/key_management.dart';
import 'package:confidential/src/obfuscation/encryption/rsa_encryption.dart';
import 'package:test/test.dart';

void main() {
  group('Enhanced Encryption Tests', () {
    test('AES-256-GCM with key management', () {
      final keyConfig = KeyManagementConfig(
        enableRotation: true,
        rotationIntervalDays: 30,
        maxOldKeys: 3,
        keyDerivationFunction: 'PBKDF2',
        keyDerivationIterations: 10000, // Reduced for testing
      );

      final keyManager = KeyManager(keyConfig);
      final algorithm = AesGcmEncryption(256, keyManager: keyManager);

      final data = Uint8List.fromList(utf8.encode('Hello, Enhanced World!'));
      final nonce = 12345;

      // Generate initial key
      keyManager.generateNewKey(nonce, 256);

      // Test encryption with key rotation
      final encrypted = algorithm.encryptWithKeyRotation(data, nonce);
      final decrypted = algorithm.decryptWithKeyRotation(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('Hello, Enhanced World!'));
    });

    test('ChaCha20-Poly1305 with proper implementation', () {
      final algorithm = ChaCha20Poly1305Encryption();
      final data = Uint8List.fromList(utf8.encode('ChaCha20 Test Data'));
      final nonce = 54321;

      final encrypted = algorithm.obfuscate(data, nonce);
      final decrypted = algorithm.deobfuscate(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('ChaCha20 Test Data'));
    });

    test('ChaCha20-Poly1305 with key management', () {
      final keyConfig = KeyManagementConfig(
        enableRotation: false,
        keyDerivationFunction: 'PBKDF2',
        keyDerivationIterations: 5000,
      );

      final keyManager = KeyManager(keyConfig);
      final algorithm = ChaCha20Poly1305Encryption(keyManager: keyManager);

      final data = Uint8List.fromList(
        utf8.encode('ChaCha20 with Key Management'),
      );
      final nonce = 98765;

      // Generate initial key
      keyManager.generateNewKey(nonce, 256);

      final encrypted = algorithm.encryptWithKeyRotation(data, nonce);
      final decrypted = algorithm.decryptWithKeyRotation(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('ChaCha20 with Key Management'));
    });

    test('RSA-2048 encryption/decryption', () {
      final algorithm = RsaEncryption(2048);
      final data = Uint8List.fromList(utf8.encode('RSA Test Data'));
      final nonce = 11111;

      final encrypted = algorithm.obfuscate(data, nonce);
      final decrypted = algorithm.deobfuscate(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('RSA Test Data'));
    });

    test('RSA-4096 with SHA-512', () {
      final algorithm = RsaEncryption(4096, hashAlgorithm: 'SHA-512');
      final data = Uint8List.fromList(utf8.encode('RSA-4096 SHA-512 Test'));
      final nonce = 22222;

      final encrypted = algorithm.obfuscate(data, nonce);
      final decrypted = algorithm.deobfuscate(encrypted, nonce);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('RSA-4096 SHA-512 Test'));
    });

    test('Key rotation functionality', () {
      final keyConfig = KeyManagementConfig(
        enableRotation: true,
        rotationIntervalDays: 1, // Very short for testing
        maxOldKeys: 2,
      );

      final keyManager = KeyManager(keyConfig);

      // Generate initial key
      final key1 = keyManager.generateNewKey(12345, 256);
      expect(key1.version, equals(1));
      expect(keyManager.currentKey?.version, equals(1));

      // Simulate time passing and force rotation
      final key2 = keyManager.generateNewKey(12346, 256);
      expect(key2.version, equals(2));
      expect(keyManager.currentKey?.version, equals(2));

      // Verify we can still access old key
      final oldKey = keyManager.getKeyByVersion(1);
      expect(oldKey, isNotNull);
      expect(oldKey!.version, equals(1));
    });

    test('Key derivation with different functions', () {
      final pbkdf2Config = KeyManagementConfig(
        keyDerivationFunction: 'PBKDF2',
        keyDerivationIterations: 1000,
        salt: 'test-salt-pbkdf2',
      );

      final scryptConfig = KeyManagementConfig(
        keyDerivationFunction: 'SCRYPT',
        salt: 'test-salt-scrypt',
      );

      final pbkdf2Manager = KeyManager(pbkdf2Config);
      final scryptManager = KeyManager(scryptConfig);

      final pbkdf2Key = pbkdf2Manager.generateNewKey(12345, 256);
      final scryptKey = scryptManager.generateNewKey(12345, 256);

      // Keys should be different due to different KDFs
      expect(pbkdf2Key.keyData, isNot(equals(scryptKey.keyData)));
    });

    test('EncryptionFactory creates correct algorithms', () {
      expect(EncryptionFactory.create('aes-256-gcm'), isA<AesGcmEncryption>());
      expect(
        EncryptionFactory.create('chacha20-poly1305'),
        isA<ChaCha20Poly1305Encryption>(),
      );
      expect(EncryptionFactory.create('rsa-2048'), isA<RsaEncryption>());
      expect(EncryptionFactory.create('rsa-4096-sha256'), isA<RsaEncryption>());
    });

    test('EncryptionFactory with key manager', () {
      final keyConfig = KeyManagementConfig();
      final keyManager = KeyManager(keyConfig);

      final aes = EncryptionFactory.create(
        'aes-256-gcm',
        keyManager: keyManager,
      );
      expect(aes, isA<AesGcmEncryption>());
      expect((aes as AesGcmEncryption).keyManager, equals(keyManager));
    });

    test('Supported algorithms list includes new algorithms', () {
      final supported = EncryptionFactory.supportedAlgorithms;

      expect(supported, contains('aes-256-gcm'));
      expect(supported, contains('chacha20-poly1305'));
      expect(supported, contains('rsa-2048'));
      expect(supported, contains('rsa-4096'));
      expect(supported, contains('rsa-2048-sha256'));
      expect(supported, contains('rsa-4096-sha256'));
      expect(supported, contains('rsa-2048-sha512'));
      expect(supported, contains('rsa-4096-sha512'));
    });

    test('Key management configuration serialization', () {
      final config = KeyManagementConfig(
        enableRotation: true,
        rotationIntervalDays: 45,
        maxOldKeys: 5,
        keyDerivationFunction: 'SCRYPT',
        keyDerivationIterations: 50000,
        salt: 'custom-salt',
      );

      final map = config.toMap();
      final restored = KeyManagementConfig.fromMap(map);

      expect(restored.enableRotation, equals(config.enableRotation));
      expect(
        restored.rotationIntervalDays,
        equals(config.rotationIntervalDays),
      );
      expect(restored.maxOldKeys, equals(config.maxOldKeys));
      expect(
        restored.keyDerivationFunction,
        equals(config.keyDerivationFunction),
      );
      expect(
        restored.keyDerivationIterations,
        equals(config.keyDerivationIterations),
      );
      expect(restored.salt, equals(config.salt));
    });

    test('Versioned key serialization', () {
      final key = VersionedKey(
        version: 42,
        keyData: Uint8List.fromList([1, 2, 3, 4, 5]),
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        expiresAt: DateTime.parse('2024-02-01T12:00:00Z'),
        isActive: true,
      );

      final map = key.toMap();
      final restored = VersionedKey.fromMap(map);

      expect(restored.version, equals(key.version));
      expect(restored.keyData, equals(key.keyData));
      expect(restored.createdAt, equals(key.createdAt));
      expect(restored.expiresAt, equals(key.expiresAt));
      expect(restored.isActive, equals(key.isActive));
    });

    test('Key manager export/import', () {
      final config = KeyManagementConfig(enableRotation: true);
      final manager = KeyManager(config);

      // Generate some keys
      manager.generateNewKey(1, 256);
      manager.generateNewKey(2, 256);

      // Export and import
      final exported = manager.exportKeys();
      final newManager = KeyManager(config);
      newManager.importKeys(exported);

      // Verify keys are preserved
      expect(newManager.getKeyByVersion(1), isNotNull);
      expect(newManager.getKeyByVersion(2), isNotNull);
      expect(newManager.currentKey?.version, equals(2));
    });
  });
}
