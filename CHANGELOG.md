# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
