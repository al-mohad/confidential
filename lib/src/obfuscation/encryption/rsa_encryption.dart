/// RSA encryption implementation for dart-confidential.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../obfuscation.dart';
import 'encryption.dart';

/// RSA encryption algorithm with OAEP padding.
class RsaEncryption extends EncryptionAlgorithm {
  final int keySize;
  final String hashAlgorithm;

  const RsaEncryption(this.keySize, {this.hashAlgorithm = 'SHA-256'}) : super();

  @override
  String get name => 'rsa-$keySize-oaep-${hashAlgorithm.toLowerCase()}';

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    try {
      final keyPair = _generateKeyPair(nonce);
      final publicKey = keyPair.publicKey as RSAPublicKey;

      // RSA can only encrypt data smaller than key size minus padding
      final maxBlockSize = (keySize ~/ 8) - 2 * 32 - 2; // OAEP padding overhead

      if (data.length <= maxBlockSize) {
        // Single block encryption
        final cipher = _createCipher();
        cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

        final encrypted = cipher.process(data);

        // Prepend key information for decryption
        final keyBytes = _encodePublicKey(publicKey);
        final result = Uint8List(4 + keyBytes.length + encrypted.length);

        // Store key length
        result.setRange(0, 4, _intToBytes(keyBytes.length));
        // Store public key
        result.setRange(4, 4 + keyBytes.length, keyBytes);
        // Store encrypted data
        result.setRange(4 + keyBytes.length, result.length, encrypted);

        return result;
      } else {
        // Multi-block encryption with hybrid approach
        return _hybridEncrypt(data, publicKey, nonce);
      }
    } catch (e) {
      throw ObfuscationException('RSA encryption failed', e);
    }
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    try {
      final keyPair = _generateKeyPair(nonce);
      final privateKey = keyPair.privateKey as RSAPrivateKey;

      // Extract key length
      final keyLength = _bytesToInt(data.sublist(0, 4));

      // Skip public key (we have the private key)
      final encryptedData = data.sublist(4 + keyLength);

      // Check if this is hybrid encryption
      if (encryptedData.length > (keySize ~/ 8)) {
        return _hybridDecrypt(encryptedData, privateKey);
      } else {
        // Single block decryption
        final cipher = _createCipher();
        cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

        return cipher.process(encryptedData);
      }
    } catch (e) {
      throw ObfuscationException('RSA decryption failed', e);
    }
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateKeyPair(int nonce) {
    final keyGen = RSAKeyGenerator();
    final random = FortunaRandom();

    // Seed the random number generator deterministically
    final seed = Uint8List(32);
    final seedRandom = Random(nonce);
    for (int i = 0; i < 32; i++) {
      seed[i] = seedRandom.nextInt(256);
    }
    random.seed(KeyParameter(seed));

    final params = RSAKeyGeneratorParameters(
      BigInt.from(65537), // Standard public exponent
      keySize,
      64, // Certainty for prime generation
    );

    keyGen.init(ParametersWithRandom(params, random));
    return keyGen.generateKeyPair();
  }

  OAEPEncoding _createCipher() {
    switch (hashAlgorithm.toUpperCase()) {
      case 'SHA-1':
        return OAEPEncoding.withSHA1(RSAEngine());
      case 'SHA-256':
        return OAEPEncoding.withSHA256(RSAEngine());
      case 'SHA-512':
        return OAEPEncoding.withSHA512(RSAEngine());
      default:
        return OAEPEncoding.withSHA256(RSAEngine()); // Default to SHA-256
    }
  }

  Uint8List _encodePublicKey(RSAPublicKey publicKey) {
    // Simple encoding: modulus length + modulus + exponent length + exponent
    final modulusBytes = _bigIntToBytes(publicKey.modulus!);
    final exponentBytes = _bigIntToBytes(publicKey.exponent!);

    final result = Uint8List(8 + modulusBytes.length + exponentBytes.length);
    int offset = 0;

    // Modulus length and data
    result.setRange(offset, offset + 4, _intToBytes(modulusBytes.length));
    offset += 4;
    result.setRange(offset, offset + modulusBytes.length, modulusBytes);
    offset += modulusBytes.length;

    // Exponent length and data
    result.setRange(offset, offset + 4, _intToBytes(exponentBytes.length));
    offset += 4;
    result.setRange(offset, offset + exponentBytes.length, exponentBytes);

    return result;
  }

  Uint8List _hybridEncrypt(Uint8List data, RSAPublicKey publicKey, int nonce) {
    // Generate AES key for data encryption
    final aesKey = Uint8List(32);
    final random = Random(nonce + 1);
    for (int i = 0; i < 32; i++) {
      aesKey[i] = random.nextInt(256);
    }

    // Encrypt data with AES-GCM
    final aesGcm = AesGcmEncryption(256);
    final encryptedData = aesGcm.obfuscate(data, nonce + 2);

    // Encrypt AES key with RSA
    final cipher = _createCipher();
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encryptedKey = cipher.process(aesKey);

    // Combine: key length + encrypted key + encrypted data
    final result = Uint8List(4 + encryptedKey.length + encryptedData.length);
    result.setRange(0, 4, _intToBytes(encryptedKey.length));
    result.setRange(4, 4 + encryptedKey.length, encryptedKey);
    result.setRange(4 + encryptedKey.length, result.length, encryptedData);

    return result;
  }

  Uint8List _hybridDecrypt(Uint8List data, RSAPrivateKey privateKey) {
    // Extract encrypted key length
    final keyLength = _bytesToInt(data.sublist(0, 4));
    final encryptedKey = data.sublist(4, 4 + keyLength);
    final encryptedData = data.sublist(4 + keyLength);

    // Decrypt AES key with RSA
    final cipher = _createCipher();
    cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    cipher.process(encryptedKey); // Decrypt the AES key

    // Decrypt data with AES-GCM
    final aesGcm = AesGcmEncryption(256);
    // We need to reconstruct the nonce, but for hybrid we use a different approach
    // For now, we'll use a fixed nonce offset
    return aesGcm.deobfuscate(encryptedData, 12345); // This needs improvement
  }

  Uint8List _bigIntToBytes(BigInt bigInt) {
    final bytes = <int>[];
    var value = bigInt;

    if (value == BigInt.zero) {
      return Uint8List.fromList([0]);
    }

    while (value > BigInt.zero) {
      bytes.insert(0, (value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }

    return Uint8List.fromList(bytes);
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
