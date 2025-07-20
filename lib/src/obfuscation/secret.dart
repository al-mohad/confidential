/// Secret container for obfuscated data.
library;

import 'dart:typed_data';

/// Container for obfuscated secret data.
class Secret {
  /// The obfuscated data.
  final Uint8List data;
  
  /// The nonce used for obfuscation.
  final int nonce;
  
  const Secret({required this.data, required this.nonce});
  
  /// Creates a Secret from a list of integers.
  factory Secret.fromList(List<int> data, int nonce) {
    return Secret(data: Uint8List.fromList(data), nonce: nonce);
  }
  
  /// Creates a Secret from a hex string.
  factory Secret.fromHex(String hex, int nonce) {
    final data = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      data.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Secret(data: Uint8List.fromList(data), nonce: nonce);
  }
  
  /// Converts the data to a hex string.
  String toHex() {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  @override
  String toString() => 'Secret(data: [${data.length} bytes], nonce: $nonce)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Secret) return false;
    return nonce == other.nonce && 
           data.length == other.data.length &&
           _listEquals(data, other.data);
  }
  
  @override
  int get hashCode => Object.hash(nonce, Object.hashAll(data));
  
  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Type alias for deobfuscation functions.
typedef DeobfuscationFunction<T> = T Function(Uint8List data, int nonce);

/// Base class for obfuscated values.
abstract class ObfuscatedValue<T> {
  /// The secret containing obfuscated data.
  final Secret secret;
  
  /// The deobfuscation function.
  final DeobfuscationFunction<T> deobfuscate;
  
  const ObfuscatedValue(this.secret, this.deobfuscate);
  
  /// Gets the deobfuscated value.
  T get value => deobfuscate(secret.data, secret.nonce);
  
  /// Alias for value getter (projected value).
  T get $ => value;
}

/// Obfuscated string value.
class ObfuscatedString extends ObfuscatedValue<String> {
  const ObfuscatedString(super.secret, super.deobfuscate);
}

/// Obfuscated list of strings value.
class ObfuscatedStringList extends ObfuscatedValue<List<String>> {
  const ObfuscatedStringList(super.secret, super.deobfuscate);
}

/// Obfuscated integer value.
class ObfuscatedInt extends ObfuscatedValue<int> {
  const ObfuscatedInt(super.secret, super.deobfuscate);
}

/// Obfuscated double value.
class ObfuscatedDouble extends ObfuscatedValue<double> {
  const ObfuscatedDouble(super.secret, super.deobfuscate);
}

/// Obfuscated boolean value.
class ObfuscatedBool extends ObfuscatedValue<bool> {
  const ObfuscatedBool(super.secret, super.deobfuscate);
}
