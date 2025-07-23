/// Encryption-based obfuscation implementations.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../obfuscation.dart';
import 'key_management.dart';
import 'rsa_encryption.dart';

/// Base class for encryption-based obfuscation.
abstract class EncryptionAlgorithm extends ObfuscationAlgorithm {
  const EncryptionAlgorithm();

  @override
  bool get isPolymorphic => true;
}

/// AES-GCM encryption algorithm.
class AesGcmEncryption extends EnhancedEncryptionAlgorithm {
  final int keySize;

  const AesGcmEncryption(this.keySize, {super.keyManager});

  @override
  String get name => 'aes-$keySize-gcm';

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final key = _generateKey(nonce);
      final iv = _generateIV(nonce);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));

      cipher.init(true, params);

      final encrypted = cipher.process(data);

      // Combine IV + encrypted data + tag
      final result = Uint8List(iv.length + encrypted.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, result.length, encrypted);

      return result;
    } catch (e) {
      throw ObfuscationException('AES-GCM encryption failed', e);
    }
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final key = _generateKey(nonce);

      // Extract IV and encrypted data
      final iv = data.sublist(0, 12);
      final encryptedData = data.sublist(12);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));

      cipher.init(false, params);

      return cipher.process(encryptedData);
    } catch (e) {
      throw ObfuscationException('AES-GCM decryption failed', e);
    }
  }

  Uint8List _generateKey(int nonce) {
    final keyBytes = keySize ~/ 8;
    final key = Uint8List(keyBytes);
    final random = Random(nonce);

    for (int i = 0; i < keyBytes; i++) {
      key[i] = random.nextInt(256);
    }

    return key;
  }

  Uint8List _generateIV(int nonce) {
    final iv = Uint8List(12); // GCM standard IV size
    // Add current time to make it truly polymorphic
    final random = Random(nonce + DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < 12; i++) {
      iv[i] = random.nextInt(256);
    }

    return iv;
  }

  @override
  int _getKeySize() => keySize;

  @override
  Uint8List _encryptWithKey(Uint8List data, VersionedKey key) {
    try {
      final iv = _generateIV(key.version);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key.keyData),
        128,
        iv,
        Uint8List(0),
      );

      cipher.init(true, params);

      final encrypted = cipher.process(data);

      // Combine IV + encrypted data + tag
      final result = Uint8List(iv.length + encrypted.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, result.length, encrypted);

      return result;
    } catch (e) {
      throw ObfuscationException(
        'AES-GCM encryption with versioned key failed',
        e,
      );
    }
  }

  @override
  Uint8List _decryptWithKey(Uint8List data, VersionedKey key) {
    try {
      // Extract IV and encrypted data
      final iv = data.sublist(0, 12);
      final encryptedData = data.sublist(12);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key.keyData),
        128,
        iv,
        Uint8List(0),
      );

      cipher.init(false, params);

      return cipher.process(encryptedData);
    } catch (e) {
      throw ObfuscationException(
        'AES-GCM decryption with versioned key failed',
        e,
      );
    }
  }
}

/// ChaCha20-Poly1305 encryption algorithm.
class ChaCha20Poly1305Encryption extends EnhancedEncryptionAlgorithm {
  const ChaCha20Poly1305Encryption({super.keyManager});

  @override
  String get name => 'chacha20-poly1305';

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final key = _generateKey(nonce);
      final iv = _generateNonce(nonce);

      // Create ChaCha20 cipher
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key), iv);
      cipher.init(true, params);

      // Encrypt the data
      final encrypted = Uint8List(data.length);
      cipher.processBytes(data, 0, data.length, encrypted, 0);

      // Create Poly1305 authenticator
      final poly1305 = Poly1305();
      poly1305.init(KeyParameter(_generatePoly1305Key(key, iv)));

      // Add encrypted data to authenticator
      poly1305.update(encrypted, 0, encrypted.length);

      // Generate authentication tag
      final tag = Uint8List(16);
      poly1305.doFinal(tag, 0);

      // Combine nonce + encrypted data + tag
      final result = Uint8List(iv.length + encrypted.length + tag.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, iv.length + encrypted.length, encrypted);
      result.setRange(iv.length + encrypted.length, result.length, tag);

      return result;
    } catch (e) {
      throw ObfuscationException('ChaCha20-Poly1305 encryption failed', e);
    }
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final key = _generateKey(nonce);

      // Extract components
      final iv = data.sublist(0, 8);
      final tag = data.sublist(data.length - 16);
      final encryptedData = data.sublist(8, data.length - 16);

      // Verify authentication tag
      final poly1305 = Poly1305();
      poly1305.init(KeyParameter(_generatePoly1305Key(key, iv)));
      poly1305.update(encryptedData, 0, encryptedData.length);

      final computedTag = Uint8List(16);
      poly1305.doFinal(computedTag, 0);

      // Constant-time comparison
      if (!_constantTimeEquals(tag, computedTag)) {
        throw ObfuscationException('Authentication tag verification failed');
      }

      // Decrypt the data
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key), iv);
      cipher.init(false, params);

      final decrypted = Uint8List(encryptedData.length);
      cipher.processBytes(encryptedData, 0, encryptedData.length, decrypted, 0);

      return decrypted;
    } catch (e) {
      throw ObfuscationException('ChaCha20-Poly1305 decryption failed', e);
    }
  }

  Uint8List _generateKey(int nonce) {
    final key = Uint8List(32); // ChaCha20 key size
    final random = Random(nonce);

    for (int i = 0; i < 32; i++) {
      key[i] = random.nextInt(256);
    }

    return key;
  }

  Uint8List _generateNonce(int nonce) {
    final iv = Uint8List(8); // ChaCha20 nonce size is 8 bytes
    // Add current time to make it truly polymorphic
    final random = Random(nonce + DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < 8; i++) {
      iv[i] = random.nextInt(256);
    }

    return iv;
  }

  Uint8List _generatePoly1305Key(Uint8List chachaKey, Uint8List nonce) {
    // Generate Poly1305 key using ChaCha20 with zero block
    final cipher = ChaCha20Engine();
    final params = ParametersWithIV(KeyParameter(chachaKey), nonce);
    cipher.init(true, params);

    final zeroBlock = Uint8List(64);
    final keyStream = Uint8List(64);
    cipher.processBytes(zeroBlock, 0, 64, keyStream, 0);

    // Return first 32 bytes as Poly1305 key
    return keyStream.sublist(0, 32);
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }

  @override
  int _getKeySize() => 256; // ChaCha20 uses 256-bit keys

  @override
  Uint8List _encryptWithKey(Uint8List data, VersionedKey key) {
    try {
      final iv = _generateNonce(key.version);

      // Create ChaCha20 cipher
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key.keyData), iv);
      cipher.init(true, params);

      // Encrypt the data
      final encrypted = Uint8List(data.length);
      cipher.processBytes(data, 0, data.length, encrypted, 0);

      // Create Poly1305 authenticator
      final poly1305 = Poly1305();
      poly1305.init(KeyParameter(_generatePoly1305Key(key.keyData, iv)));

      // Add encrypted data to authenticator
      poly1305.update(encrypted, 0, encrypted.length);

      // Generate authentication tag
      final tag = Uint8List(16);
      poly1305.doFinal(tag, 0);

      // Combine nonce + encrypted data + tag
      final result = Uint8List(iv.length + encrypted.length + tag.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, iv.length + encrypted.length, encrypted);
      result.setRange(iv.length + encrypted.length, result.length, tag);

      return result;
    } catch (e) {
      throw ObfuscationException(
        'ChaCha20-Poly1305 encryption with versioned key failed',
        e,
      );
    }
  }

  @override
  Uint8List _decryptWithKey(Uint8List data, VersionedKey key) {
    try {
      // Extract components
      final iv = data.sublist(0, 8);
      final tag = data.sublist(data.length - 16);
      final encryptedData = data.sublist(8, data.length - 16);

      // Verify authentication tag
      final poly1305 = Poly1305();
      poly1305.init(KeyParameter(_generatePoly1305Key(key.keyData, iv)));
      poly1305.update(encryptedData, 0, encryptedData.length);

      final computedTag = Uint8List(16);
      poly1305.doFinal(computedTag, 0);

      // Constant-time comparison
      if (!_constantTimeEquals(tag, computedTag)) {
        throw ObfuscationException('Authentication tag verification failed');
      }

      // Decrypt the data
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key.keyData), iv);
      cipher.init(false, params);

      final decrypted = Uint8List(encryptedData.length);
      cipher.processBytes(encryptedData, 0, encryptedData.length, decrypted, 0);

      return decrypted;
    } catch (e) {
      throw ObfuscationException(
        'ChaCha20-Poly1305 decryption with versioned key failed',
        e,
      );
    }
  }
}

/// Enhanced encryption algorithm with key management support.
abstract class EnhancedEncryptionAlgorithm extends EncryptionAlgorithm {
  /// The key manager for this algorithm.
  final KeyManager? keyManager;

  const EnhancedEncryptionAlgorithm({this.keyManager});

  /// Encrypts data using the current key version.
  Uint8List encryptWithKeyRotation(Uint8List data, int nonce) {
    if (keyManager == null) {
      return obfuscate(data, nonce);
    }

    // Check if key rotation is needed
    keyManager!.rotateIfNeeded(nonce, _getKeySize());

    final currentKey = keyManager!.currentKey;
    if (currentKey == null) {
      throw ObfuscationException('No active encryption key available');
    }

    // Encrypt with versioned key
    final encrypted = _encryptWithKey(data, currentKey);

    // Prepend version information
    final result = Uint8List(4 + encrypted.length);
    result.setRange(0, 4, _intToBytes(currentKey.version));
    result.setRange(4, result.length, encrypted);

    return result;
  }

  /// Decrypts data using the specified key version.
  Uint8List decryptWithKeyRotation(Uint8List data, int nonce) {
    if (keyManager == null) {
      return deobfuscate(data, nonce);
    }

    // Extract version
    final version = _bytesToInt(data.sublist(0, 4));
    final encryptedData = data.sublist(4);

    final key = keyManager!.getKeyByVersion(version);
    if (key == null) {
      throw ObfuscationException('Key version $version not found');
    }

    return _decryptWithKey(encryptedData, key);
  }

  /// Gets the key size for this algorithm.
  int _getKeySize();

  /// Encrypts data with a specific key.
  Uint8List _encryptWithKey(Uint8List data, VersionedKey key);

  /// Decrypts data with a specific key.
  Uint8List _decryptWithKey(Uint8List data, VersionedKey key);

  Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}

/// Factory for creating encryption algorithms.
class EncryptionFactory {
  /// Creates an encryption algorithm by name.
  static EncryptionAlgorithm create(String name, {KeyManager? keyManager}) {
    switch (name.toLowerCase()) {
      case 'aes-128-gcm':
        return AesGcmEncryption(128, keyManager: keyManager);
      case 'aes-192-gcm':
        return AesGcmEncryption(192, keyManager: keyManager);
      case 'aes-256-gcm':
        return AesGcmEncryption(256, keyManager: keyManager);
      case 'chacha20-poly1305':
      case 'chacha20-poly':
        return ChaCha20Poly1305Encryption(keyManager: keyManager);
      case 'rsa-2048':
        return const RsaEncryption(2048);
      case 'rsa-4096':
        return const RsaEncryption(4096);
      case 'rsa-2048-sha256':
        return const RsaEncryption(2048, hashAlgorithm: 'SHA-256');
      case 'rsa-4096-sha256':
        return const RsaEncryption(4096, hashAlgorithm: 'SHA-256');
      case 'rsa-2048-sha512':
        return const RsaEncryption(2048, hashAlgorithm: 'SHA-512');
      case 'rsa-4096-sha512':
        return const RsaEncryption(4096, hashAlgorithm: 'SHA-512');
      default:
        throw ObfuscationException('Unknown encryption algorithm: $name');
    }
  }

  /// Gets all supported encryption algorithm names.
  static List<String> get supportedAlgorithms => [
    'aes-128-gcm',
    'aes-192-gcm',
    'aes-256-gcm',
    'chacha20-poly1305',
    'rsa-2048',
    'rsa-4096',
    'rsa-2048-sha256',
    'rsa-4096-sha256',
    'rsa-2048-sha512',
    'rsa-4096-sha512',
  ];
}
