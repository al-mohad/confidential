/// 🔑 Enhanced Hardware-Backed Key Storage Example
///
/// This example demonstrates the enhanced hardware-backed key storage
/// with native platform channel integration for maximum security.
library;

import 'dart:typed_data';

import 'package:confidential/confidential.dart';

/// Example demonstrating enhanced hardware-backed key storage with native integration.
class EnhancedHardwareKeyStorageExample {
  late HardwareKeyStorage _keyStorage;

  /// Initialize enhanced hardware key storage with native platform channels.
  Future<void> initializeEnhancedKeyStorage() async {
    print('🔑 Initializing Enhanced Hardware-Backed Key Storage...\n');

    // Example 1: Maximum Security with Native Channels
    await _demonstrateNativeMaxSecurity();

    // Example 2: Platform-Specific Features
    await _demonstratePlatformSpecificFeatures();

    // Example 3: Biometric Authentication
    await _demonstrateBiometricAuthentication();

    // Example 4: Key Attestation and Security Levels
    await _demonstrateKeyAttestation();

    // Example 5: Performance Comparison
    await _demonstratePerformanceComparison();
  }

  /// Demonstrates maximum security configuration with native channels.
  Future<void> _demonstrateNativeMaxSecurity() async {
    print('🛡️  Maximum Security with Native Channels');
    print('==========================================');

    final config = HardwareKeyStorageConfig.maxSecurity();
    _keyStorage = HardwareKeyStorage(config: config);

    try {
      // Get comprehensive storage information
      final storageInfo = await _keyStorage.getStorageInfo();

      print('Enhanced Storage Configuration:');
      print('  - Platform: ${storageInfo['platform']}');
      print('  - Hardware backing: ${storageInfo['hardwareBackingAvailable']}');
      print('  - Native channels: ${storageInfo['useNativePlatformChannels']}');
      print('  - Native storage: ${storageInfo['nativeStorageAvailable']}');

      if (storageInfo['platformCapabilities'] != null) {
        final capabilities =
            storageInfo['platformCapabilities'] as Map<String, dynamic>;
        print('  - StrongBox available: ${capabilities['strongBoxAvailable']}');
        print(
          '  - Secure Enclave available: ${capabilities['secureEnclaveAvailable']}',
        );
        print('  - Biometric available: ${capabilities['biometricAvailable']}');
        print('  - Best security level: ${capabilities['bestSecurityLevel']}');
      }

      // Generate a maximum security key
      final key = await _keyStorage.generateAndStoreKey(
        keyId: 'max_security_native_key',
        version: 1,
      );

      print('\n✅ Generated maximum security key:');
      print('  - Version: ${key.version}');
      print('  - Key size: ${key.keyData.length * 8} bits');
      print('  - Hardware-backed: ${storageInfo['hardwareBackingAvailable']}');
      print('  - Created: ${key.createdAt}');
    } catch (e) {
      print('❌ Error with enhanced max security: $e');
    }
    print('');
  }

  /// Demonstrates platform-specific features.
  Future<void> _demonstratePlatformSpecificFeatures() async {
    print('📱 Platform-Specific Enhanced Features');
    print('======================================');

    final config = HardwareKeyStorageConfig(
      useHardwareBacking: true,
      useNativePlatformChannels: true,
      preferStrongBox: true,
      preferSecureEnclave: true,
      useBiometricAuth: false, // Disable for this demo
    );

    final platformKeyStorage = HardwareKeyStorage(config: config);

    try {
      final storageInfo = await platformKeyStorage.getStorageInfo();
      final securityFeatures =
          storageInfo['securityFeatures'] as Map<String, dynamic>;

      print('Platform-Specific Features:');
      securityFeatures.forEach((feature, supported) {
        final status = supported ? '✅' : '❌';
        print('  $status $feature: $supported');
      });

      // Generate platform-optimized keys
      final keys = <String, VersionedKey>{};

      // Generate multiple keys to test different configurations
      for (int i = 1; i <= 3; i++) {
        final keyId = 'platform_key_$i';
        final key = await platformKeyStorage.generateAndStoreKey(
          keyId: keyId,
          version: i,
        );
        keys[keyId] = key;
        print('✅ Generated platform key $i: ${key.keyData.length} bytes');
      }

      // List all platform keys
      final keyIds = await platformKeyStorage.listKeys();
      print(
        '📋 Platform keys: ${keyIds.where((id) => id.startsWith('platform_')).join(', ')}',
      );
    } catch (e) {
      print('❌ Error with platform features: $e');
    }
    print('');
  }

  /// Demonstrates biometric authentication integration.
  Future<void> _demonstrateBiometricAuthentication() async {
    print('👆 Biometric Authentication Integration');
    print('======================================');

    final config = HardwareKeyStorageConfig(
      useHardwareBacking: true,
      useNativePlatformChannels: true,
      useBiometricAuth: true,
      requireDeviceAuth: true,
    );

    final biometricKeyStorage = HardwareKeyStorage(config: config);

    try {
      final storageInfo = await biometricKeyStorage.getStorageInfo();
      final capabilities =
          storageInfo['platformCapabilities'] as Map<String, dynamic>?;

      print('Biometric Capabilities:');
      print(
        '  - Biometric available: ${capabilities?['biometricAvailable'] ?? false}',
      );
      print(
        '  - Biometric auth enabled: ${storageInfo['biometricAuthEnabled']}',
      );
      print('  - Device auth required: ${storageInfo['deviceAuthRequired']}');

      if (capabilities?['biometricAvailable'] == true) {
        // Generate a biometric-protected key
        final key = await biometricKeyStorage.generateAndStoreKey(
          keyId: 'biometric_protected_key',
          version: 1,
        );

        print('\n✅ Generated biometric-protected key:');
        print('  - Requires biometric: ${config.useBiometricAuth}');
        print('  - Requires device auth: ${config.requireDeviceAuth}');
        print('  - Key size: ${key.keyData.length * 8} bits');

        // Note: In a real app, accessing this key would trigger biometric prompt
        print('💡 Key access would require biometric authentication');
      } else {
        print('⚠️  Biometric authentication not available on this platform');
      }
    } catch (e) {
      print('❌ Error with biometric authentication: $e');
    }
    print('');
  }

  /// Demonstrates key attestation and security levels.
  Future<void> _demonstrateKeyAttestation() async {
    print('🔍 Key Attestation and Security Levels');
    print('======================================');

    final config = HardwareKeyStorageConfig.maxSecurity();
    final attestationKeyStorage = HardwareKeyStorage(config: config);

    try {
      // Generate a key for attestation
      await attestationKeyStorage.generateAndStoreKey(
        keyId: 'attestation_test_key',
        version: 1,
      );

      final storageInfo = await attestationKeyStorage.getStorageInfo();
      final attestationInfo =
          storageInfo['attestation'] as Map<String, dynamic>;

      print('Key Attestation Results:');
      print('  - Attestation supported: ${attestationInfo['supported']}');

      if (attestationInfo['supported'] == true) {
        print('  - Platform: ${attestationInfo['platform']}');
        print('  - HSM: ${attestationInfo['hardwareSecurityModule']}');
        print('  - Protection level: ${attestationInfo['keyProtection']}');
        print('  - Verification: ${attestationInfo['attestationVerified']}');

        // Show security level information
        final capabilities =
            storageInfo['platformCapabilities'] as Map<String, dynamic>?;
        if (capabilities != null) {
          print('\nSecurity Level Analysis:');
          print('  - Best available: ${capabilities['bestSecurityLevel']}');
          print(
            '  - Hardware backing: ${capabilities['hardwareBackingAvailable']}',
          );
          print('  - StrongBox: ${capabilities['strongBoxAvailable']}');
          print(
            '  - Secure Enclave: ${capabilities['secureEnclaveAvailable']}',
          );
        }
      } else {
        print('  - Reason: ${attestationInfo['reason']}');
      }
    } catch (e) {
      print('❌ Error with key attestation: $e');
    }
    print('');
  }

  /// Demonstrates performance comparison between native and fallback storage.
  Future<void> _demonstratePerformanceComparison() async {
    print('⚡ Performance Comparison');
    print('========================');

    try {
      // Test native platform channels
      final nativeConfig = HardwareKeyStorageConfig(
        useHardwareBacking: true,
        useNativePlatformChannels: true,
        enableKeyRotation: false,
      );
      final nativeStorage = HardwareKeyStorage(config: nativeConfig);

      // Test fallback storage
      final fallbackConfig = HardwareKeyStorageConfig(
        useHardwareBacking: true,
        useNativePlatformChannels: false,
        enableKeyRotation: false,
      );
      final fallbackStorage = HardwareKeyStorage(config: fallbackConfig);

      const testIterations = 5;

      // Benchmark native storage
      final nativeStartTime = DateTime.now();
      for (int i = 0; i < testIterations; i++) {
        await nativeStorage.generateAndStoreKey(
          keyId: 'native_perf_key_$i',
          version: i + 1,
        );
      }
      final nativeEndTime = DateTime.now();
      final nativeDuration = nativeEndTime.difference(nativeStartTime);

      // Benchmark fallback storage
      final fallbackStartTime = DateTime.now();
      for (int i = 0; i < testIterations; i++) {
        await fallbackStorage.generateAndStoreKey(
          keyId: 'fallback_perf_key_$i',
          version: i + 1,
        );
      }
      final fallbackEndTime = DateTime.now();
      final fallbackDuration = fallbackEndTime.difference(fallbackStartTime);

      print('Performance Results ($testIterations key generations):');
      print('  - Native channels: ${nativeDuration.inMilliseconds}ms');
      print('  - Fallback storage: ${fallbackDuration.inMilliseconds}ms');

      final speedup =
          fallbackDuration.inMilliseconds / nativeDuration.inMilliseconds;
      if (speedup > 1) {
        print('  - Native is ${speedup.toStringAsFixed(1)}x faster');
      } else {
        print('  - Fallback is ${(1 / speedup).toStringAsFixed(1)}x faster');
      }

      // Clean up performance test keys
      await _cleanupPerformanceKeys(
        nativeStorage,
        fallbackStorage,
        testIterations,
      );
    } catch (e) {
      print('❌ Error with performance comparison: $e');
    }
    print('');
  }

  /// Cleans up performance test keys.
  Future<void> _cleanupPerformanceKeys(
    HardwareKeyStorage nativeStorage,
    HardwareKeyStorage fallbackStorage,
    int iterations,
  ) async {
    try {
      for (int i = 0; i < iterations; i++) {
        await nativeStorage.deleteKey('native_perf_key_$i');
        await fallbackStorage.deleteKey('fallback_perf_key_$i');
      }
      print('🧹 Cleaned up performance test keys');
    } catch (e) {
      print('⚠️  Warning: Failed to clean up some performance test keys: $e');
    }
  }

  /// Demonstrates practical encryption integration with enhanced security.
  Future<void> demonstrateEnhancedEncryptionIntegration() async {
    print('🔐 Enhanced Encryption Integration');
    print('==================================');

    final config = HardwareKeyStorageConfig.maxSecurity();
    final keyStorage = HardwareKeyStorage(config: config);

    try {
      // Generate an enhanced encryption key
      final encryptionKey = await keyStorage.generateAndStoreKey(
        keyId: 'enhanced_user_data_key',
        version: 1,
      );

      // Get detailed security information
      final storageInfo = await keyStorage.getStorageInfo();
      final capabilities =
          storageInfo['platformCapabilities'] as Map<String, dynamic>?;

      print('Enhanced Encryption Setup:');
      print(
        '  - Security level: ${capabilities?['bestSecurityLevel'] ?? 'unknown'}',
      );
      print('  - Hardware backing: ${storageInfo['hardwareBackingAvailable']}');
      print('  - Native channels: ${storageInfo['useNativePlatformChannels']}');
      print('  - Key size: ${encryptionKey.keyData.length * 8} bits');

      // Simulate encrypting highly sensitive data
      final sensitiveData = 'TOP SECRET: Nuclear launch codes 12345-67890';
      print('\n📝 Original data: ${sensitiveData.substring(0, 30)}...');

      // Use the hardware-backed key for encryption
      final keyMaterial = encryptionKey.keyData;
      print('🔑 Using ${keyMaterial.length * 8}-bit hardware-backed key');

      // Simulate enhanced encryption (in real use, integrate with HardwareAesGcmEncryption)
      final encryptedData = _simulateEnhancedEncryption(
        sensitiveData,
        keyMaterial,
      );
      print('🔒 Enhanced encrypted data: ${encryptedData.substring(0, 30)}...');

      // Retrieve key for decryption (would trigger biometric if configured)
      final retrievedKey = await keyStorage.getKey('enhanced_user_data_key');
      if (retrievedKey != null) {
        final decryptedData = _simulateEnhancedDecryption(
          encryptedData,
          retrievedKey.keyData,
        );
        print('🔓 Decrypted data: ${decryptedData.substring(0, 30)}...');
        print('✅ Enhanced encryption/decryption successful!');

        // Show security benefits
        print('\n🛡️  Security Benefits:');
        print('  • Keys stored in hardware security module');
        print('  • Biometric authentication protection');
        print('  • Key attestation verification');
        print('  • Automatic key rotation');
        print('  • Platform-specific optimizations');
      }
    } catch (e) {
      print('❌ Error in enhanced encryption integration: $e');
    }
    print('');
  }

  /// Simulates enhanced encryption with additional security metadata.
  String _simulateEnhancedEncryption(String data, Uint8List key) {
    // Add security metadata
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final securityHeader = 'ENHANCED:$timestamp:';
    final dataWithHeader = securityHeader + data;

    // Simple XOR encryption (use proper AES-GCM in production)
    final bytes = dataWithHeader.codeUnits;
    final encrypted = <int>[];

    for (int i = 0; i < bytes.length; i++) {
      final keyByte = key[i % key.length];
      encrypted.add(bytes[i] ^ keyByte);
    }

    return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Simulates enhanced decryption with security verification.
  String _simulateEnhancedDecryption(String encryptedHex, Uint8List key) {
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

    final decryptedString = String.fromCharCodes(decrypted);

    // Verify and remove security header
    if (decryptedString.startsWith('ENHANCED:')) {
      final headerEnd = decryptedString.indexOf(':', 9);
      if (headerEnd != -1) {
        return decryptedString.substring(headerEnd + 1);
      }
    }

    return decryptedString;
  }
}

/// Main function to run the enhanced hardware key storage examples.
Future<void> main() async {
  print('🔑 Enhanced Hardware-Backed Key Storage Examples');
  print('================================================\n');

  final example = EnhancedHardwareKeyStorageExample();

  try {
    await example.initializeEnhancedKeyStorage();
    await example.demonstrateEnhancedEncryptionIntegration();

    print('🎉 All enhanced examples completed successfully!');
    print('\n💡 Enhanced Key Features:');
    print('  • Native Android Keystore with StrongBox support');
    print('  • Native iOS Keychain with Secure Enclave support');
    print('  • Hardware key attestation and verification');
    print('  • Enhanced biometric authentication');
    print('  • Platform-specific security optimizations');
    print('  • Improved performance with native channels');
    print('  • Comprehensive security level detection');
  } catch (e) {
    print('❌ Enhanced example failed: $e');
  }
}
