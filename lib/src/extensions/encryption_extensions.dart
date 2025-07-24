/// Extension methods for improved API ergonomics.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../obfuscation/encryption/encryption.dart';
import '../obfuscation/secret.dart';

/// Extension methods for String encryption/decryption.
extension StringEncryption on String {
  /// Encrypts this string using the specified algorithm.
  ///
  /// Example:
  /// ```dart
  /// final encrypted = "Hello World".encrypt(algorithm: 'aes-256-gcm', nonce: 12345);
  /// ```
  Secret encrypt({required String algorithm, int? nonce}) {
    final data = Uint8List.fromList(utf8.encode(this));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated string value from this string.
  ///
  /// Example:
  /// ```dart
  /// final obfuscated = "secret".obfuscate(algorithm: 'aes-256-gcm');
  /// ```
  ObfuscatedString obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedString(secret, (data, nonce) {
      final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
      return utf8.decode(decrypted);
    });
  }
}

/// Extension methods for List<String> encryption/decryption.
extension StringListEncryption on List<String> {
  /// Encrypts this string list using the specified algorithm.
  Secret encrypt({required String algorithm, int? nonce}) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated string list value from this list.
  ObfuscatedStringList obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedStringList(secret, (data, nonce) {
      final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
      final json = utf8.decode(decrypted);
      return (jsonDecode(json) as List).cast<String>();
    });
  }
}

/// Extension methods for Map encryption/decryption.
extension MapEncryption on Map<String, dynamic> {
  /// Encrypts this map using the specified algorithm.
  Secret encrypt({required String algorithm, int? nonce}) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated map value from this map.
  ObfuscatedMap obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedMap(secret, (data, nonce) {
      final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
      final json = utf8.decode(decrypted);
      return (jsonDecode(json) as Map).cast<String, dynamic>();
    });
  }
}

/// Extension methods for Secret decryption.
extension SecretDecryption on Secret {
  /// Decrypts this secret using the specified algorithm.
  ///
  /// Example:
  /// ```dart
  /// final decrypted = secret.decrypt&lt;String&gt;(algorithm: 'aes-256-gcm');
  /// ```
  T decrypt<T>({required String algorithm}) {
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);

    if (T == String) {
      return utf8.decode(decrypted) as T;
    } else if (T == List<String>) {
      final json = utf8.decode(decrypted);
      return (jsonDecode(json) as List).cast<String>() as T;
    } else if (T == Map<String, dynamic>) {
      final json = utf8.decode(decrypted);
      return (jsonDecode(json) as Map).cast<String, dynamic>() as T;
    } else {
      final json = utf8.decode(decrypted);
      return jsonDecode(json) as T;
    }
  }

  /// Decrypts this secret as a string.
  String decryptAsString({required String algorithm}) {
    return decrypt<String>(algorithm: algorithm);
  }

  /// Decrypts this secret as a string list.
  List<String> decryptAsStringList({required String algorithm}) {
    return decrypt<List<String>>(algorithm: algorithm);
  }

  /// Decrypts this secret as a map.
  Map<String, dynamic> decryptAsMap({required String algorithm}) {
    return decrypt<Map<String, dynamic>>(algorithm: algorithm);
  }
}

/// Extension methods for ObfuscatedValue convenience.
extension ObfuscatedValueExtensions<T> on ObfuscatedValue<T> {
  /// Gets the value with a more ergonomic syntax.
  ///
  /// Example:
  /// ```dart
  /// final value = obfuscatedSecret.getValue();
  /// // Instead of: final value = obfuscatedSecret.value;
  /// ```
  T getValue() => value;

  /// Gets the value asynchronously (useful for consistency with async providers).
  Future<T> getValueAsync() async => value;

  /// Checks if the obfuscated value is of a specific type.
  bool isType<U>() => T == U;

  /// Safely casts the value to another type.
  U? safeCast<U>() {
    final val = value;
    return val is U ? val : null;
  }

  /// Creates a new obfuscated value with a transformation applied.
  ObfuscatedGeneric<U> map<U>(U Function(T) transform) {
    return ObfuscatedGeneric<U>(
      secret,
      (data, nonce) => transform(deobfuscate(data, nonce)),
    );
  }
}

/// Extension methods for Uint8List encryption.
extension Uint8ListEncryption on Uint8List {
  /// Encrypts this byte array using the specified algorithm.
  Secret encrypt({required String algorithm, int? nonce}) {
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(this, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated byte array value from this data.
  ObfuscatedBytes obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedBytes(secret, (data, nonce) {
      return encryptionAlgorithm.deobfuscate(data, nonce);
    });
  }
}

/// Extension methods for int encryption.
extension IntEncryption on int {
  /// Encrypts this integer using the specified algorithm.
  Secret encrypt({required String algorithm, int? nonce}) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated integer value from this integer.
  ObfuscatedInt obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedInt(secret, (data, nonce) {
      final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
      final json = utf8.decode(decrypted);
      return jsonDecode(json) as int;
    });
  }
}

/// Extension methods for bool encryption.
extension BoolEncryption on bool {
  /// Encrypts this boolean using the specified algorithm.
  Secret encrypt({required String algorithm, int? nonce}) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    return Secret(data: encrypted, nonce: actualNonce);
  }

  /// Creates an obfuscated boolean value from this boolean.
  ObfuscatedBool obfuscate({required String algorithm, int? nonce}) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);

    return ObfuscatedBool(secret, (data, nonce) {
      final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
      final json = utf8.decode(decrypted);
      return jsonDecode(json) as bool;
    });
  }
}

/// Concrete implementation for obfuscated maps.
class ObfuscatedMap extends ObfuscatedValue<Map<String, dynamic>> {
  const ObfuscatedMap(super.secret, super.deobfuscate);
}

/// Concrete implementation for obfuscated byte arrays.
class ObfuscatedBytes extends ObfuscatedValue<Uint8List> {
  const ObfuscatedBytes(super.secret, super.deobfuscate);
}

/// Concrete implementation for generic obfuscated values.
class ObfuscatedGeneric<T> extends ObfuscatedValue<T> {
  const ObfuscatedGeneric(super.secret, super.deobfuscate);
}
