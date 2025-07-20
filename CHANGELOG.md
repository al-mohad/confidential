# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
