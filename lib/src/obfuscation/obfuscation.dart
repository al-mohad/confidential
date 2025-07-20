/// Core obfuscation functionality and interfaces.
library;

import 'dart:typed_data';

/// Base interface for all obfuscation steps.
abstract class DataObfuscationStep {
  /// Obfuscates the given data using this step's algorithm.
  Uint8List obfuscate(Uint8List data, int nonce);
}

/// Base interface for all deobfuscation steps.
abstract class DataDeobfuscationStep {
  /// Deobfuscates the given data using this step's algorithm.
  Uint8List deobfuscate(Uint8List data, int nonce);
}

/// Base class for obfuscation/deobfuscation algorithms.
abstract class ObfuscationAlgorithm
    implements DataObfuscationStep, DataDeobfuscationStep {

  const ObfuscationAlgorithm();

  /// The name of this algorithm.
  String get name;

  /// Whether this algorithm is polymorphic (produces different output for same input).
  bool get isPolymorphic;
}

/// Container for obfuscation configuration and algorithms.
class Obfuscation {
  /// List of obfuscation steps to apply in order.
  final List<ObfuscationAlgorithm> steps;
  
  const Obfuscation(this.steps);
  
  /// Applies all obfuscation steps to the data.
  Uint8List obfuscate(Uint8List data, int nonce) {
    Uint8List result = data;
    for (final step in steps) {
      result = step.obfuscate(result, nonce);
    }
    return result;
  }
  
  /// Applies all deobfuscation steps to the data in reverse order.
  Uint8List deobfuscate(Uint8List data, int nonce) {
    Uint8List result = data;
    for (final step in steps.reversed) {
      result = step.deobfuscate(result, nonce);
    }
    return result;
  }
}

/// Exception thrown when obfuscation/deobfuscation fails.
class ObfuscationException implements Exception {
  final String message;
  final Object? cause;
  
  const ObfuscationException(this.message, [this.cause]);
  
  @override
  String toString() => 'ObfuscationException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}
