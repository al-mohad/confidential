/// Dart literals obfuscator to defend against static reverse engineering.
///
/// A highly configurable and performant tool for obfuscating Dart literals
/// embedded in the application code that you should protect from static code
/// analysis, making the app more resistant to reverse engineering.
library;

// Core obfuscation functionality
export 'src/cli/cli.dart';
// Code generation
export 'src/code_generation/generator.dart';
// Configuration system
export 'src/configuration/configuration.dart';
// Compression implementations
export 'src/obfuscation/compression/compression.dart';
// Encryption implementations
export 'src/obfuscation/encryption/encryption.dart';
export 'src/obfuscation/obfuscated.dart';
// Core obfuscation functionality
export 'src/obfuscation/obfuscation.dart';
// Secret container
export 'src/obfuscation/secret.dart';
// Randomization implementations
export 'src/obfuscation/randomization/randomization.dart';
