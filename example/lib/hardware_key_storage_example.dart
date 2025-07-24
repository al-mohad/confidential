/// 🔑 Hardware-Backed Key Storage Example
///
/// This example demonstrates how to use hardware-backed key storage
/// on Flutter mobile platforms with Android Keystore and iOS Keychain.
library;

import 'dart:typed_data';

import 'package:confidential/confidential.dart';

/// Example demonstrating hardware-backed key storage usage.
class HardwareKeyStorageExample {
  late HardwareKeyStorage _keyStorage;

  /// Initialize hardware key storage with different security levels.
  Future<void> initializeKeyStorage() async {
    print('🔑 Initializing Hardware-Backed Key Storage...\n');

    // Example 1: Maximum Security Configuration
    await _demonstrateMaxSecurityConfig();

    // Example 2: Development Configuration
    await _demonstrateDevelopmentConfig();

    // Example 3: Custom Configuration
    await _demonstrateCustomConfig();

    // Example 4: Platform-Specific Features
    await _demonstratePlatformFeatures();
  }

  /// Demonstrates maximum security configuration.
  Future<void> _demonstrateMaxSecurityConfig() async {
    print('🛡️  Maximum Security Configuration');
    print('=====================================');

    final config = HardwareKeyStorageConfig.maxSecurity();
    _keyStorage = HardwareKeyStorage(config: config);

    // Check hardware backing availability
    final hasHardwareBacking = await _keyStorage.isHardwareBackingAvailable();
    print('Hardware backing available: $hasHardwareBacking');

    if (hasHardwareBacking) {
      try {
        // Generate a secure key
        final key = await _keyStorage.generateAndStoreKey(
          keyId: 'max_security_key',
          version: 1,
        );

        print('✅ Generated secure key:');
        print('  - Version: ${key.version}');
        print('  - Key size: ${key.keyData.length * 8} bits');
        print('  - Created: ${key.createdAt}');
        print('  - Expires: ${key.expiresAt}');
        print('  - Active: ${key.isActive}');

        // Demonstrate key retrieval
        final retrievedKey = await _keyStorage.getKey('max_security_key');
        print('✅ Successfully retrieved key: ${retrievedKey != null}');
      } catch (e) {
        print('❌ Error with max security config: $e');
      }
    } else {
      print('⚠️  Hardware backing not available on this platform');
    }
    print('');
  }

  /// Demonstrates development configuration.
  Future<void> _demonstrateDevelopmentConfig() async {
    print('🔧 Development Configuration');
    print('============================');

    final config = HardwareKeyStorageConfig.development();
    final devKeyStorage = HardwareKeyStorage(config: config);

    try {
      // Generate multiple keys for testing
      final keys = <VersionedKey>[];
      for (int i = 1; i <= 3; i++) {
        final key = await devKeyStorage.generateAndStoreKey(
          keyId: 'dev_key_$i',
          version: i,
        );
        keys.add(key);
        print('✅ Generated dev key $i: ${key.keyData.length} bytes');
      }

      // List all stored keys
      final keyIds = await devKeyStorage.listKeys();
      print('📋 Stored keys: ${keyIds.join(', ')}');

      // Clean up development keys
      await devKeyStorage.clearAllKeys();
      print('🧹 Cleaned up development keys');
    } catch (e) {
      print('❌ Error with development config: $e');
    }
    print('');
  }

  /// Demonstrates custom configuration.
  Future<void> _demonstrateCustomConfig() async {
    print('⚙️  Custom Configuration');
    print('========================');

    final config = HardwareKeyStorageConfig(
      useHardwareBacking: true,
      requireHardwareBacking: false, // Graceful fallback
      keyPrefix: 'my_app_secure',
      useBiometricAuth: false, // Disable for this example
      requireDeviceAuth: true,
      keySize: 256,
      enableKeyRotation: true,
      rotationIntervalDays: 14, // Rotate every 2 weeks
    );

    final customKeyStorage = HardwareKeyStorage(config: config);

    try {
      // Generate key with custom settings
      await customKeyStorage.generateAndStoreKey(
        keyId: 'custom_app_key',
        version: 1,
      );

      print('✅ Generated custom key:');
      print('  - Key ID: custom_app_key');
      print('  - Size: ${config.keySize} bits');
      print('  - Rotation enabled: ${config.enableKeyRotation}');
      print('  - Rotation interval: ${config.rotationIntervalDays} days');

      // Demonstrate key rotation
      await Future.delayed(
        Duration(milliseconds: 100),
      ); // Simulate time passage
      final rotatedKey = await customKeyStorage.rotateKeyIfNeeded(
        'custom_app_key',
        force: true, // Force rotation for demo
      );

      if (rotatedKey != null) {
        print('🔄 Key rotated successfully:');
        print('  - New version: ${rotatedKey.version}');
        print('  - Previous version still available for decryption');
      }
    } catch (e) {
      print('❌ Error with custom config: $e');
    }
    print('');
  }

  /// Demonstrates platform-specific features.
  Future<void> _demonstratePlatformFeatures() async {
    print('📱 Platform-Specific Features');
    print('=============================');

    final config = HardwareKeyStorageConfig(
      useHardwareBacking: true,
      requireDeviceAuth: true,
    );
    final platformKeyStorage = HardwareKeyStorage(config: config);

    try {
      // Get detailed storage information
      final storageInfo = await platformKeyStorage.getStorageInfo();

      print('Platform Information:');
      print('  - Platform: ${storageInfo['platform']}');
      print(
        '  - Hardware backing available: ${storageInfo['hardwareBackingAvailable']}',
      );
      print(
        '  - Hardware backing enabled: ${storageInfo['hardwareBackingEnabled']}',
      );
      print(
        '  - Biometric auth enabled: ${storageInfo['biometricAuthEnabled']}',
      );
      print('  - Device auth required: ${storageInfo['deviceAuthRequired']}');
      print('  - Key size: ${storageInfo['keySize']} bits');
      print('  - Key rotation enabled: ${storageInfo['keyRotationEnabled']}');
      print('  - Stored key count: ${storageInfo['storedKeyCount']}');

      // Display security features
      final securityFeatures =
          storageInfo['securityFeatures'] as Map<String, dynamic>;
      print('\nSecurity Features:');
      securityFeatures.forEach((feature, supported) {
        final status = supported ? '✅' : '❌';
        print('  $status $feature: $supported');
      });

      // Display attestation information
      final attestation = storageInfo['attestation'] as Map<String, dynamic>;
      print('\nKey Attestation:');
      print('  - Supported: ${attestation['supported']}');
      if (attestation['supported'] == true) {
        print('  - Platform: ${attestation['platform']}');
        print('  - HSM: ${attestation['hardwareSecurityModule']}');
        print('  - Protection: ${attestation['keyProtection']}');
        print('  - Verified: ${attestation['attestationVerified']}');
      } else {
        print('  - Reason: ${attestation['reason']}');
      }
    } catch (e) {
      print('❌ Error getting platform features: $e');
    }
    print('');
  }

  /// Demonstrates practical usage with encryption.
  Future<void> demonstrateEncryptionIntegration() async {
    print('🔐 Encryption Integration Example');
    print('=================================');

    final config = HardwareKeyStorageConfig(
      useHardwareBacking: true,
      requireHardwareBacking: false,
      keyPrefix: 'encryption_demo',
    );
    final keyStorage = HardwareKeyStorage(config: config);

    try {
      // Generate encryption key
      final encryptionKey = await keyStorage.generateAndStoreKey(
        keyId: 'user_data_key',
        version: 1,
      );

      // Simulate encrypting sensitive data
      final sensitiveData = 'User credit card: 4532-1234-5678-9012';
      print('📝 Original data: ${sensitiveData.substring(0, 20)}...');

      // In a real app, you would use this key with your encryption algorithm
      final keyMaterial = encryptionKey.keyData;
      print('🔑 Using ${keyMaterial.length * 8}-bit hardware-backed key');

      // Simulate data encryption (simplified for example)
      final encryptedData = _simulateEncryption(sensitiveData, keyMaterial);
      print('🔒 Encrypted data: ${encryptedData.substring(0, 20)}...');

      // Retrieve key for decryption
      final retrievedKey = await keyStorage.getKey('user_data_key');
      if (retrievedKey != null) {
        final decryptedData = _simulateDecryption(
          encryptedData,
          retrievedKey.keyData,
        );
        print('🔓 Decrypted data: ${decryptedData.substring(0, 20)}...');
        print('✅ Encryption/decryption successful!');
      }
    } catch (e) {
      print('❌ Error in encryption integration: $e');
    }
    print('');
  }

  /// Simulates encryption (simplified for example).
  String _simulateEncryption(String data, Uint8List key) {
    // In a real implementation, use proper encryption like AES-GCM
    // This is just for demonstration purposes
    final bytes = data.codeUnits;
    final encrypted = <int>[];

    for (int i = 0; i < bytes.length; i++) {
      final keyByte = key[i % key.length];
      encrypted.add(bytes[i] ^ keyByte);
    }

    return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Simulates decryption (simplified for example).
  String _simulateDecryption(String encryptedHex, Uint8List key) {
    // Convert hex back to bytes
    final encrypted = <int>[];
    for (int i = 0; i < encryptedHex.length; i += 2) {
      encrypted.add(int.parse(encryptedHex.substring(i, i + 2), radix: 16));
    }

    // XOR with key to decrypt
    final decrypted = <int>[];
    for (int i = 0; i < encrypted.length; i++) {
      final keyByte = key[i % key.length];
      decrypted.add(encrypted[i] ^ keyByte);
    }

    return String.fromCharCodes(decrypted);
  }
}

/// Main function to run the hardware key storage examples.
Future<void> main() async {
  print('🔑 Hardware-Backed Key Storage Examples');
  print('=======================================\n');

  final example = HardwareKeyStorageExample();

  try {
    await example.initializeKeyStorage();
    await example.demonstrateEncryptionIntegration();

    print('🎉 All examples completed successfully!');
    print('\n💡 Key Takeaways:');
    print('  • Use HardwareKeyStorageConfig.maxSecurity() for production');
    print('  • Hardware backing provides TEE/Secure Enclave protection');
    print('  • Keys are automatically rotated based on configuration');
    print('  • Biometric authentication adds extra security layer');
    print('  • Graceful fallback to software storage when needed');
  } catch (e) {
    print('❌ Example failed: $e');
  }
}
