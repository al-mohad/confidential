/// Asynchronous expirable obfuscated values with rotation support.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../obfuscation/encryption/encryption.dart';
import 'expirable_obfuscated.dart';
import 'expirable_secret.dart';
import 'expiry_aware_providers.dart';

/// Asynchronous version of ExpirableObfuscatedValue.
class AsyncExpirableObfuscatedValue<T> {
  final String secretName;
  final ExpiryAwareSecretProvider provider;
  final String algorithm;
  final T Function(Uint8List data, int nonce) deobfuscate;
  final SecretExpiryConfig expiryConfig;

  ExpirableObfuscatedValue<T>? _cachedValue;
  DateTime? _cacheTime;
  final Duration _cacheExpiration;

  /// Stream controller for expiry events.
  final StreamController<SecretExpiryEvent> _eventController =
      StreamController<SecretExpiryEvent>.broadcast();

  AsyncExpirableObfuscatedValue({
    required this.secretName,
    required this.provider,
    required this.algorithm,
    required this.deobfuscate,
    required this.expiryConfig,
    Duration cacheExpiration = const Duration(minutes: 5),
  }) : _cacheExpiration = cacheExpiration;

  /// Stream of expiry events for this secret.
  Stream<SecretExpiryEvent> get expiryEvents => _eventController.stream;

  /// Gets the current value, loading asynchronously if needed.
  Future<T> get value async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.value;
  }

  /// Gets the current expiry status.
  Future<SecretExpiryStatus> get expiryStatus async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.expiryStatus;
  }

  /// Gets the expiry time.
  Future<DateTime?> get expiresAt async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.expiresAt;
  }

  /// Gets time until expiry.
  Future<Duration?> get timeUntilExpiry async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.timeUntilExpiry;
  }

  /// Checks if the secret is expired.
  Future<bool> get isExpired async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.isExpired;
  }

  /// Checks if the secret is near expiry.
  Future<bool> get isNearExpiry async {
    final expirableValue = await _getExpirableValue();
    return expirableValue.isNearExpiry;
  }

  /// Manually triggers a refresh.
  Future<bool> refresh() async {
    try {
      _cachedValue = null; // Clear cache
      final expirableValue = await _getExpirableValue();
      return await expirableValue.refresh();
    } catch (e) {
      _emitEvent(
        SecretExpiryEvent(
          secretName: secretName,
          type: SecretExpiryEventType.refreshFailed,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  /// Sets a custom refresh callback.
  Future<void> setRefreshCallback(SecretRefreshCallback callback) async {
    final expirableValue = await _getExpirableValue();
    expirableValue.setRefreshCallback(callback);
  }

  /// Sets an expiry callback.
  Future<void> setExpiryCallback(SecretExpiryCallback callback) async {
    final expirableValue = await _getExpirableValue();
    expirableValue.setExpiryCallback(callback);
  }

  /// Gets or loads the expirable value.
  Future<ExpirableObfuscatedValue<T>> _getExpirableValue() async {
    // Check cache first
    if (_cachedValue != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age < _cacheExpiration && !_cachedValue!.isExpired) {
        return _cachedValue!;
      }
    }

    // Load from provider
    final secretWithMetadata = await provider.loadSecretWithMetadata(
      secretName,
    );
    if (secretWithMetadata == null) {
      throw Exception('Secret $secretName not found');
    }

    // Create expirable secret with metadata expiry info
    final expirableSecret = ExpirableSecret(
      secret: secretWithMetadata.secret,
      config: _mergeExpiryConfigs(expiryConfig, secretWithMetadata.metadata),
    );

    // Create expirable obfuscated value
    final expirableValue = _createExpirableObfuscatedValue(expirableSecret);

    // Set up callbacks
    expirableValue.setRefreshCallback(_createRefreshCallback());
    expirableValue.setExpiryCallback(_createExpiryCallback());

    // Cache the result
    _cachedValue = expirableValue;
    _cacheTime = DateTime.now();

    return expirableValue;
  }

  /// Creates the appropriate expirable obfuscated value type.
  ExpirableObfuscatedValue<T> _createExpirableObfuscatedValue(
    ExpirableSecret expirableSecret,
  ) {
    // This is a simplified version - in practice, you'd need to determine
    // the correct type based on T and create the appropriate subclass
    return ExpirableObfuscatedGeneric<T>(
      expirableSecret: expirableSecret,
      deobfuscate: deobfuscate,
      secretName: secretName,
    );
  }

  /// Merges expiry configurations from constructor and metadata.
  SecretExpiryConfig _mergeExpiryConfigs(
    SecretExpiryConfig config,
    SecretMetadata metadata,
  ) {
    return SecretExpiryConfig(
      ttl: config.ttl ?? metadata.ttl,
      expiresAt: config.expiresAt ?? metadata.expiresAt,
      gracePeriod: config.gracePeriod,
      autoRefresh: config.autoRefresh,
      refreshThreshold: config.refreshThreshold,
      maxRefreshAttempts: config.maxRefreshAttempts,
      refreshRetryDelay: config.refreshRetryDelay,
    );
  }

  /// Creates a refresh callback that reloads from the provider.
  SecretRefreshCallback _createRefreshCallback() {
    return (secretName, expirableSecret) async {
      try {
        _emitEvent(
          SecretExpiryEvent(
            secretName: secretName,
            type: SecretExpiryEventType.refreshStarted,
          ),
        );

        final secretWithMetadata = await provider.loadSecretWithMetadata(
          secretName,
        );
        if (secretWithMetadata != null) {
          _emitEvent(
            SecretExpiryEvent(
              secretName: secretName,
              type: SecretExpiryEventType.refreshCompleted,
            ),
          );
          return secretWithMetadata.secret;
        } else {
          _emitEvent(
            SecretExpiryEvent(
              secretName: secretName,
              type: SecretExpiryEventType.refreshFailed,
              error: 'Provider returned null',
            ),
          );
          return null;
        }
      } catch (e) {
        _emitEvent(
          SecretExpiryEvent(
            secretName: secretName,
            type: SecretExpiryEventType.refreshFailed,
            error: e.toString(),
          ),
        );
        return null;
      }
    };
  }

  /// Creates an expiry callback that emits events.
  SecretExpiryCallback _createExpiryCallback() {
    return (secretName, expirableSecret) async {
      _emitEvent(
        SecretExpiryEvent(
          secretName: secretName,
          type: expirableSecret.isHardExpired
              ? SecretExpiryEventType.secretExpired
              : SecretExpiryEventType.secretNearExpiry,
        ),
      );
    };
  }

  /// Emits an expiry event.
  void _emitEvent(SecretExpiryEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Maps this async expirable value to another type.
  AsyncExpirableObfuscatedValue<U> map<U>(U Function(T) transform) {
    return AsyncExpirableObfuscatedValue<U>(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm,
      expiryConfig: expiryConfig,
      deobfuscate: (data, nonce) => transform(deobfuscate(data, nonce)),
      cacheExpiration: _cacheExpiration,
    );
  }

  /// Disposes resources.
  void dispose() {
    _cachedValue?.dispose();
    _eventController.close();
  }
}

/// Event emitted when a secret expiry-related action occurs.
class SecretExpiryEvent {
  /// The name of the secret.
  final String secretName;

  /// The type of expiry event.
  final SecretExpiryEventType type;

  /// Error message if applicable.
  final String? error;

  /// When the event occurred.
  final DateTime timestamp;

  SecretExpiryEvent({
    required this.secretName,
    required this.type,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Types of secret expiry events.
enum SecretExpiryEventType {
  /// Secret refresh started.
  refreshStarted,

  /// Secret refresh completed successfully.
  refreshCompleted,

  /// Secret refresh failed.
  refreshFailed,

  /// Secret expired.
  secretExpired,

  /// Secret is near expiry.
  secretNearExpiry,
}

/// Asynchronous expirable obfuscated string.
class AsyncExpirableObfuscatedString
    extends AsyncExpirableObfuscatedValue<String> {
  AsyncExpirableObfuscatedString({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    required super.expiryConfig,
    super.cacheExpiration,
  }) : super(
         deobfuscate: (data, nonce) {
           final encryptionAlgorithm = EncryptionFactory.create(algorithm);
           final decrypted = encryptionAlgorithm.deobfuscate(data, nonce);
           return utf8.decode(decrypted);
         },
       );
}

/// Asynchronous expirable obfuscated string list.
class AsyncExpirableObfuscatedStringList
    extends AsyncExpirableObfuscatedValue<List<String>> {
  AsyncExpirableObfuscatedStringList({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    required super.expiryConfig,
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

/// Asynchronous expirable obfuscated integer.
class AsyncExpirableObfuscatedInt extends AsyncExpirableObfuscatedValue<int> {
  AsyncExpirableObfuscatedInt({
    required super.secretName,
    required super.provider,
    required super.algorithm,
    required super.expiryConfig,
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

/// Factory for creating async expirable obfuscated values.
class AsyncExpirableObfuscatedFactory {
  final ExpiryAwareSecretProvider provider;
  final String defaultAlgorithm;
  final SecretExpiryConfig defaultExpiryConfig;

  AsyncExpirableObfuscatedFactory({
    required this.provider,
    this.defaultAlgorithm = 'aes-256-gcm',
    SecretExpiryConfig? defaultExpiryConfig,
  }) : defaultExpiryConfig =
           defaultExpiryConfig ??
           const SecretExpiryConfig(
             ttl: Duration(hours: 24),
             autoRefresh: true,
           );

  /// Creates an async expirable obfuscated string.
  AsyncExpirableObfuscatedString string(
    String secretName, {
    String? algorithm,
    SecretExpiryConfig? expiryConfig,
    Duration? cacheExpiration,
  }) {
    return AsyncExpirableObfuscatedString(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      expiryConfig: expiryConfig ?? defaultExpiryConfig,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async expirable obfuscated string list.
  AsyncExpirableObfuscatedStringList stringList(
    String secretName, {
    String? algorithm,
    SecretExpiryConfig? expiryConfig,
    Duration? cacheExpiration,
  }) {
    return AsyncExpirableObfuscatedStringList(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      expiryConfig: expiryConfig ?? defaultExpiryConfig,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }

  /// Creates an async expirable obfuscated integer.
  AsyncExpirableObfuscatedInt integer(
    String secretName, {
    String? algorithm,
    SecretExpiryConfig? expiryConfig,
    Duration? cacheExpiration,
  }) {
    return AsyncExpirableObfuscatedInt(
      secretName: secretName,
      provider: provider,
      algorithm: algorithm ?? defaultAlgorithm,
      expiryConfig: expiryConfig ?? defaultExpiryConfig,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 5),
    );
  }
}
