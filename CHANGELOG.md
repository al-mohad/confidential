# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-01-24

### 📱 Added - Platform-Specific Support & Web Handling
- **Platform Detection**: Automatic detection of web, mobile, desktop, and server environments
- **Web Security Warnings**: Clear warnings about JavaScript compilation limitations and security risks
- **Web-Aware Obfuscated Values**: Smart handling with fallback strategies for web platform
- **Platform-Specific Security Assessment**: Detailed security levels and recommendations for each platform
- **Conditional Platform Imports**: Proper web vs native environment handling using dart:io conditionally
- **Global Platform Configuration**: Environment-specific settings with production/development presets
- **Fallback Strategies**: Graceful degradation for insecure environments with configurable options

### 🛡️ Security Features
- Platform-specific security levels (Web: none, iOS: high, Android: medium, etc.)
- Comprehensive security warnings and recommendations for each platform
- Web fallback patterns: public keys, server-side proxy, environment-specific values
- Configurable secret disabling on insecure platforms

## [0.8.0] - 2025-01-24

### 📊 Added - Analytics & Audit Logging
- **Comprehensive Audit System**: Anonymized access tracking with suspicious behavior detection
- **AuditLogger**: Real-time logging of secret access attempts, modifications, and deletions
- **AnalyticsConfig**: Production/development presets with configurable privacy and security settings
- **Suspicious Behavior Detection**: Automatic flagging of rapid access attempts with customizable thresholds
- **Analytics-Aware Secrets**: Obfuscated values that automatically log access with failure tracking
- **Real-time Reporting**: Periodic analytics reports with usage statistics and security metrics
- **Privacy Protection**: Data anonymization with configurable sensitivity filtering
- **Export/Import**: JSON-based audit log backup and restore functionality
- **YAML Configuration**: Analytics settings integrated into configuration system

### 🛡️ Security Features
- Configurable time windows for suspicious detection (default: 5 minutes)
- Access attempt thresholds with critical severity alerts
- Stream-based monitoring for real-time security responses
- Memory-efficient log management with retention limits
- No plaintext secrets in audit logs
 
## [0.7.0] - 2025-01-23

### 🧩 Added - Popular Package Integrations
- **Complete Integration Ecosystem**:
  - Dio HTTP client integration for automatic encrypted token injection
  - Provider dependency injection with reactive secret management
  - Riverpod integration with async value support and providers
  - GetIt service locator integration with lazy singletons and factories
  - BLoC/Cubit state management integration with events and states
  - **NEW: GetX integration** with reactive controllers and services
- **Unified Integration Manager**:
  - Single interface to manage all package integrations
  - Automatic initialization and lifecycle management
  - Cross-integration secret synchronization
  - Factory methods for common integration patterns

### 🌐 Dio HTTP Client Integration
- **ConfidentialDioInterceptor**:
  - Automatic injection of encrypted tokens into HTTP headers
  - Support for static, async, and dynamic token providers
  - Configurable header names and token prefixes
  - Custom header injection and logging capabilities
  - Auto-refresh tokens on 401 errors
- **Extension Methods**:
  - Easy Dio instance setup with `addConfidentialTokens()`
  - Direct token management methods
  - Factory for creating pre-configured Dio instances

### 📦 Provider Integration
- **ObfuscatedValueProvider**: ChangeNotifier-compatible provider for static secrets
- **AsyncObfuscatedValueProvider**: Provider with automatic loading and refresh
- **SecretManagerProvider**: Centralized management of multiple secret providers
- **Features**:
  - Automatic UI updates when secrets change
  - Configurable refresh intervals and auto-refresh
  - Error handling and loading states
  - Disposal management for memory efficiency

### 🎣 Riverpod Integration
- **RiverpodObfuscatedValueProvider**: Static secret providers
- **RiverpodAsyncObfuscatedValueProvider**: Async secret providers with AsyncValue
- **RiverpodObfuscatedValueFamilyProvider**: Parameterized secret providers
- **RiverpodSecretManager**: Centralized secret management
- **Features**:
  - Full AsyncValue support (data, loading, error states)
  - Provider families for parameterized secrets
  - Extension methods for easy provider consumption
  - Automatic invalidation and refresh capabilities

### 🔧 GetIt Service Locator Integration
- **ConfidentialGetItService**: Service for registering and retrieving secrets
- **AsyncObfuscatedValueProvider**: Wrapper for async secrets in GetIt
- **Features**:
  - Singleton and lazy singleton registration
  - Factory registration for dynamic secrets
  - Automatic disposal management
  - Extension methods for direct GetIt integration
  - Bulk registration from secret providers

### 🏗️ BLoC State Management Integration
- **SecretBloc**: BLoC for managing multiple secrets with events and states
- **SecretCubit**: Individual secret management with Cubit pattern
- **Events**: LoadSecretEvent, RefreshSecretEvent, RefreshAllSecretsEvent
- **States**: SecretInitialState, SecretLoadingState, SecretLoadedState, SecretErrorState
- **Features**:
  - Type-safe secret loading and error handling
  - Automatic state management and UI updates
  - Bulk secret operations and refresh capabilities
  - Integration with existing BLoC architecture

### 🎯 GetX Integration (NEW)
- **SecretController**: GetX controller for reactive secret management
- **SecretService**: Application-wide secret service with multiple controllers
- **RxLike Interface**: Reactive values for real-time UI updates
- **Features**:
  - Reactive secret binding with automatic UI updates
  - Computed reactive values based on secrets
  - Worker pattern for reacting to secret changes
  - Multiple controller support for different contexts
  - Extension methods for enhanced ergonomics
  - Full GetX lifecycle integration (onInit, onReady, onClose)

### 🎛️ Unified Integration Manager
- **ConfidentialIntegrationManager**: Single interface for all integrations
- **IntegrationConfig**: Flexible configuration for enabling/disabling integrations
- **Features**:
  - Automatic initialization of all enabled integrations
  - Cross-integration secret synchronization
  - Bulk operations across all integrations
  - Factory methods for common patterns
  - Proper disposal and cleanup management

### 🛠️ Developer Experience Improvements
- **Factory Methods**: Easy creation of integration instances
- **Extension Methods**: Intuitive APIs for each integration
- **Type Safety**: Strong typing throughout all integrations
- **Error Handling**: Comprehensive error handling and recovery
- **Documentation**: Extensive examples and usage patterns
- **Testing**: Full test coverage for all integrations

### 📚 Documentation and Examples
- Complete integration examples for all supported packages
- Real-world usage patterns and best practices
- Performance optimization guidelines
- Migration guides for existing applications
- Advanced configuration examples

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
