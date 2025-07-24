/// Hardware-backed encryption implementations for enhanced security.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../platform/hardware_key_manager.dart';
import '../../platform/platform_support.dart';
import '../obfuscation.dart';
import 'encryption.dart';
import 'key_management.dart';

/// AES-GCM encryption with hardware-backed key storage.
class HardwareAesGcmEncryption extends AesGcmEncryption {
  final HardwareKeyManager _keyManager;
  final bool _useHardwareKeys;

  HardwareAesGcmEncryption({
    int keySize = 256,
    HardwareKeyManager? keyManager,
    bool useHardwareKeys = true,
  }) : _keyManager = keyManager ?? HardwareKeyManager.maxSecurity(),
       _useHardwareKeys = useHardwareKeys,
       super(keySize);

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    if (_useHardwareKeys) {
      return _obfuscateWithHardwareKey(data, nonce);
    }

    return super.obfuscate(data, nonce);
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    if (_useHardwareKeys) {
      return _deobfuscateWithHardwareKey(data, nonce);
    }

    return super.deobfuscate(data, nonce);
  }

  /// Encrypts data using hardware-backed keys.
  Uint8List _obfuscateWithHardwareKey(Uint8List data, int nonce) {
    try {
      // Get or generate hardware-backed key
      final key = _getOrGenerateHardwareKey(nonce);

      // Generate IV from nonce
      final iv = _generateIV(nonce);

      // Encrypt using AES-GCM
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key.keyData),
        128,
        iv,
        Uint8List(0),
      );

      cipher.init(true, params);
      final encrypted = cipher.process(data);

      // Combine version + IV + encrypted data + tag
      final result = Uint8List(4 + iv.length + encrypted.length);

      // Store key version for decryption
      result.setRange(0, 4, _intToBytes(key.version));
      result.setRange(4, 4 + iv.length, iv);
      result.setRange(4 + iv.length, result.length, encrypted);

      return result;
    } catch (e) {
      throw ObfuscationException('Hardware AES-GCM encryption failed', e);
    }
  }

  /// Generates IV for AES-GCM encryption.
  Uint8List _generateIV(int nonce) {
    final iv = Uint8List(12); // GCM standard IV size
    // Add current time to make it truly polymorphic
    final random = Random(nonce + DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < 12; i++) {
      iv[i] = random.nextInt(256);
    }

    return iv;
  }

  /// Decrypts data using hardware-backed keys.
  Uint8List _deobfuscateWithHardwareKey(Uint8List data, int nonce) {
    try {
      // Extract key version
      final keyVersion = _bytesToInt(data.sublist(0, 4));

      // Get key by version
      final key = _keyManager.getKeyByVersion(keyVersion);
      if (key == null) {
        throw ObfuscationException('Key version $keyVersion not found');
      }

      // Extract IV and encrypted data
      final iv = data.sublist(4, 4 + 12); // AES-GCM uses 12-byte IV
      final encryptedData = data.sublist(4 + 12);

      // Decrypt using AES-GCM
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
      throw ObfuscationException('Hardware AES-GCM decryption failed', e);
    }
  }

  /// Gets or generates a hardware-backed key for the given nonce.
  VersionedKey _getOrGenerateHardwareKey(int nonce) {
    // Try to get current key
    var currentKey = _keyManager.currentKey;

    if (currentKey == null || currentKey.isExpired) {
      // Generate new key
      currentKey = _keyManager.generateNewKey(nonce, keySize);
    }

    return currentKey;
  }

  /// Converts integer to bytes.
  List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Converts bytes to integer.
  int _bytesToInt(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  /// Gets information about the hardware encryption setup.
  Future<Map<String, dynamic>> getEncryptionInfo() async {
    final storageInfo = await _keyManager.getStorageInfo();

    return {
      'encryptionType': 'HardwareAesGcmEncryption',
      'keySize': keySize,
      'useHardwareKeys': _useHardwareKeys,
      'hardwareBackingAvailable': await _keyManager
          .isHardwareBackingAvailable(),
      'storageInfo': storageInfo,
    };
  }
}

/// ChaCha20-Poly1305 encryption with hardware-backed key storage.
class HardwareChaCha20Poly1305Encryption extends ChaCha20Poly1305Encryption {
  final HardwareKeyManager _keyManager;
  final bool _useHardwareKeys;

  HardwareChaCha20Poly1305Encryption({
    HardwareKeyManager? keyManager,
    bool useHardwareKeys = true,
  }) : _keyManager = keyManager ?? HardwareKeyManager.maxSecurity(),
       _useHardwareKeys = useHardwareKeys,
       super();

  @override
  Uint8List obfuscate(Uint8List data, int nonce) {
    if (_useHardwareKeys) {
      return _obfuscateWithHardwareKey(data, nonce);
    }

    return super.obfuscate(data, nonce);
  }

  @override
  Uint8List deobfuscate(Uint8List data, int nonce) {
    if (_useHardwareKeys) {
      return _deobfuscateWithHardwareKey(data, nonce);
    }

    return super.deobfuscate(data, nonce);
  }

  /// Encrypts data using hardware-backed keys.
  Uint8List _obfuscateWithHardwareKey(Uint8List data, int nonce) {
    try {
      // Get or generate hardware-backed key
      final key = _getOrGenerateHardwareKey(nonce);

      // Generate nonce for ChaCha20
      final chachaNonce = _generateNonce(nonce);

      // Create ChaCha20 cipher
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key.keyData), chachaNonce);
      cipher.init(true, params);

      // Encrypt the data
      final encrypted = Uint8List(data.length);
      cipher.processBytes(data, 0, data.length, encrypted, 0);

      // Create Poly1305 authenticator
      final poly1305 = Poly1305();
      poly1305.init(
        KeyParameter(_generatePoly1305Key(key.keyData, chachaNonce)),
      );

      // Add encrypted data to authenticator
      poly1305.update(encrypted, 0, encrypted.length);

      // Generate authentication tag
      final tag = Uint8List(16);
      poly1305.doFinal(tag, 0);

      // Combine version + nonce + encrypted data + tag
      final result = Uint8List(
        4 + chachaNonce.length + encrypted.length + tag.length,
      );

      // Store key version
      result.setRange(0, 4, _intToBytes(key.version));
      result.setRange(4, 4 + chachaNonce.length, chachaNonce);
      result.setRange(
        4 + chachaNonce.length,
        4 + chachaNonce.length + encrypted.length,
        encrypted,
      );
      result.setRange(
        4 + chachaNonce.length + encrypted.length,
        result.length,
        tag,
      );

      return result;
    } catch (e) {
      throw ObfuscationException(
        'Hardware ChaCha20-Poly1305 encryption failed',
        e,
      );
    }
  }

  /// Decrypts data using hardware-backed keys.
  Uint8List _deobfuscateWithHardwareKey(Uint8List data, int nonce) {
    try {
      // Extract key version
      final keyVersion = _bytesToInt(data.sublist(0, 4));

      // Get key by version
      final key = _keyManager.getKeyByVersion(keyVersion);
      if (key == null) {
        throw ObfuscationException('Key version $keyVersion not found');
      }

      // Extract components
      final chachaNonce = data.sublist(
        4,
        4 + 12,
      ); // ChaCha20 uses 12-byte nonce
      final encryptedData = data.sublist(4 + 12, data.length - 16);
      final tag = data.sublist(data.length - 16);

      // Verify authentication tag
      final poly1305 = Poly1305();
      poly1305.init(
        KeyParameter(_generatePoly1305Key(key.keyData, chachaNonce)),
      );
      poly1305.update(encryptedData, 0, encryptedData.length);

      final computedTag = Uint8List(16);
      poly1305.doFinal(computedTag, 0);

      // Constant-time comparison
      var tagMatch = true;
      for (int i = 0; i < 16; i++) {
        tagMatch &= (tag[i] == computedTag[i]);
      }

      if (!tagMatch) {
        throw ObfuscationException('Authentication tag verification failed');
      }

      // Decrypt the data
      final cipher = ChaCha20Engine();
      final params = ParametersWithIV(KeyParameter(key.keyData), chachaNonce);
      cipher.init(false, params);

      final decrypted = Uint8List(encryptedData.length);
      cipher.processBytes(encryptedData, 0, encryptedData.length, decrypted, 0);

      return decrypted;
    } catch (e) {
      throw ObfuscationException(
        'Hardware ChaCha20-Poly1305 decryption failed',
        e,
      );
    }
  }

  /// Gets or generates a hardware-backed key for the given nonce.
  VersionedKey _getOrGenerateHardwareKey(int nonce) {
    // Try to get current key
    var currentKey = _keyManager.currentKey;

    if (currentKey == null || currentKey.isExpired) {
      // Generate new key
      currentKey = _keyManager.generateNewKey(
        nonce,
        256,
      ); // ChaCha20 uses 256-bit keys
    }

    return currentKey;
  }

  /// Converts integer to bytes.
  List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Converts bytes to integer.
  int _bytesToInt(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  /// Generates nonce for ChaCha20 encryption.
  Uint8List _generateNonce(int nonce) {
    final iv = Uint8List(
      12,
    ); // ChaCha20 nonce size is 12 bytes for this implementation
    // Add current time to make it truly polymorphic
    final random = Random(nonce + DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < 12; i++) {
      iv[i] = random.nextInt(256);
    }

    return iv;
  }

  /// Generates Poly1305 key from ChaCha20 key and nonce.
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

  /// Gets information about the hardware encryption setup.
  Future<Map<String, dynamic>> getEncryptionInfo() async {
    final storageInfo = await _keyManager.getStorageInfo();

    return {
      'encryptionType': 'HardwareChaCha20Poly1305Encryption',
      'useHardwareKeys': _useHardwareKeys,
      'hardwareBackingAvailable': await _keyManager
          .isHardwareBackingAvailable(),
      'storageInfo': storageInfo,
    };
  }
}

/// Factory for creating hardware-backed encryption instances.
class HardwareEncryptionFactory {
  /// Creates an AES-GCM encryption instance with hardware backing.
  static HardwareAesGcmEncryption createAesGcm({
    int keySize = 256,
    HardwareKeyManager? keyManager,
    bool useHardwareKeys = true,
  }) {
    return HardwareAesGcmEncryption(
      keySize: keySize,
      keyManager: keyManager,
      useHardwareKeys: useHardwareKeys,
    );
  }

  /// Creates a ChaCha20-Poly1305 encryption instance with hardware backing.
  static HardwareChaCha20Poly1305Encryption createChaCha20Poly1305({
    HardwareKeyManager? keyManager,
    bool useHardwareKeys = true,
  }) {
    return HardwareChaCha20Poly1305Encryption(
      keyManager: keyManager,
      useHardwareKeys: useHardwareKeys,
    );
  }

  /// Creates the best available encryption for the current platform.
  static Future<EncryptionAlgorithm> createBestAvailable({
    HardwareKeyManager? keyManager,
  }) async {
    final platform = PlatformDetector.detectPlatform();
    final manager = keyManager ?? HardwareKeyManager.maxSecurity();

    final hasHardwareBacking = await manager.isHardwareBackingAvailable();

    if (hasHardwareBacking &&
        (platform == ConfidentialPlatform.android ||
            platform == ConfidentialPlatform.ios)) {
      // Use hardware-backed AES-GCM on mobile platforms
      return createAesGcm(keyManager: manager);
    } else if (hasHardwareBacking) {
      // Use hardware-backed ChaCha20-Poly1305 on other platforms
      return createChaCha20Poly1305(keyManager: manager);
    } else {
      // Fallback to software encryption
      return AesGcmEncryption(256);
    }
  }

  /// Gets information about available hardware encryption options.
  static Future<Map<String, dynamic>> getAvailableOptions() async {
    final platform = PlatformDetector.detectPlatform();
    final manager = HardwareKeyManager.development();

    final hasHardwareBacking = await manager.isHardwareBackingAvailable();
    final storageInfo = await manager.getStorageInfo();

    return {
      'platform': platform.name,
      'hardwareBackingAvailable': hasHardwareBacking,
      'recommendedEncryption': hasHardwareBacking
          ? 'hardware-aes-gcm'
          : 'software-aes-gcm',
      'supportedAlgorithms': [
        'hardware-aes-gcm',
        'hardware-chacha20-poly1305',
        'software-aes-gcm',
        'software-chacha20-poly1305',
      ],
      'storageInfo': storageInfo,
    };
  }
}
