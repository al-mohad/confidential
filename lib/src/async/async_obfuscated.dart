/// Asynchronous obfuscated values and utilities.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../obfuscation/encryption/encryption.dart';
import 'secret_providers.dart';

/// Asynchronous version of ObfuscatedValue.
class AsyncObfuscatedValue<T> {
  final String secretName;
  final SecretProvider provider;
  final String algorithm;
  final T Function(Uint8List data, int nonce) deobfuscate;
  
  T? _cachedValue;
  DateTime? _cacheTime;
  final Duration _cacheExpiration;

  AsyncObfuscatedValue({
    required this.secretName,
    required this.provider,
    required this.algorithm,
    required this.deobfuscate,
    Duration cacheExpiration = const Duration(minutes: 5),
  }) : _cacheExpiration = cacheExpiration;

  /// Gets the deobfuscated value asynchronously.
  Future<T> get value async {
    // Check cache
    if (_cachedValue != null && 
        _cacheTime != null && 
        DateTime.now().difference(_cacheTime!).compareTo(_cacheExpiration) < 0) {
      return _cachedValue!;
    }

    // Load secret from provider
    final secret = await provider.loadSecret(secretName);
    if (secret == null) {
      throw Exception('Secret "$secretName" not found');
    }

    // Deobfuscate
    final value = deobfuscate(secret.data, secret.nonce);
    
    // Cache the result
    _cachedValue = value;
    _cacheTime = DateTime.now();
    
    return value;
  }

  /// Gets the value with a timeout.
  Future<T> getValueWithTimeout(Duration timeout) async {
    return await value.timeout(timeout);
  }

  /// Gets the value or returns a default if loading fails.
  Future<T> getValueOrDefault(T defaultValue) async {
    try {
      return await value;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Clears the cached value.
  void clearCache() {
    _cachedValue = null;
    _cacheTime = null;
  }

  /// Creates a stream that emits the value periodically.
  Stream<T> asStream({Duration interval = const Duration(seconds: 30)}) {
    return Stream.periodic(interval, (_) => value).asyncMap((future) => future);
  }

  /// Maps this async obfuscated value to another type.
  AsyncObfuscatedValue<U> map<U>(U Function(T) transform) {
    return AsyncObfuscatedValue<U>(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm,
      deobfuscate: (data, nonce) => transform(deobfuscate(data, nonce)),
      cacheExpiration: _cacheExpiration,
    );
  }
}

/// Asynchronous obfuscated string.
class AsyncObfuscatedString extends AsyncObfuscatedValue<String> {
  AsyncObfuscatedString({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    super.cacheExpiration,
  }) : super(
          deobfuscate: (data, nonce) {
            final encryptionAlgorithm = EncryptionFactory.create(algorithm);
            final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
            return utf8.decode(decrypted);
          },
        );
}

/// Asynchronous obfuscated string list.
class AsyncObfuscatedStringList extends AsyncObfuscatedValue<List<String>> {
  AsyncObfuscatedStringList({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    super.cacheExpiration,
  }) : super(
          deobfuscate: (data, nonce) {
            final encryptionAlgorithm = EncryptionFactory.create(algorithm);
            final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
            final json = utf8.decode(decrypted);
            return (jsonDecode(json) as List).cast<String>();
          },
        );
}

/// Asynchronous obfuscated integer.
class AsyncObfuscatedInt extends AsyncObfuscatedValue<int> {
  AsyncObfuscatedInt({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    super.cacheExpiration,
  }) : super(
          deobfuscate: (data, nonce) {
            final encryptionAlgorithm = EncryptionFactory.create(algorithm);
            final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
            final json = utf8.decode(decrypted);
            return jsonDecode(json) as int;
          },
        );
}

/// Asynchronous obfuscated boolean.
class AsyncObfuscatedBool extends AsyncObfuscatedValue<bool> {
  AsyncObfuscatedBool({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    super.cacheExpiration,
  }) : super(
          deobfuscate: (data, nonce) {
            final encryptionAlgorithm = EncryptionFactory.create(algorithm);
            final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
            final json = utf8.decode(decrypted);
            return jsonDecode(json) as bool;
          },
        );
}

/// Asynchronous obfuscated map.
class AsyncObfuscatedMap extends AsyncObfuscatedValue<Map<String, dynamic>> {
  AsyncObfuscatedMap({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    super.cacheExpiration,
  }) : super(
          deobfuscate: (data, nonce) {
            final encryptionAlgorithm = EncryptionFactory.create(algorithm);
            final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
            final json = utf8.decode(decrypted);
            return (jsonDecode(json) as Map).cast<String, dynamic>();
          },
        );
}

/// Factory for creating async obfuscated values.
class AsyncObfuscatedFactory {
  final SecretProvider provider;
  final String defaultAlgorithm;

  AsyncObfuscatedFactory({
    required this.provider,
    this.defaultAlgorithm = 'aes-256-gcm',
  });

  /// Creates an async obfuscated string.
  AsyncObfuscatedString string(
    String secretName, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedString(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async obfuscated string list.
  AsyncObfuscatedStringList stringList(
    String secretName, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedStringList(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async obfuscated integer.
  AsyncObfuscatedInt integer(
    String secretName, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedInt(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async obfuscated boolean.
  AsyncObfuscatedBool boolean(
    String secretName, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedBool(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async obfuscated map.
  AsyncObfuscatedMap map(
    String secretName, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedMap(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates a generic async obfuscated value.
  AsyncObfuscatedValue<T> value<T>(
    String secretName,
    T Function(Uint8List data, int nonce) deobfuscate, {
    String? algorithm,
    Duration? cacheExpiration,
  }) {
    return AsyncObfuscatedValue<T>(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      deobfuscate: deobfuscate,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }
}

/// Utility class for managing multiple async obfuscated values.
class AsyncSecretManager {
  final SecretProvider provider;
  final String defaultAlgorithm;
  final Map<String, AsyncObfuscatedValue> _secrets = {};

  AsyncSecretManager({
    required this.provider,
    this.defaultAlgorithm = 'aes-256-gcm',
  });

  /// Registers an async obfuscated value.
  void register<T>(String name, AsyncObfuscatedValue<T> secret) {
    _secrets[name] = secret;
  }

  /// Gets a registered async obfuscated value.
  AsyncObfuscatedValue<T>? get<T>(String name) {
    final secret = _secrets[name];
    return secret is AsyncObfuscatedValue<T> ? secret : null;
  }

  /// Preloads all registered secrets.
  Future<void> preloadAll() async {
    final futures = _secrets.values.map((secret) => secret.value);
    await Future.wait(futures);
  }

  /// Clears all caches.
  void clearAllCaches() {
    for (final secret in _secrets.values) {
      secret.clearCache();
    }
  }

  /// Gets the factory for creating new async obfuscated values.
  AsyncObfuscatedFactory get factory => AsyncObfuscatedFactory(
        provider: provider,
        defaultAlgorithm: defaultAlgorithm,
      );
}
