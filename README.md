# Dart Confidential

[![Pub Version](https://img.shields.io/pub/v/confidential)](https://pub.dev/packages/confidential)
[![Dart](https://img.shields.io/badge/Dart-3.8%2B-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)

A highly configurable and performant tool for obfuscating Dart literals embedded in the application code that you should protect from static code analysis, making the app more resistant to reverse engineering.

This is a Dart port of the [Swift Confidential](https://github.com/securevale/swift-confidential) project by SecureVale, bringing the same powerful obfuscation capabilities to the Dart ecosystem.

Simply integrate the tool with your Dart project, configure your own obfuscation algorithm along with the list of secret literals, and build the project 🚀

## Motivation

Pretty much every single app has at least few literals embedded in code, those include: URLs, various client identifiers (e.g. API keys), pinning data (e.g. X.509 certificates or SPKI digests), database connection strings, RASP-related literals (e.g. list of suspicious packages or file paths for tamper detection), and many other context-specific literals. While the listed examples of code literals might seem innocent, not obfuscating them, in many cases, can be considered as giving a handshake to the potential threat actor. This is especially true in security-sensitive apps, such as mobile banking apps, 2FA authenticator apps and password managers.

This tool aims to provide an elegant and maintainable solution to the above problem by introducing the composable obfuscation techniques that can be freely combined to form an algorithm for obfuscating selected Dart literals.

> **Note**: While Dart Confidential certainly makes the static analysis of the code more challenging, **it is by no means the only code hardening technique that you should employ to protect your app against reverse engineering and tampering**. To achieve a decent level of security, we highly encourage you to supplement this tool's security measures with **runtime application self-protection (RASP) checks**, as well as **Dart code obfuscation**. With that said, no security measure can ever guarantee absolute security. Any motivated and skilled enough attacker will eventually bypass all security protections. For this reason, **always keep your threat models up to date**.

## ✨ Features

- **🔐 Multi-Algorithm Obfuscation**: Supports AES-256-GCM, ChaCha20-Poly1305, XOR, and compression
- **🔒 Hardware-Backed Security**: Platform-specific secure storage (iOS Keychain, Android Keystore) with biometric authentication
- **📦 Remote Secret Sources**: AWS Secrets Manager, Google Secret Manager, and HashiCorp Vault integration
- **🎯 Type-Safe API**: Strongly typed obfuscated values with compile-time safety
- **🔄 Asynchronous Loading**: Non-blocking secret loading with caching and retry mechanisms
- **💾 Intelligent Caching**: Local encrypted caching with compression and automatic cleanup
- **📊 Analytics & Audit Logging**: Comprehensive access tracking with suspicious activity detection
- **🌐 Platform-Aware Security**: Web-specific warnings and platform-optimized protection
- **🔗 Popular Integrations**: Built-in support for Dio, Provider, Riverpod, GetIt, BLoC, and GetX
- **🧰 CLI & Build-Time Integration**: Complete toolchain for build-time secret management
- **🔄 Build Runner Support**: Automatic code generation with platform-aware optimizations
- **⚡ High Performance**: Optimized algorithms with minimal runtime overhead
- **🛡️ Security-First Design**: Defense against static analysis and reverse engineering

## Getting Started

Begin by creating a `confidential.yaml` YAML configuration file in the root directory of your Dart project. At minimum, the configuration must contain obfuscation algorithm and one or more secret definitions.

For example, a configuration file for a hypothetical security module could look like this:

```yaml
algorithm:
  - encrypt using aes-192-gcm
  - shuffle

defaultNamespace: create Secrets

secrets:
  - name: suspiciousDynamicLibraries
    value:
      - Substrate
      - Substitute
      - FridaGadget
      # ... other suspicious libraries
  - name: suspiciousFilePaths
    value:
      - /.installed_unc0ver
      - /usr/sbin/frida-server
      - /private/var/lib/cydia
      # ... other suspicious file paths
```

> **Warning**: The algorithm from the above configuration serves as example only, **do not use this particular algorithm in your production code**. Instead, compose your own algorithm from the [obfuscation techniques](#obfuscation-techniques) described below and **don't share your algorithm with anyone**.

Having created the configuration file, you can use the `dart-confidential` CLI tool to generate Dart code with obfuscated secret literals:

```bash
dart run dart-confidential obfuscate --configuration confidential.yaml --output lib/generated/confidential.dart
```

Upon successful command execution, the generated `confidential.dart` file will contain code similar to the following:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by dart-confidential

import 'package:confidential/confidential.dart';
import 'dart:typed_data';
import 'dart:convert';

class ObfuscatedLiterals {

  static final suspiciousDynamicLibraries = ObfuscatedValue<List<String>>(
    Secret(
      data: Uint8List.fromList([0x14, 0x4b, 0xe5, 0x48, /* ... */]),
      nonce: 13452749969377545032,
    ),
    _deobfuscateData,
  );

  static final suspiciousFilePaths = ObfuscatedValue<List<String>>(
    Secret(
      data: Uint8List.fromList([0x04, 0xdf, 0x99, 0x61, /* ... */]),
      nonce: 4402772458530791297,
    ),
    _deobfuscateData,
  );

  static T _deobfuscateData<T>(Uint8List data, int nonce) {
    // Deobfuscation implementation
  }
}
```

You can then, for example, iterate over a deobfuscated array of suspicious dynamic libraries in your own code using the projected value of the generated `suspiciousDynamicLibraries` property:

```dart
final suspiciousLibraries = ObfuscatedLiterals.suspiciousDynamicLibraries.$
    .map((lib) => lib.toLowerCase())
    .toList();

final checkPassed = loadedLibraries
    .every((lib) => !suspiciousLibraries.any((suspicious) =>
        lib.toLowerCase().contains(suspicious)));
```

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  confidential: ^0.4.0

dev_dependencies:
  confidential: ^0.4.0
```

Then run:

```bash
dart pub get
```

## Configuration

Dart Confidential supports a number of configuration options, all of which are stored in a single YAML configuration file.

### YAML configuration keys

| Key | Value type | Description |
|-----|------------|-------------|
| `algorithm` | List of strings | The list of obfuscation techniques representing individual steps that are composed together to form the obfuscation algorithm. See [Obfuscation techniques](#obfuscation-techniques) section for usage details. **Required.** |
| `defaultAccessModifier` | String | The default access-level modifier applied to each generated secret literal, unless the secret definition states otherwise. The default value is `internal`. |
| `defaultNamespace` | String | The default namespace in which to enclose all the generated secret literals without explicitly assigned namespace. The default value is `create Secrets`. |
| `experimentalMode` | Boolean | Specifies whether to use experimental mode. The default value is `false`. |
| `internalImport` | Boolean | Specifies whether to generate internal import statements. The default value is `false`. |
| `secrets` | List of objects | The list of objects defining the secret literals to be obfuscated. See [Secrets](#secrets) section for usage details. **Required.** |

### Obfuscation techniques

The obfuscation techniques are the composable building blocks from which you can create your own obfuscation algorithm. You can compose them in any order you want, so that no one except you knows how the secret literals are obfuscated.

#### Encryption

This technique involves data encryption using the algorithm of your choice. The encryption technique is _polymorphic_, meaning that given the same input data, different output data is produced with each run.

**Syntax**
```
encrypt using <algorithm>
```

**Symmetric Encryption Algorithms:**
- `aes-128-gcm` - The Advanced Encryption Standard (AES) algorithm in Galois/Counter Mode (GCM) with 128-bit key
- `aes-192-gcm` - The Advanced Encryption Standard (AES) algorithm in Galois/Counter Mode (GCM) with 192-bit key
- `aes-256-gcm` - The Advanced Encryption Standard (AES) algorithm in Galois/Counter Mode (GCM) with 256-bit key 🔒 **Recommended**
- `chacha20-poly1305` - The ChaCha20-Poly1305 authenticated encryption algorithm

**Asymmetric Encryption Algorithms:**
- `rsa-2048` - RSA encryption with 2048-bit keys and OAEP padding
- `rsa-4096` - RSA encryption with 4096-bit keys and OAEP padding 🔒 **High Security**
- `rsa-2048-sha256` - RSA-2048 with SHA-256 hash function
- `rsa-4096-sha256` - RSA-4096 with SHA-256 hash function
- `rsa-2048-sha512` - RSA-2048 with SHA-512 hash function
- `rsa-4096-sha512` - RSA-4096 with SHA-512 hash function 🔒 **Maximum Security**

#### Compression

This technique involves data compression using the algorithm of your choice. In general, the compression technique is _non-polymorphic_, meaning that given the same input data, the same output data is produced with each run. However, Dart Confidential applies additional polymorphic obfuscation routines to mask the bytes identifying the compression algorithm used.

**Syntax**
```
compress using <algorithm>
```

Supported algorithms:
- `zlib` - The zlib compression algorithm
- `gzip` - The GZip compression algorithm
- `bzip2` - The BZip2 compression algorithm
- `lz4` - The LZ4 compression algorithm
- `lzfse` - The LZFSE compression algorithm (fallback to gzip)
- `lzma` - The LZMA compression algorithm (fallback to bzip2)

#### Randomization

This technique involves data randomization. The randomization technique is _polymorphic_, meaning that given the same input data, different output data is produced with each run.

**Syntax**
```
shuffle
```

### Secrets

The configuration file utilizes YAML objects to describe the secret literals, which are to be obfuscated.

| Key | Value type | Description |
|-----|------------|-------------|
| `name` | String | The name of the generated Dart property containing obfuscated secret literal's data. This value is used as-is, without validity checking. Thus, make sure to use a valid property name. **Required.** |
| `value` | String or List of strings | The plain value of the secret literal, which is to be obfuscated. The YAML data types are mapped to `String` and `List<String>` in Dart, respectively. **Required.** |
| `accessModifier` | String | The access-level modifier of the generated Dart property containing obfuscated secret literal's data. The supported values are `internal`, `public` and `private`. If not specified, the top-level `defaultAccessModifier` value is used. |
| `namespace` | String | The namespace in which to enclose the generated secret literal declaration. |

### Namespaces

In accordance with Dart programming best practices, Dart Confidential encapsulates generated secret literal declarations in namespaces (i.e. classes). The namespaces syntax allows you to either create a new namespace or extend an existing one.

**Syntax**
```
create <namespace>                    # creates new namespace
extend <namespace> [from <module>]    # extends existing namespace, optionally specifying
                                      # the module to which this namespace belongs
```

**Example usage**

Assuming that you would like to keep the generated secret literal declaration(s) in a new namespace named `Secrets`, use the following YAML code:

```yaml
defaultNamespace: create Secrets
```

If, however, you would rather like to keep the generated secret literal declaration(s) in an existing namespace named `Pinning` and imported from `Crypto` module, use the following YAML code instead:

```yaml
namespace: extend Pinning from Crypto
```

## 🔒 Enhanced Security Features

### Key Management and Rotation

Dart Confidential now supports advanced key management with automatic key rotation for enhanced security:

```yaml
keyManagement:
  enableRotation: true              # Enable automatic key rotation
  rotationIntervalDays: 30          # Rotate keys every 30 days
  maxOldKeys: 3                     # Keep 3 old keys for backward compatibility
  keyDerivationFunction: PBKDF2     # Use PBKDF2 for key derivation (or SCRYPT)
  keyDerivationIterations: 100000   # Number of iterations for key strengthening
  salt: "your-unique-salt-here"     # Custom salt for key derivation
```

**Key Derivation Functions:**
- `PBKDF2` - Password-Based Key Derivation Function 2 (recommended for most use cases)
- `SCRYPT` - Memory-hard key derivation function (higher security, more resource intensive)

**Benefits:**
- 🔄 **Automatic Key Rotation**: Keys are automatically rotated based on your schedule
- 🔙 **Backward Compatibility**: Old keys are retained for decrypting existing data
- 🛡️ **Strong Key Derivation**: PBKDF2/SCRYPT with configurable iterations
- 🔐 **Version Management**: Each key has a version for proper tracking

### Algorithm Selection Guide

**For Maximum Security (Recommended):**
```yaml
algorithm:
  - encrypt using aes-256-gcm
  - compress using bzip2
  - encrypt using chacha20-poly1305
  - shuffle
```

**For High-Security Asymmetric Encryption:**
```yaml
algorithm:
  - encrypt using rsa-4096-sha512
  - compress using lz4
```

**For Balanced Security and Performance:**
```yaml
algorithm:
  - encrypt using aes-256-gcm
  - shuffle
```

### Hardware-Backed Security

Dart Confidential supports hardware-backed key storage for maximum security on supported platforms:

```dart
import 'package:confidential/src/platform/hardware_key_manager.dart';

// Create hardware key manager with maximum security
final keyManager = HardwareKeyManager.maxSecurity();

// Check hardware security level
final securityLevel = await keyManager.getSecurityLevel();
print('Security level: ${securityLevel.level}'); // hardware, software, or unknown

// Use hardware-backed obfuscated values
final hardwareSecret = await keyManager.createObfuscatedValue(
  'sensitive-api-key',
  algorithm: 'aes-256-gcm',
);
```

**Platform Support:**
- 🍎 **iOS**: Secure Enclave and Keychain with biometric authentication
- 🤖 **Android**: Android Keystore with hardware security module support
- 🖥️ **Desktop**: Software fallback with enhanced security
- 🌐 **Web**: Software-only with security warnings

**Features:**
- 🔒 **Biometric Authentication**: Touch ID, Face ID, and fingerprint support
- 🛡️ **Hardware Security Module**: Uses dedicated security chips when available
- 🔄 **Automatic Fallback**: Gracefully falls back to software storage
- 📱 **Platform Detection**: Automatically detects and uses best available security

### Remote Secret Sources

Dart Confidential integrates with popular cloud secret management services for enterprise-grade secret storage:

```dart
import 'package:confidential/confidential.dart';

// AWS Secrets Manager
final awsConfig = RemoteSecretConfig.aws(
  accessKeyId: 'AKIA...',
  secretAccessKey: 'your-secret-key',
  region: 'us-east-1',
);

final awsProvider = AwsSecretsManagerProvider(config: awsConfig);
final apiKey = await awsProvider.getSecretValue('production-api-key');

// Google Secret Manager
final googleConfig = RemoteSecretConfig.gcp(
  projectId: 'my-project',
  serviceAccountKey: 'service-account-json',
);

final googleProvider = GoogleSecretManagerProvider(config: googleConfig);
final dbPassword = await googleProvider.getSecretValue('database-password');

// HashiCorp Vault
final vaultConfig = RemoteSecretConfig.vault(
  address: 'https://vault.company.com',
  token: 'hvs.your-vault-token',
);

final vaultProvider = HashiCorpVaultProvider(config: vaultConfig);
final config = await vaultProvider.getSecretValue('app-config');

// With Local Caching
final cacheConfig = LocalCacheConfig(
  expiration: Duration(hours: 1),
  encryptCache: true,
  compressCache: true,
);

final cachedProvider = await CachedRemoteProviderFactory.createAwsProvider(
  config: awsConfig,
  cacheConfig: cacheConfig,
  cacheFirst: true,
  backgroundRefresh: true,
);
```

**Supported Providers:**
- 🟠 **AWS Secrets Manager**: Full API integration with IAM authentication
- 🔵 **Google Secret Manager**: Service account and OAuth token support
- 🟣 **HashiCorp Vault**: KV v2 engine with token authentication
- 💾 **Local Caching**: Encrypted local storage with intelligent refresh

**Features:**
- 🔄 **Batch Operations**: Retrieve multiple secrets efficiently
- 📊 **Health Monitoring**: Connection testing and status reporting
- 🛡️ **Secure Caching**: AES-256-GCM encrypted local cache
- 🔄 **Background Refresh**: Automatic cache updates
- 📈 **Performance Metrics**: Cache hit rates and response times

## 🧼 Enhanced API Ergonomics

### Extension Methods for Easy Encryption

Dart Confidential now provides convenient extension methods for encrypting and obfuscating data directly:

```dart
// String encryption
final secret = "Hello, World!".encrypt(algorithm: 'aes-256-gcm');
final decrypted = secret.decryptAsString(algorithm: 'aes-256-gcm');

// Direct obfuscation
final obfuscated = "Secret Message".obfuscate(algorithm: 'aes-256-gcm');
print(obfuscated.value); // or obfuscated.$

// List and Map encryption
final listSecret = ['item1', 'item2'].encrypt(algorithm: 'chacha20-poly1305');
final mapSecret = {'key': 'value'}.encrypt(algorithm: 'rsa-2048');

// Type-safe decryption
final decryptedList = listSecret.decryptAsStringList(algorithm: 'chacha20-poly1305');
final decryptedMap = mapSecret.decryptAsMap(algorithm: 'rsa-2048');

// Advanced operations
final mapped = obfuscated.map<int>((s) => s.length);
final asyncValue = await obfuscated.getValueAsync();
```

### Enhanced Secret Grouping and Organization

Organize your secrets with groups, tags, and environments:

```yaml
groups:
  - name: apiSecrets
    description: "API-related secrets"
    namespace: create ApiSecrets
    tags: ["api", "external"]
    environment: production
    secrets:
      - name: apiKey
        value: "secret-key-123"
        tags: ["critical", "auth"]
        priority: 10

  - name: databaseSecrets
    description: "Database credentials"
    namespace: create DatabaseSecrets
    tags: ["database", "internal"]
    environment: production
    secrets:
      - name: connectionString
        value: "postgresql://..."
        tags: ["critical", "connection"]
        priority: 10
```

### Asynchronous Secret Loading

Load secrets from remote sources or files asynchronously:

```dart
// File-based provider
final fileProvider = FileSecretProvider(basePath: '/secure/secrets');

// HTTP-based provider
final httpProvider = HttpSecretProvider(
  baseUrl: 'https://vault.example.com',
  headers: {'Authorization': 'Bearer token'},
);

// Composite provider (tries multiple sources)
final provider = CompositeSecretProvider([fileProvider, httpProvider]);

// Async obfuscated values
final factory = AsyncObfuscatedFactory(provider: provider);
final asyncSecret = factory.string('apiKey');

// Load with caching and error handling
final value = await asyncSecret.value;
final valueOrDefault = await asyncSecret.getValueOrDefault('fallback');
final valueWithTimeout = await asyncSecret.getValueWithTimeout(Duration(seconds: 5));

// Stream updates
asyncSecret.asStream(interval: Duration(minutes: 1))
  .listen((value) => print('Updated: $value'));
```

### Advanced Secret Management

```dart
// Secret filtering and organization
final manager = SecretGroupManager.fromYaml(config);

// Filter by environment
final prodSecrets = manager.getSecrets(SecretFilter.environment('production'));

// Filter by tags
final criticalSecrets = manager.getSecrets(SecretFilter.tags(['critical']));

// Exclude deprecated secrets
final activeSecrets = manager.getSecrets(SecretFilter.excludeDeprecated());

// Complex filtering
final filtered = manager.getSecrets(SecretFilter(
  groups: ['api'],
  tags: ['critical'],
  environment: 'production',
  excludeDeprecated: true,
));
```

## 🧩 Popular Package Integrations

Dart Confidential provides seamless integration with popular packages for dependency injection, state management, and HTTP clients:

### 🌐 Dio HTTP Client Integration

Automatically inject encrypted tokens into HTTP requests:

```dart
// Setup Dio with confidential token injection
final dio = Dio();
final interceptor = dio.addConfidentialTokens(
  config: DioIntegrationConfig(
    authHeaderName: 'Authorization',
    tokenPrefix: 'Bearer ',
    enableLogging: true,
  ),
);

// Add tokens from various sources
interceptor.addStaticToken('auth', authToken.obfuscate(algorithm: 'aes-256-gcm'));
interceptor.addAsyncToken('api-key', asyncApiKey);
interceptor.addDynamicToken('session', () => getCurrentSessionId());

// All requests automatically include encrypted tokens
final response = await dio.get('/api/user/profile');
```

### 📦 Provider Integration

Inject secrets via Provider dependency injection:

```dart
// Create Provider-compatible secret manager
final manager = ConfidentialProviderFactory.createManager();
manager.addStatic('jwtSecret', jwtSecret.obfuscate(algorithm: 'aes-256-gcm'));
manager.addAsync('databaseUrl', asyncDatabaseUrl);

// In your widget tree
ChangeNotifierProvider(
  create: (_) => manager,
  child: MyApp(),
)

// In your widgets
Consumer<SecretManagerProvider>(
  builder: (context, secrets, child) {
    final jwt = secrets.getStaticValue<String>("jwtSecret");
    return Text("JWT: ${jwt?.substring(0, 10)}...");
  },
)
```

### 🎣 Riverpod Integration

Use secrets with Riverpod providers:

```dart
// Define providers
final apiKeyProvider = ConfidentialRiverpodFactory.createStatic(
  apiKeySecret, name: "apiKey");

final asyncSecretProvider = ConfidentialRiverpodFactory.createAsync(
  asyncSecret, name: "asyncSecret");

// In your widgets
Consumer(builder: (context, ref, child) {
  final apiKey = ref.watch(apiKeyProvider);
  return Text("API Key: ${apiKey.substring(0, 10)}...");
});

// For async providers
Consumer(builder: (context, ref, child) {
  final asyncValue = ref.watch(asyncSecretProvider);
  return asyncValue.when(
    data: (secret) => Text("Secret: $secret"),
    loading: () => CircularProgressIndicator(),
    error: (err, stack) => Text("Error: $err"),
  );
});
```

### 🔧 GetIt Service Locator Integration

Register secrets with GetIt:

```dart
// Setup GetIt with confidential secrets
await ConfidentialGetItFactory.setupWithProvider(
  getIt: GetIt.instance,
  secretProvider: yourSecretProvider,
  secretNames: {"apiKey": "aes-256-gcm"},
);

// Access anywhere in your app
final apiKey = await GetIt.instance.getAsyncObfuscated<String>("apiKey");
final staticSecret = GetIt.instance.getObfuscated<String>("staticSecret");
```

### 🏗️ BLoC State Management Integration

Manage secrets with BLoC pattern:

```dart
// Create BLoC with secrets
final secretBloc = ConfidentialBlocFactory.createBloc();
secretBloc.addStaticSecret('sessionKey', sessionKey);
secretBloc.add(LoadSecretEvent('userToken'));

// In your widget
BlocBuilder<SecretBloc, SecretState>(
  builder: (context, state) {
    if (state is SecretLoadedState<String>) {
      return Text("Secret: ${state.value}");
    } else if (state is SecretLoadingState) {
      return CircularProgressIndicator();
    } else if (state is SecretErrorState) {
      return Text("Error: ${state.error}");
    }
    return Text("No secret loaded");
  },
)
```

### 🎯 GetX Integration

Reactive secret management with GetX:

```dart
// Create GetX service
final secretService = ConfidentialGetXFactory.createService();
secretService.addStaticSecret('sessionKey', sessionKey);
secretService.addAsyncSecret('authToken', asyncAuthToken);

// In your GetX controller
class MyController extends GetxController {
  final secretService = Get.find<SecretService>();

  @override
  void onInit() {
    super.onInit();
    // Access secrets reactively
    final apiKey = secretService.getRx<String>("apiKey");
    apiKey?.listen((value) => print("API key updated: $value"));
  }
}

// In your widgets with reactive updates
Obx(() {
  final apiKey = secretService.getStatic<String>("apiKey");
  return Text("API Key: ${apiKey?.substring(0, 10)}...");
});
```

### 🎛️ Unified Integration Manager

Manage all integrations from a single interface:

```dart
// Create manager with all integrations enabled
final manager = ConfidentialIntegrationFactory.createFullIntegration();
await manager.initialize(
  dioInstance: dio,
  getItInstance: GetIt.instance,
  secretProvider: yourProvider,
  secretNames: {"apiKey": "aes-256-gcm"},
);

// Add secrets to all integrations at once
manager.addStaticSecret("newSecret", obfuscatedValue);

// Access different integrations
final providerManager = manager.providerManager;
final secretBloc = manager.secretBloc;
final dioInterceptor = manager.dioInterceptor;
final getXService = manager.getXService;

// Refresh all secrets across all integrations
await manager.refreshAllSecrets();
```

## 📊 Analytics & Audit Logging

Monitor secret access and detect suspicious behavior with comprehensive audit logging:

### Basic Analytics Setup

```dart
// Configure analytics for production
final config = AnalyticsConfig.production();
final logger = AuditLogger(config);

// Create analytics-aware secrets
final apiKey = 'secret-key'.obfuscate(algorithm: 'aes-256-gcm')
    .withAnalytics(logger, 'apiKey');

// Access is automatically logged
final key = apiKey.value; // Logged with metadata and statistics
```

### Suspicious Behavior Detection

```dart
// Monitor for security threats
logger.suspiciousEvents.listen((event) {
  print('🚨 SUSPICIOUS: ${event.message}');
  if (event.severity == AuditSeverity.critical) {
    securityTeam.alert(event);
  }
});

// Configure detection thresholds
final config = AnalyticsConfig(
  suspiciousTimeWindowMinutes: 5,
  maxAccessAttemptsPerWindow: 20,
  enableSuspiciousDetection: true,
);
```

### Real-time Analytics Reporting

```dart
// Generate periodic reports
final reporter = AnalyticsReporter(logger);
reporter.reports.listen((report) {
  print('📊 ${report.totalAccesses} accesses, ${report.successRate}% success rate');
  if (report.hasSecurityConcerns) {
    dashboard.showSecurityAlert();
  }
});
reporter.startReporting();
```

### YAML Configuration

```yaml
analytics:
  enabled: true
  enableAccessCounters: true
  enableSuspiciousDetection: true
  anonymizeData: true
  maxLogEntries: 5000
  suspiciousTimeWindowMinutes: 5
  maxAccessAttemptsPerWindow: 20
```

## 📱 Platform-Specific Support & Web Handling

Dart Confidential provides intelligent platform detection and web-specific security handling:

### Platform Detection & Security Assessment

```dart
// Automatic platform detection
final platform = PlatformDetector.detectPlatform();
final securityInfo = PlatformDetector.getSecurityInfo();

print('Platform: ${platform.name}');
print('Security Level: ${securityInfo.securityLevel.name}');
print('Secrets Secure: ${PlatformDetector.areSecretsSecure}');

// Platform checks
if (PlatformDetector.isWeb) {
  print('⚠️ Web platform detected - secrets not secure');
} else if (PlatformDetector.isMobile) {
  print('📱 Mobile platform - moderate to high security');
}
```

### Web-Aware Obfuscated Values

```dart
// Automatic web warnings
final apiKey = 'secret-key'.obfuscate(algorithm: 'aes-256-gcm')
    .withWebWarnings('apiKey');

// Fallback for web platform
final dbUrl = 'real-db-url'.obfuscate(algorithm: 'aes-256-gcm')
    .webAware('dbUrl', fallbackValue: 'sqlite:///fallback.db');

// Disabled on web with fallback
final encKey = 'encryption-key'.obfuscate(algorithm: 'aes-256-gcm')
    .webDisabled('encKey', fallbackValue: 'fallback-key');

// Access with automatic platform handling
final key = apiKey.value; // Shows warning on web, works normally elsewhere
```

### Platform-Specific Configuration

```dart
// Production configuration with web warnings
GlobalPlatformConfig.initializeForEnvironment(
  isProduction: true,
  showPlatformInfo: false,
);

// Development configuration with detailed info
GlobalPlatformConfig.initializeForEnvironment(
  isProduction: false,
  showPlatformInfo: true,
);

// Access global platform-aware manager
final manager = GlobalPlatformConfig.getGlobalManager();
manager.registerSecret('apiKey', 'secret-value');
```

### Web Security Best Practices

**❌ Never store on web:**
- Database passwords
- Private API keys
- Encryption keys
- Authentication secrets

**✅ Safe for web:**
- Public API keys
- Configuration flags
- UI settings
- Non-sensitive data

**💡 Recommended patterns:**
```dart
// Pattern 1: Public keys (safe for web)
final publicKey = 'pk_live_public_key'.obfuscate(algorithm: 'aes-256-gcm')
    .webAware('publicKey', config: WebAwareConfig.silent());

// Pattern 2: Server-side proxy
// Store secrets on server, expose via authenticated API endpoints

// Pattern 3: Environment-specific fallbacks
final serverKey = 'sk_live_server_key'.obfuscate(algorithm: 'aes-256-gcm')
    .webAware('serverKey',
      fallbackValue: 'pk_live_public_fallback',
      config: WebAwareConfig.webWithWarnings());
```

## Usage

### Build Runner Integration (Recommended)

The easiest way to use dart-confidential is with build_runner, which automatically generates obfuscated code when you build your project:

1. Add build_runner to your `pubspec.yaml`:

```yaml
dev_dependencies:
  build_runner: ^2.4.7
  confidential: ^0.4.0
```

2. Create a `confidential.yaml` configuration file in your project root
3. Run the build:

```bash
dart run build_runner build
```

The obfuscated code will be automatically generated in `lib/generated/confidential.dart`.

### CLI Usage

You can also use the command-line tool directly:

```bash
# Basic usage
dart run dart-confidential obfuscate -c confidential.yaml -o lib/generated/confidential.dart

# Show help
dart run dart-confidential --help

# Show version
dart run dart-confidential --version
```

### Commands

- `obfuscate` - Obfuscate literals based on configuration

### Options

- `-c, --configuration` - Path to the configuration file (required)
- `-o, --output` - Output file path (required)
- `-h, --help` - Show help message
- `-v, --version` - Show version information

## Examples

See the `example/` directory for complete examples:

- `example/confidential.yaml` - Example configuration file
- `example/confidential_example.dart` - Example usage
- `example/` - Complete Flutter app demonstrating build_runner integration

### Running the Flutter Example

1. Navigate to the example directory:
```bash
cd example
```

2. Get dependencies:
```bash
dart pub get
```

3. Generate obfuscated code:
```bash
dart run build_runner build
```

4. Run the Flutter app:
```bash
flutter run
```

The example app demonstrates how to use obfuscated literals in a real Flutter application.

## 🧰 CLI & Build-Time Integration

Dart Confidential includes a comprehensive CLI tool for build-time secret management and integration with your development workflow.

### Installation & Setup

Initialize your project with platform-specific configuration:

```bash
# Initialize a Flutter project
dart run dart-confidential init --project-type flutter

# Initialize with build_runner integration
dart run dart-confidential init --with-build-runner --with-examples
```

### CLI Commands

#### 🚀 Project Initialization
```bash
# Initialize with platform detection and examples
dart run dart-confidential init --project-type flutter --with-examples

# Initialize for different project types
dart run dart-confidential init --project-type dart
dart run dart-confidential init --project-type package
```

#### ⚙️ Code Generation
```bash
# Generate obfuscated Dart code
dart run dart-confidential obfuscate --config confidential.yaml

# Watch mode for development
dart run dart-confidential obfuscate --watch

# Different output formats
dart run dart-confidential obfuscate --format json
dart run dart-confidential obfuscate --format yaml --minify
```

#### 📦 Asset Generation
```bash
# Generate encrypted asset files
dart run dart-confidential generate-assets --output-dir assets/encrypted

# Generate compressed binary assets
dart run dart-confidential generate-assets --format binary --compress

# Generate with manifest
dart run dart-confidential generate-assets --manifest assets_manifest.json
```

#### 🌍 Environment Files
```bash
# Generate .env files
dart run dart-confidential generate-env --format dotenv --environment production

# Generate JSON environment files
dart run dart-confidential generate-env --format json --include-metadata

# Generate shell scripts
dart run dart-confidential generate-env --format shell --prefix "MYAPP_"
```

#### 💉 Build-Time Injection
```bash
# Inject secrets at compile time
dart run dart-confidential inject-secrets --target flutter --injection-method compile-time

# Runtime injection with assets
dart run dart-confidential inject-secrets --injection-method runtime

# Hybrid approach (recommended)
dart run dart-confidential inject-secrets --injection-method hybrid --platform android
```

#### ✅ Validation
```bash
# Validate configuration
dart run dart-confidential validate --config confidential.yaml

# Strict validation with auto-fix
dart run dart-confidential validate --strict --fix

# Platform-specific validation
dart run dart-confidential validate --check-platform --check-algorithms
```

### Build Runner Integration

Configure automatic code generation in `build.yaml`:

```yaml
targets:
  $default:
    builders:
      confidential|confidential_builder:
        enabled: true
        options:
          config_file: confidential.yaml
          output_file: lib/generated/confidential.dart
          generate_assets: true
          assets_dir: assets/encrypted
          generate_env: true
          env_format: dotenv
```

Then run:

```bash
# One-time build
dart run build_runner build

# Watch mode
dart run build_runner watch

# Clean and rebuild
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Complete Workflow Example

```bash
# 1. Initialize project
dart run dart-confidential init --project-type flutter --with-build-runner

# 2. Edit confidential.yaml with your secrets
# (Add your API keys, database passwords, etc.)

# 3. Generate code
dart run dart-confidential obfuscate

# 4. Generate assets for runtime loading
dart run dart-confidential generate-assets --format binary --split

# 5. Generate environment files
dart run dart-confidential generate-env --format dotenv --environment production

# 6. Validate configuration
dart run dart-confidential validate --strict

# 7. Build with build_runner (automatic)
dart run build_runner build

# 8. Inject secrets for production build
dart run dart-confidential inject-secrets --target flutter --injection-method hybrid

# 9. Build your app
flutter build apk --release
```

### Platform-Specific Features

The CLI automatically detects your target platform and provides:

- **🌐 Web Platform**: Security warnings about JavaScript compilation limitations
- **📱 Mobile Platforms**: Optimized obfuscation for iOS and Android
- **🖥️ Desktop Platforms**: Enhanced security for native applications
- **🔧 Development Mode**: Additional debugging and validation features

## Security Considerations

> **Warning**: The example algorithms in this documentation are for demonstration purposes only. **Do not use these particular algorithms in your production code**. Instead, compose your own algorithm from the available obfuscation techniques and **don't share your algorithm with anyone**.

Following secure SDLC best practices, consider not committing the production algorithm in your repository, but instead configure your CI/CD pipeline to run a custom script (ideally just before the build step), which will modify the configuration file by replacing the algorithm value with the one retrieved from the secrets vault.

## Differences from Swift Confidential

This Dart implementation maintains feature parity with the original Swift Confidential while adapting to Dart's ecosystem:

- **Property Wrappers → ObfuscatedValue**: Dart doesn't have property wrappers, so we use `ObfuscatedValue<T>` classes instead
- **Macros → Code Generation**: Instead of Swift macros, we use a CLI tool for code generation
- **Package Manager**: Uses `pub` instead of Swift Package Manager
- **Platform Support**: Supports all Dart platforms (Flutter, web, server, etc.)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This project is a Dart port of [Swift Confidential](https://github.com/securevale/swift-confidential) by SecureVale. We thank the original authors for their excellent work and for making it available under an open-source license.
