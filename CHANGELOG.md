# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2025-01-23

### 🧼 Added - Enhanced API Ergonomics
- **Extension Methods for Easy Encryption**:
  - `String.encrypt()` and `.obfuscate()` - Direct string encryption with algorithm selection
  - `List<String>.encrypt()` and `.obfuscate()` - List encryption with type safety
  - `Map<String, dynamic>.encrypt()` and `.obfuscate()` - Map encryption support
  - `int.encrypt()`, `bool.encrypt()`, `Uint8List.encrypt()` - Primitive type encryption
  - Type-safe decryption methods: `.decryptAsString()`, `.decryptAsStringList()`, `.decryptAsMap()`
- **Enhanced ObfuscatedValue Extensions**:
  - `.getValue()` - Ergonomic value access
  - `.getValueAsync()` - Async value access for consistency
  - `.map<T>()` - Transform obfuscated values with type safety
  - `.safeCast<T>()` - Safe type casting with null safety
  - `.isType<T>()` - Runtime type checking

### 🗂️ Enhanced Secret Organization
- **Secret Groups and Categories**:
  - Organize secrets into logical groups with descriptions
  - Support for tags, environments, and priority levels
  - Group-level namespace and access modifier settings
  - Deprecation tracking and filtering
- **Advanced Secret Filtering**:
  - Filter by groups, tags, environments, and priority
  - Exclude deprecated secrets automatically
  - Regular expression name matching
  - Complex multi-criteria filtering
- **Enhanced Configuration Support**:
  - YAML configuration for secret groups and metadata
  - Namespace metadata with dependencies and descriptions
  - Environment-specific secret management

### ⚡ Asynchronous Secret Loading
- **Secret Providers**:
  - `FileSecretProvider` - Load secrets from local files with caching
  - `HttpSecretProvider` - Load secrets from HTTP endpoints with retry logic
  - `CompositeSecretProvider` - Try multiple providers in order with fallback
- **Provider Features**:
  - Configurable timeouts and retry mechanisms
  - Automatic caching with expiration policies
  - Parallel loading for multiple secrets
  - Comprehensive error handling and recovery
- **Async Obfuscated Values**:
  - `AsyncObfuscatedString`, `AsyncObfuscatedInt`, `AsyncObfuscatedBool`, etc.
  - Lazy loading with intelligent caching
  - Timeout and default value support
  - Stream-based updates for real-time secret changes
- **Advanced Async Management**:
  - `AsyncObfuscatedFactory` for creating async values
  - `AsyncSecretManager` for managing multiple async secrets
  - Preloading capabilities for performance optimization

### 🛠️ Developer Experience Improvements
- **Intuitive API Design**: Extension methods make encryption feel natural
- **Better Error Messages**: Comprehensive error handling with meaningful messages
- **Type Safety**: Strong typing throughout the async and extension systems
- **Backward Compatibility**: All existing code continues to work unchanged
- **Performance Optimizations**: Intelligent caching and lazy loading

### 📚 Documentation and Examples
- Updated README with comprehensive API ergonomics guide
- New example configurations showcasing grouping and async features
- Complete usage examples for all new extension methods
- Advanced secret management patterns and best practices
- Performance and security recommendations

### 🧪 Testing and Quality
- Comprehensive test suite for all extension methods
- Secret grouping and filtering test coverage
- Async provider testing with error scenarios and edge cases
- Integration tests for complete workflows
- Performance and reliability testing

### 📦 New Modules
- `lib/src/extensions/encryption_extensions.dart` - Extension methods for all data types
- `lib/src/async/secret_providers.dart` - Asynchronous secret loading infrastructure
- `lib/src/async/async_obfuscated.dart` - Async obfuscated value implementations
- `lib/src/grouping/secret_groups.dart` - Enhanced secret organization system
- `test/api_improvements_test.dart` - Comprehensive test suite for new features
- `example/lib/ergonomics_example.dart` - Complete usage demonstration
- `example/confidential-ergonomics.yaml` - Advanced configuration examples

## [0.5.0] - 2025-01-23

### 🔒 Added - Enhanced Encryption Support
- **RSA Encryption**: Added support for RSA-2048 and RSA-4096 with OAEP padding
  - `rsa-2048`, `rsa-4096` with default SHA-256
  - `rsa-2048-sha256`, `rsa-4096-sha256`, `rsa-2048-sha512`, `rsa-4096-sha512`
  - Hybrid encryption for large data (RSA + AES-GCM)
- **Enhanced ChaCha20-Poly1305**: Replaced XOR placeholder with proper authenticated encryption
  - Full AEAD (Authenticated Encryption with Associated Data) implementation
  - Constant-time tag verification for security
  - Proper ChaCha20 stream cipher with Poly1305 MAC
- **Advanced Key Management System**:
  - Automatic key rotation with configurable intervals
  - Key versioning for backward compatibility
  - PBKDF2 and SCRYPT key derivation functions
  - Configurable iteration counts and custom salts
  - Key export/import for backup and restoration
- **Enhanced AES-GCM**: Improved with better key derivation and management
- **Configuration Extensions**: YAML support for key management settings

### 🛡️ Security Improvements
- **Stronger Key Derivation**: PBKDF2 with 100,000+ iterations (configurable)
- **Memory-Hard KDF**: SCRYPT support for enhanced security
- **Key Rotation**: Automatic rotation prevents long-term key exposure
- **Polymorphic IVs**: Unique initialization vectors for each encryption
- **Authenticated Encryption**: All symmetric algorithms now use AEAD modes

### 📚 Documentation
- Updated README with comprehensive encryption algorithm guide
- Added security recommendations and algorithm selection guide
- Enhanced configuration examples for different security levels
- Complete API documentation for new key management features

### 🧪 Testing
- Comprehensive test suite for all new encryption algorithms
- Key management and rotation testing
- Algorithm compatibility and security verification
- Performance and reliability testing

### 🔧 Technical Improvements
- Enhanced `EncryptionFactory` with key manager support
- New `EnhancedEncryptionAlgorithm` base class for advanced features
- Improved error handling and exception messages
- Better separation of concerns in encryption modules

### 📦 New Modules
- `lib/src/obfuscation/encryption/rsa_encryption.dart` - RSA implementation
- `lib/src/obfuscation/encryption/key_management.dart` - Key management system
- `test/enhanced_encryption_test.dart` - Comprehensive encryption tests
- `example/confidential-advanced.yaml` - Advanced configuration examples

## [0.4.1] - 2025-01-20

### Fixed
- Added Apache-2.0 license field to pubspec.yaml for proper pub.dev recognition
- Removed unused `_generateNonce` method to eliminate static analysis warnings
- Removed unnecessary null assertion operators in compression module
- Fixed web platform compatibility by removing dart:io exports from main library

### Changed
- **BREAKING**: CLI and configuration modules no longer exported from main library
- Updated dependencies to latest versions (archive ^4.0.7, build ^3.0.0, pointycastle ^4.0.0)
- Improved static analysis score and pub.dev compatibility

### Note
- CLI and configuration can still be imported directly when needed in non-web environments
- Package now supports web deployment while maintaining full CLI functionality

## [0.4.0] - 2025-01-20

### Added
- Initial release of Dart Confidential
- Complete port of Swift Confidential functionality to Dart
- CLI tool for obfuscating literals (`dart-confidential`)
- Support for multiple obfuscation techniques:
  - Encryption: AES-128/192/256-GCM, ChaCha20-Poly1305
  - Compression: zlib, gzip, bzip2, lz4, lzfse (fallback), lzma (fallback)
  - Randomization: shuffle, XOR
- YAML-based configuration system
- Code generation for obfuscated literals
- Namespace management (create/extend)
- Access modifier control
- Support for string and list values
- Comprehensive test suite
- Complete documentation and examples

### Features
- **Polymorphic obfuscation**: Different output for same input on each run
- **Composable algorithms**: Mix and match obfuscation techniques
- **Type-safe generated code**: Strongly typed obfuscated values
- **Cross-platform**: Works on all Dart platforms (Flutter, web, server)
- **Security-focused**: Designed for protecting sensitive literals from static analysis

### Documentation
- Comprehensive README with usage examples
- API documentation for all public interfaces
- Security considerations and best practices
- Migration guide from Swift Confidential concepts

### Examples
- Example configuration files
- Sample usage patterns
- CLI usage examples
