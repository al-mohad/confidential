/// Obfuscated annotation and utilities.
library;

import 'secret.dart';

/// Annotation for marking obfuscated properties.
///
/// This is similar to Swift's @Obfuscated property wrapper.
class Obfuscated<T> {
  /// The deobfuscation function to use.
  final DeobfuscationFunction<T> deobfuscationFunction;

  const Obfuscated(this.deobfuscationFunction);
}

/// Utility class for creating obfuscated values.
class ObfuscatedFactory {
  /// Creates an obfuscated string.
  static ObfuscatedString string(
    Secret secret,
    DeobfuscationFunction<String> deobfuscate,
  ) {
    return ObfuscatedString(secret, deobfuscate);
  }

  /// Creates an obfuscated string list.
  static ObfuscatedStringList stringList(
    Secret secret,
    DeobfuscationFunction<List<String>> deobfuscate,
  ) {
    return ObfuscatedStringList(secret, deobfuscate);
  }

  /// Creates an obfuscated integer.
  static ObfuscatedInt integer(
    Secret secret,
    DeobfuscationFunction<int> deobfuscate,
  ) {
    return ObfuscatedInt(secret, deobfuscate);
  }

  /// Creates an obfuscated double.
  static ObfuscatedDouble doubleValue(
    Secret secret,
    DeobfuscationFunction<double> deobfuscate,
  ) {
    return ObfuscatedDouble(secret, deobfuscate);
  }

  /// Creates an obfuscated boolean.
  static ObfuscatedBool boolean(
    Secret secret,
    DeobfuscationFunction<bool> deobfuscate,
  ) {
    return ObfuscatedBool(secret, deobfuscate);
  }
}
