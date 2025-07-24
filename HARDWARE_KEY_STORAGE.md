# 🔑 Hardware-Backed Key Storage

The Confidential package provides enhanced hardware-backed key storage for Flutter mobile platforms, offering maximum security through direct integration with Android Keystore and iOS Keychain/Secure Enclave.

## Features

### 🛡️ Platform-Specific Security
- **Android**: Direct Android Keystore integration with StrongBox support
- **iOS**: Native Keychain and Secure Enclave integration
- **Cross-platform**: Graceful fallback to secure storage on other platforms

### 🔐 Advanced Security Features
- Hardware security module (HSM) backing
- Biometric authentication (Face ID, Touch ID, Fingerprint)
- Key attestation and verification
- Automatic key rotation
- Device authentication requirements

### ⚡ Performance Optimizations
- Native platform channel integration
- Efficient key caching
- Minimal overhead for hardware operations
- Optimized for mobile platforms

## Quick Start

### Basic Usage

```dart
import 'package:confidential/confidential.dart';

// Create maximum security configuration
final config = HardwareKeyStorageConfig.maxSecurity();
final keyStorage = HardwareKeyStorage(config: config);

// Generate a hardware-backed key
final key = await keyStorage.generateAndStoreKey(
  keyId: 'user_data_key',
  version: 1,
);

// Use with encryption
final encryption = HardwareAesGcmEncryption(
  keyManager: HardwareKeyManager.maxSecurity(),
);
```

### Enhanced Configuration

```dart
// Custom configuration with platform-specific features
final config = HardwareKeyStorageConfig(
  useHardwareBacking: true,
  useNativePlatformChannels: true,  // Enable native integration
  preferStrongBox: true,            // Android StrongBox preference
  preferSecureEnclave: true,        // iOS Secure Enclave preference
  useBiometricAuth: true,           // Require biometric authentication
  requireDeviceAuth: true,          // Require device unlock
  keySize: 256,                     // AES-256 keys
  enableKeyRotation: true,          // Automatic rotation
  rotationIntervalDays: 7,          // Weekly rotation
);

final keyStorage = HardwareKeyStorage(config: config);
```

## Platform Capabilities

### Android Features

```dart
// Check Android-specific capabilities
final capabilities = await keyStorage.getPlatformCapabilities();

if (capabilities.strongBoxAvailable) {
  print('🔒 StrongBox HSM available');
}

if (capabilities.biometricAvailable) {
  print('👆 Biometric authentication available');
}

// Get detailed storage information
final storageInfo = await keyStorage.getStorageInfo();
final features = storageInfo['securityFeatures'] as Map<String, dynamic>;

print('Android Keystore: ${features['androidKeystore']}');
print('StrongBox: ${features['strongBox']}');
print('TEE Support: ${features['teeSupport']}');
```

### iOS Features

```dart
// Check iOS-specific capabilities
final capabilities = await keyStorage.getPlatformCapabilities();

if (capabilities.secureEnclaveAvailable) {
  print('🔐 Secure Enclave available');
}

// Get detailed storage information
final storageInfo = await keyStorage.getStorageInfo();
final features = storageInfo['securityFeatures'] as Map<String, dynamic>;

print('Secure Enclave: ${features['secureEnclave']}');
print('Keychain: ${features['keychain']}');
print('Face ID: ${features['faceId']}');
print('Touch ID: ${features['touchId']}');
```

## Security Levels

The system automatically detects and uses the highest available security level:

```dart
final capabilities = await keyStorage.getPlatformCapabilities();
print('Best security level: ${capabilities.bestSecurityLevel}');

// Security levels (highest to lowest):
// - SecurityLevel.strongBox      (Android StrongBox HSM)
// - SecurityLevel.secureEnclave  (iOS Secure Enclave)
// - SecurityLevel.tee           (Android TEE)
// - SecurityLevel.keychain      (iOS Keychain)
// - SecurityLevel.software      (Software fallback)
```

## Biometric Authentication

### Setup

```dart
final config = HardwareKeyStorageConfig(
  useBiometricAuth: true,
  requireDeviceAuth: true,
);

final keyStorage = HardwareKeyStorage(config: config);
```

### Usage with Native Integration

```dart
// Direct biometric authentication (requires native channels)
final nativeStorage = NativeHardwareKeyStorage();

if (await nativeStorage.isBiometricAvailable()) {
  final result = await nativeStorage.authenticateWithBiometric(
    title: 'Secure Access',
    subtitle: 'Use your biometric to access encrypted data',
    negativeButtonText: 'Cancel',
  );
  
  if (result.authenticated) {
    // Access protected keys
    final key = await keyStorage.getKey('protected_key');
  }
}
```

## Key Attestation

Verify that keys are truly hardware-backed:

```dart
// Generate a key for attestation
await keyStorage.generateAndStoreKey(
  keyId: 'attestation_key',
  version: 1,
);

// Get attestation information
final storageInfo = await keyStorage.getStorageInfo();
final attestation = storageInfo['attestation'] as Map<String, dynamic>;

if (attestation['supported'] == true) {
  print('✅ Key attestation supported');
  print('Platform: ${attestation['platform']}');
  print('HSM: ${attestation['hardwareSecurityModule']}');
  print('Protection: ${attestation['keyProtection']}');
  print('Verified: ${attestation['attestationVerified']}');
}
```

## Integration with Encryption

### Hardware AES-GCM Encryption

```dart
// Create hardware-backed encryption
final encryption = HardwareEncryptionFactory.createAesGcm(
  keySize: 256,
  keyManager: HardwareKeyManager.maxSecurity(),
  useHardwareKeys: true,
);

// Encrypt sensitive data
final sensitiveData = 'Top secret information';
final encrypted = encryption.obfuscate(
  Uint8List.fromList(sensitiveData.codeUnits),
  12345, // nonce
);

// Decrypt data
final decrypted = encryption.deobfuscate(encrypted, 12345);
final originalData = String.fromCharCodes(decrypted);
```

### Hardware ChaCha20-Poly1305 Encryption

```dart
// Create ChaCha20-Poly1305 with hardware backing
final encryption = HardwareEncryptionFactory.createChaCha20Poly1305(
  keyManager: HardwareKeyManager.maxSecurity(),
  useHardwareKeys: true,
);

// Use same encrypt/decrypt pattern as above
```

## Configuration Options

### HardwareKeyStorageConfig

| Option | Description | Default |
|--------|-------------|---------|
| `useHardwareBacking` | Enable hardware-backed storage | `true` |
| `requireHardwareBacking` | Fail if hardware backing unavailable | `false` |
| `useNativePlatformChannels` | Use native platform integration | `true` |
| `preferStrongBox` | Prefer Android StrongBox when available | `true` |
| `preferSecureEnclave` | Prefer iOS Secure Enclave when available | `true` |
| `useBiometricAuth` | Require biometric authentication | `false` |
| `requireDeviceAuth` | Require device unlock | `true` |
| `keySize` | Key size in bits | `256` |
| `enableKeyRotation` | Enable automatic key rotation | `true` |
| `rotationIntervalDays` | Days between key rotations | `30` |

### Predefined Configurations

```dart
// Maximum security (production)
final maxSec = HardwareKeyStorageConfig.maxSecurity();

// Development/testing
final dev = HardwareKeyStorageConfig.development();

// Custom configuration
final custom = HardwareKeyStorageConfig(
  useHardwareBacking: true,
  useBiometricAuth: true,
  keySize: 256,
  rotationIntervalDays: 14,
);
```

## Error Handling

```dart
try {
  final key = await keyStorage.generateAndStoreKey(
    keyId: 'secure_key',
    version: 1,
  );
} on ObfuscationException catch (e) {
  if (e.message.contains('Hardware-backed storage required')) {
    // Handle hardware requirement not met
    print('Hardware backing not available');
  } else {
    // Handle other errors
    print('Key generation failed: ${e.message}');
  }
} catch (e) {
  // Handle unexpected errors
  print('Unexpected error: $e');
}
```

## Best Practices

### 1. Use Maximum Security in Production

```dart
// Always use max security for production apps
final config = HardwareKeyStorageConfig.maxSecurity();
```

### 2. Handle Platform Differences

```dart
// Check capabilities before using platform-specific features
final capabilities = await keyStorage.getPlatformCapabilities();

if (capabilities.platform == ConfidentialPlatform.android) {
  // Android-specific logic
} else if (capabilities.platform == ConfidentialPlatform.ios) {
  // iOS-specific logic
}
```

### 3. Implement Graceful Fallbacks

```dart
final config = HardwareKeyStorageConfig(
  useHardwareBacking: true,
  requireHardwareBacking: false, // Allow fallback
);
```

### 4. Monitor Key Health

```dart
// Regularly check key integrity
final keyIds = await keyStorage.listKeys();
for (final keyId in keyIds) {
  final key = await keyStorage.getKey(keyId);
  if (key?.isExpired == true) {
    // Rotate expired keys
    await keyStorage.rotateKeyIfNeeded(keyId);
  }
}
```

### 5. Use Appropriate Key Sizes

```dart
// Use AES-256 for maximum security
final config = HardwareKeyStorageConfig(keySize: 256);

// AES-128 may be sufficient for some use cases
final lightConfig = HardwareKeyStorageConfig(keySize: 128);
```

## Performance Considerations

- Native platform channels provide better performance than flutter_secure_storage alone
- Key caching reduces repeated hardware access
- Biometric authentication adds latency but improves security
- StrongBox/Secure Enclave operations may be slower but more secure

## Platform Requirements

### Android
- Minimum API level 23 (Android 6.0) for hardware backing
- API level 28+ (Android 9.0) for StrongBox support
- Biometric authentication requires compatible hardware

### iOS
- iOS 9.0+ for Secure Enclave support
- Face ID/Touch ID requires compatible hardware
- Keychain is available on all iOS devices

## Troubleshooting

### Common Issues

1. **Hardware backing not available**
   - Check device capabilities
   - Use development config for testing
   - Implement fallback strategies

2. **Biometric authentication fails**
   - Verify biometric setup on device
   - Handle authentication errors gracefully
   - Provide alternative authentication methods

3. **Key generation fails**
   - Check platform requirements
   - Verify configuration parameters
   - Monitor device storage space

### Debug Information

```dart
// Get comprehensive debug information
final storageInfo = await keyStorage.getStorageInfo();
print('Debug info: ${jsonEncode(storageInfo)}');

// Check platform capabilities
final capabilities = await keyStorage.getPlatformCapabilities();
print('Capabilities: ${capabilities.toMap()}');
```

## Examples

See the complete examples in:
- `example/lib/hardware_key_storage_example.dart` - Basic usage
- `example/lib/enhanced_hardware_key_storage_example.dart` - Advanced features

Run examples:
```bash
cd example
flutter run lib/enhanced_hardware_key_storage_example.dart
```
