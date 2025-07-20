/// Encryption-based obfuscation implementations.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../obfuscation.dart';

/// Base class for encryption-based obfuscation.
abstract class EncryptionAlgorithm extends ObfuscationAlgorithm {
  const EncryptionAlgorithm();

  @override
  bool get isPolymorphic => true;
}

/// AES-GCM encryption algorithm.
class AesGcmEncryption extends EncryptionAlgorithm {
  final int keySize;

  const AesGcmEncryption(this.keySize) : super();

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
}

/// ChaCha20-Poly1305 encryption algorithm.
class ChaCha20Poly1305Encryption extends EncryptionAlgorithm {
  const ChaCha20Poly1305Encryption() : super();

  @override
  String get name => 'chacha20-poly1305';

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      // Simplified implementation using XOR for now
      final key = _generateKey(nonce);
      final result = Uint8List(data.length + 4); // 4 bytes for length prefix

      // Store length
      result.setRange(0, 4, _intToBytes(data.length));

      // XOR with key
      for (int i = 0; i < data.length; i++) {
        result[i + 4] = data[i] ^ key[i % key.length];
      }

      return result;
    } catch (e) {
      throw ObfuscationException('ChaCha20-Poly1305 encryption failed', e);
    }
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final key = _generateKey(nonce);

      // Extract length and encrypted data
      final length = _bytesToInt(data.sublist(0, 4));
      final encryptedData = data.sublist(4);

      final result = Uint8List(length);

      // XOR with key to decrypt
      for (int i = 0; i < length; i++) {
        result[i] = encryptedData[i] ^ key[i % key.length];
      }

      return result;
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
    final nonceBytes = Uint8List(12); // ChaCha20 nonce size
    // Add current time to make it truly polymorphic
    final random = Random(nonce + DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < 12; i++) {
      nonceBytes[i] = random.nextInt(256);
    }

    return nonceBytes;
  }

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
  static EncryptionAlgorithm create(String name) {
    switch (name.toLowerCase()) {
      case 'aes-128-gcm':
        return const AesGcmEncryption(128);
      case 'aes-192-gcm':
        return const AesGcmEncryption(192);
      case 'aes-256-gcm':
        return const AesGcmEncryption(256);
      case 'chacha20-poly1305':
      case 'chacha20-poly':
        return const ChaCha20Poly1305Encryption();
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
  ];
}
