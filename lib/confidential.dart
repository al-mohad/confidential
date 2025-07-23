/// Dart literals obfuscator to defend against static reverse engineering.
///
/// A highly configurable and performant tool for obfuscating Dart literals
/// embedded in the application code that you should protect from static code
/// analysis, making the app more resistant to reverse engineering.
library;

// Note: CLI and configuration modules are not exported for web compatibility
// They can be imported directly when needed in non-web environments
// Compression implementations
export 'src/obfuscation/compression/compression.dart';
// Encryption implementations
export 'src/obfuscation/encryption/encryption.dart';
export 'src/obfuscation/encryption/key_management.dart';
export 'src/obfuscation/encryption/rsa_encryption.dart';
export 'src/obfuscation/obfuscated.dart';

// Extension methods for improved ergonomics
export 'src/extensions/encryption_extensions.dart';

// Asynchronous secret loading
export 'src/async/secret_providers.dart';
export 'src/async/async_obfuscated.dart';

// Enhanced grouping and namespacing
export 'src/grouping/secret_groups.dart';
// Core obfuscation functionality
export 'src/obfuscation/obfuscation.dart';
// Randomization implementations
export 'src/obfuscation/randomization/randomization.dart';
// Secret container
export 'src/obfuscation/secret.dart';
