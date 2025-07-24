/// Expirable obfuscated values with automatic rotation.
library;

import 'dart:async';
import 'dart:convert';

import '../obfuscation/encryption/encryption.dart';
import '../obfuscation/secret.dart';

/// Base class for expirable obfuscated values.
abstract class ExpirableObfuscatedValue<T> {
  /// The expirable secret container.
  ExpirableSecret _expirableSecret;

  /// The deobfuscation function.
  final DeobfuscationFunction<T> deobfuscate;

  /// Secret name for refresh callbacks.
  final String secretName;

  ExpirableObfuscatedValue({
    required ExpirableSecret expirableSecret,
    required this.deobfuscate,
    required this.secretName,
  }) : _expirableSecret = expirableSecret;

  /// Gets the deobfuscated value.
  /// Throws [SecretExpiredException] if the secret has hard expired.
  T get value {
    final secret = _expirableSecret.secret; // This checks expiry
    return deobfuscate(secret.data, secret.nonce);
  }

  /// Alias for value getter (projected value).
  T get $ => value;

  /// Gets the current expiry status.
  SecretExpiryStatus get expiryStatus => _expirableSecret.status;

  /// Gets the expiry time.
  DateTime? get expiresAt => _expirableSecret.expiresAt;

  /// Gets time until expiry.
  Duration? get timeUntilExpiry => _expirableSecret.timeUntilExpiry;

  /// Checks if the secret is expired.
  bool get isExpired => _expirableSecret.isExpired;

  /// Checks if the secret is near expiry.
  bool get isNearExpiry => _expirableSecret.isNearExpiry;

  /// Sets the refresh callback.
  void setRefreshCallback(SecretRefreshCallback callback) {
    _expirableSecret.setRefreshCallback(callback);
  }

  /// Sets the expiry callback.
  void setExpiryCallback(SecretExpiryCallback callback) {
    _expirableSecret.setExpiryCallback(callback);
  }

  /// Manually triggers a refresh.
  Future<bool> refresh() => _expirableSecret.refresh(secretName);

  /// Updates the underlying secret (used during refresh).
  void _updateSecret(ExpirableSecret newSecret) {
    _expirableSecret.dispose();
    _expirableSecret = newSecret;
  }

  /// Disposes resources.
  void dispose() {
    _expirableSecret.dispose();
  }
}

/// Expirable obfuscated string value.
class ExpirableObfuscatedString extends ExpirableObfuscatedValue<String> {
  ExpirableObfuscatedString({
    required super.expirableSecret,
    required super.secretName,
    required String algorithm,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           return utf8.decode(decrypted);
         },
       );
}

/// Expirable obfuscated string list value.
class ExpirableObfuscatedStringList
    extends ExpirableObfuscatedValue<List<String>> {
  ExpirableObfuscatedStringList({
    required super.expirableSecret,
    required super.secretName,
    required String algorithm,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           final json = utf8.decode(decrypted);
           return (jsonDecode(json) as List).cast<String>();
         },
       );
}

/// Expirable obfuscated integer value.
class ExpirableObfuscatedInt extends ExpirableObfuscatedValue<int> {
  ExpirableObfuscatedInt({
    required super.expirableSecret,
    required super.secretName,
    required String algorithm,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           final json = utf8.decode(decrypted);
           return jsonDecode(json) as int;
         },
       );
}

/// Expirable obfuscated double value.
class ExpirableObfuscatedDouble extends ExpirableObfuscatedValue<double> {
  ExpirableObfuscatedDouble({
    required super.expirableSecret,
    required super.secretName,
    required String algorithm,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           final json = utf8.decode(decrypted);
           return jsonDecode(json) as double;
         },
       );
}

/// Expirable obfuscated boolean value.
class ExpirableObfuscatedBool extends ExpirableObfuscatedValue<bool> {
  ExpirableObfuscatedBool({
    required super.expirableSecret,
    required super.secretName,
    required String algorithm,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           final json = utf8.decode(decrypted);
           return jsonDecode(json) as bool;
         },
       );
}

/// Generic expirable obfuscated value.
class ExpirableObfuscatedGeneric<T> extends ExpirableObfuscatedValue<T> {
  ExpirableObfuscatedGeneric({
    required super.expirableSecret,
    required super.deobfuscate,
    required super.secretName,
  });

  /// Creates a new expirable obfuscated value with a transformation applied.
  ExpirableObfuscatedGeneric<U> map<U>(U Function(T) transform) {
    return ExpirableObfuscatedGeneric<U>(
      expirableSecret: _expirableSecret,
      secretName: secretName,
      deobfuscate: (data, nonce) => transform(deobfuscate(data, nonce)),
    );
  }
}

/// Factory for creating expirable obfuscated values.
class ExpirableObfuscatedFactory {
  /// Creates an expirable obfuscated string.
  static ExpirableObfuscatedString string({
    required Secret secret,
    required String algorithm,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedString(
      expirableSecret: expirableSecret,
      secretName: secretName,
      algorithm: algorithm,
    );
  }

  /// Creates an expirable obfuscated string list.
  static ExpirableObfuscatedStringList stringList({
    required Secret secret,
    required String algorithm,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedStringList(
      expirableSecret: expirableSecret,
      secretName: secretName,
      algorithm: algorithm,
    );
  }

  /// Creates an expirable obfuscated integer.
  static ExpirableObfuscatedInt integer({
    required Secret secret,
    required String algorithm,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedInt(
      expirableSecret: expirableSecret,
      secretName: secretName,
      algorithm: algorithm,
    );
  }

  /// Creates an expirable obfuscated double.
  static ExpirableObfuscatedDouble doubleValue({
    required Secret secret,
    required String algorithm,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedDouble(
      expirableSecret: expirableSecret,
      secretName: secretName,
      algorithm: algorithm,
    );
  }

  /// Creates an expirable obfuscated boolean.
  static ExpirableObfuscatedBool boolean({
    required Secret secret,
    required String algorithm,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedBool(
      expirableSecret: expirableSecret,
      secretName: secretName,
      algorithm: algorithm,
    );
  }

  /// Creates a generic expirable obfuscated value.
  static ExpirableObfuscatedGeneric<T> generic<T>({
    required Secret secret,
    required DeobfuscationFunction<T> deobfuscate,
    required String secretName,
    required SecretExpiryConfig expiryConfig,
  }) {
    final expirableSecret = ExpirableSecret(
      secret: secret,
      config: expiryConfig,
    );

    return ExpirableObfuscatedGeneric<T>(
      expirableSecret: expirableSecret,
      deobfuscate: deobfuscate,
      secretName: secretName,
    );
  }
}
