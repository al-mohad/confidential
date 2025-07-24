/// Extension methods for creating expirable secrets easily.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../extensions/encryption_extensions.dart';
import '../obfuscation/encryption/encryption.dart';
import '../obfuscation/secret.dart';
import 'expirable_obfuscated.dart';
import 'expirable_secret.dart';

/// Extension methods for String to create expirable obfuscated values.
extension StringExpiryExtensions on String {
  /// Creates an expirable obfuscated string with TTL.
  ///
  /// Example:
  /// ```dart
  /// final expirableSecret = "api-key".obfuscateWithTTL(
  ///   algorithm: 'aes-256-gcm',
  ///   ttl: Duration(hours: 24),
  ///   secretName: 'apiKey',
  /// );
  /// ```
  ExpirableObfuscatedString obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.string(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }

  /// Creates an expirable obfuscated string with absolute expiry time.
  ///
  /// Example:
  /// ```dart
  /// final expirableSecret = "api-key".obfuscateWithExpiry(
  ///   algorithm: 'aes-256-gcm',
  ///   expiresAt: DateTime.now().add(Duration(hours: 24)),
  ///   secretName: 'apiKey',
  /// );
  /// ```
  ExpirableObfuscatedString obfuscateWithExpiry({
    required String algorithm,
    required DateTime expiresAt,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);

    final expiryConfig = SecretExpiryConfig.withExpiryTime(
      expiresAt,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.string(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }

  /// Creates an expirable encrypted secret with TTL.
  ///
  /// Example:
  /// ```dart
  /// final expirableSecret = "api-key".encryptWithTTL(
  ///   algorithm: 'aes-256-gcm',
  ///   ttl: Duration(hours: 24),
  /// );
  /// ```
  ExpirableSecret encryptWithTTL({
    required String algorithm,
    required Duration ttl,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final secret = encrypt(algorithm: algorithm, nonce: nonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableSecret(secret: secret, config: expiryConfig);
  }
}

/// Extension methods for `List<String>` to create expirable obfuscated values.
extension StringListExpiryExtensions on List<String> {
  /// Creates an expirable obfuscated string list with TTL.
  ExpirableObfuscatedStringList obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    final secret = Secret(data: encrypted, nonce: actualNonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.stringList(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }
}

/// Extension methods for int to create expirable obfuscated values.
extension IntExpiryExtensions on int {
  /// Creates an expirable obfuscated integer with TTL.
  ExpirableObfuscatedInt obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    final secret = Secret(data: encrypted, nonce: actualNonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.integer(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }
}

/// Extension methods for double to create expirable obfuscated values.
extension DoubleExpiryExtensions on double {
  /// Creates an expirable obfuscated double with TTL.
  ExpirableObfuscatedDouble obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    final secret = Secret(data: encrypted, nonce: actualNonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.doubleValue(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }
}

/// Extension methods for bool to create expirable obfuscated values.
extension BoolExpiryExtensions on bool {
  /// Creates an expirable obfuscated boolean with TTL.
  ExpirableObfuscatedBool obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    final secret = Secret(data: encrypted, nonce: actualNonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.boolean(
      secret: secret,
      algorithm: algorithm,
      secretName: secretName,
      expiryConfig: expiryConfig,
    );
  }
}

/// Extension methods for Map to create expirable obfuscated values.
extension MapExpiryExtensions on Map<String, dynamic> {
  /// Creates an expirable obfuscated generic value with TTL.
  ExpirableObfuscatedGeneric<Map<String, dynamic>> obfuscateWithTTL({
    required String algorithm,
    required Duration ttl,
    required String secretName,
    int? nonce,
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
    Duration gracePeriod = const Duration(minutes: 5),
  }) {
    final json = jsonEncode(this);
    final data = Uint8List.fromList(utf8.encode(json));
    final encryptionAlgorithm = EncryptionFactory.create(algorithm);
    final actualNonce = nonce ?? DateTime.now().millisecondsSinceEpoch;

    final encrypted = encryptionAlgorithm.obfuscate(data, actualNonce);
    final secret = Secret(data: encrypted, nonce: actualNonce);

    final expiryConfig = SecretExpiryConfig.withTTL(
      ttl,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
      gracePeriod: gracePeriod,
    );

    return ExpirableObfuscatedFactory.generic<Map<String, dynamic>>(
      secret: secret,
      secretName: secretName,
      expiryConfig: expiryConfig,
      deobfuscate: (data, nonce) {
        final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
        final json = utf8.decode(decrypted);
        return jsonDecode(json) as Map<String, dynamic>;
      },
    );
  }
}
