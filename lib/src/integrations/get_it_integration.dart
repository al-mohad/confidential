/// GetIt service locator integration for dart-confidential.
///
/// This module provides seamless integration with GetIt,
/// allowing registration and injection of obfuscated secrets.
library;

import 'dart:async';

import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';

/// GetIt-like interface to avoid hard dependency.
///
/// This allows the integration to work without requiring get_it as a dependency.
abstract class GetItLike {
  /// Registers a singleton instance.
  void registerSingleton<T>(T instance, {String? instanceName});

  /// Registers a lazy singleton factory.
  void registerLazySingleton<T>(
    T Function() factoryFunc, {
    String? instanceName,
    void Function(T)? dispose,
  });

  /// Registers a factory.
  void registerFactory<T>(T Function() factoryFunc, {String? instanceName});

  /// Gets an instance.
  T get<T>({String? instanceName});

  /// Checks if a type is registered.
  bool isRegistered<T>({String? instanceName});

  /// Unregisters a type.
  Future<void> unregister<T>({String? instanceName});

  /// Resets all registrations.
  Future<void> reset();
}

/// Configuration for GetIt integration.
class GetItIntegrationConfig {
  /// Whether to register secrets as singletons.
  final bool useSingletons;

  /// Whether to register async secrets as lazy singletons.
  final bool useLazySingletons;

  /// Prefix for secret instance names.
  final String instanceNamePrefix;

  /// Whether to enable automatic disposal.
  final bool enableDisposal;

  const GetItIntegrationConfig({
    this.useSingletons = true,
    this.useLazySingletons = true,
    this.instanceNamePrefix = 'confidential_',
    this.enableDisposal = true,
  });
}

/// Service for managing obfuscated secrets in GetIt.
class ConfidentialGetItService {
  final GetItLike _getIt;
  final GetItIntegrationConfig _config;
  final Map<String, String> _registeredSecrets = {};
  final Map<String, AsyncObfuscatedValueProvider> _asyncProviders = {};

  ConfidentialGetItService(
    this._getIt, {
    GetItIntegrationConfig config = const GetItIntegrationConfig(),
  }) : _config = config;

  /// Registers a static obfuscated value.
  void registerStatic<T>(
    String name,
    ObfuscatedValue<T> obfuscatedValue, {
    String? instanceName,
  }) {
    final actualInstanceName =
        instanceName ?? '${_config.instanceNamePrefix}$name';

    if (_config.useSingletons) {
      _getIt.registerSingleton<T>(
        obfuscatedValue.value,
        instanceName: actualInstanceName,
      );
    } else {
      _getIt.registerFactory<T>(
        () => obfuscatedValue.value,
        instanceName: actualInstanceName,
      );
    }

    _registeredSecrets[name] = actualInstanceName;
  }

  /// Registers an async obfuscated value.
  void registerAsync<T>(
    String name,
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    String? instanceName,
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    final actualInstanceName =
        instanceName ?? '${_config.instanceNamePrefix}$name';

    final provider = AsyncObfuscatedValueProvider<T>(
      asyncObfuscatedValue,
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );

    _asyncProviders[name] = provider as AsyncObfuscatedValueProvider;

    if (_config.useLazySingletons) {
      _getIt.registerLazySingleton<AsyncObfuscatedValueProvider<T>>(
        () => provider,
        instanceName: actualInstanceName,
        dispose: _config.enableDisposal ? (p) => p.dispose() : null,
      );
    } else {
      _getIt.registerFactory<AsyncObfuscatedValueProvider<T>>(
        () => provider,
        instanceName: actualInstanceName,
      );
    }

    _registeredSecrets[name] = actualInstanceName;
  }

  /// Registers multiple secrets from a provider.
  Future<void> registerFromProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) async {
    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );

      registerAsync<String>(
        entry.key,
        asyncSecret,
        refreshInterval: refreshInterval,
        autoRefresh: autoRefresh,
      );
    }
  }

  /// Gets a static secret value.
  T getStatic<T>(String name) {
    final instanceName = _registeredSecrets[name];
    if (instanceName == null) {
      throw ArgumentError('Secret "$name" is not registered');
    }

    return _getIt.get<T>(instanceName: instanceName);
  }

  /// Gets an async secret provider.
  AsyncObfuscatedValueProvider<T> getAsyncProvider<T>(String name) {
    final instanceName = _registeredSecrets[name];
    if (instanceName == null) {
      throw ArgumentError('Secret "$name" is not registered');
    }

    return _getIt.get<AsyncObfuscatedValueProvider<T>>(
      instanceName: instanceName,
    );
  }

  /// Gets an async secret value (may be null if not loaded).
  T? getAsync<T>(String name) {
    final provider = getAsyncProvider<T>(name);
    return provider.value;
  }

  /// Gets an async secret value, waiting for it to load.
  Future<T> getAsyncValue<T>(String name) async {
    final provider = getAsyncProvider<T>(name);
    return await provider.getValueAsync();
  }

  /// Gets an async secret value with a fallback.
  T getAsyncOrDefault<T>(String name, T defaultValue) {
    final provider = getAsyncProvider<T>(name);
    return provider.getValueOrDefault(defaultValue);
  }

  /// Checks if a secret is registered.
  bool isRegistered(String name) {
    final instanceName = _registeredSecrets[name];
    if (instanceName == null) return false;

    return _getIt.isRegistered<dynamic>(instanceName: instanceName);
  }

  /// Unregisters a secret.
  Future<void> unregister(String name) async {
    final instanceName = _registeredSecrets[name];
    if (instanceName == null) return;

    // Dispose async provider if it exists
    final asyncProvider = _asyncProviders[name];
    if (asyncProvider != null) {
      asyncProvider.dispose();
      _asyncProviders.remove(name);
    }

    await _getIt.unregister<dynamic>(instanceName: instanceName);
    _registeredSecrets.remove(name);
  }

  /// Refreshes all async secrets.
  Future<void> refreshAll() async {
    final futures = _asyncProviders.values.map(
      (provider) => provider.refresh(),
    );
    await Future.wait(futures);
  }

  /// Gets all registered secret names.
  List<String> get registeredNames => _registeredSecrets.keys.toList();

  /// Gets the count of registered secrets.
  int get registeredCount => _registeredSecrets.length;

  /// Disposes of all async providers.
  void dispose() {
    for (final provider in _asyncProviders.values) {
      provider.dispose();
    }
    _asyncProviders.clear();
  }
}

/// Async provider wrapper for GetIt integration.
class AsyncObfuscatedValueProvider<T> {
  final AsyncObfuscatedValue<T> _asyncObfuscatedValue;
  final Duration _refreshInterval;

  T? _cachedValue;
  bool _isLoading = false;
  Object? _error;
  Timer? _refreshTimer;
  bool _disposed = false;

  AsyncObfuscatedValueProvider(
    this._asyncObfuscatedValue, {
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) : _refreshInterval = refreshInterval {
    if (autoRefresh) {
      _startAutoRefresh();
    }
    _loadValue(); // Initial load
  }

  /// Gets the current value (may be null if still loading).
  T? get value => _cachedValue;

  /// Whether the value is currently being loaded.
  bool get isLoading => _isLoading;

  /// The last error that occurred during loading.
  Object? get error => _error;

  /// Whether the value has been loaded successfully.
  bool get hasValue => _cachedValue != null;

  /// Manually refreshes the value.
  Future<void> refresh() async {
    await _loadValue();
  }

  /// Gets the value with a fallback if not loaded.
  T getValueOrDefault(T defaultValue) {
    return _cachedValue ?? defaultValue;
  }

  /// Gets the value asynchronously, waiting for it to load if necessary.
  Future<T> getValueAsync() async {
    if (_cachedValue != null) {
      return _cachedValue!;
    }

    if (!_isLoading) {
      await _loadValue();
    }

    // Wait for loading to complete
    while (_isLoading && !_disposed) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_cachedValue != null) {
      return _cachedValue!;
    }

    throw _error ?? Exception('Failed to load value');
  }

  Future<void> _loadValue() async {
    if (_disposed) return;

    _isLoading = true;
    _error = null;

    try {
      final value = await _asyncObfuscatedValue.value;
      if (!_disposed) {
        _cachedValue = value;
        _error = null;
      }
    } catch (e) {
      if (!_disposed) {
        _error = e;
      }
    } finally {
      if (!_disposed) {
        _isLoading = false;
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_disposed) {
        _asyncObfuscatedValue.clearCache();
        _loadValue();
      }
    });
  }

  /// Disposes of this provider.
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
  }

  /// Whether this provider is disposed.
  bool get isDisposed => _disposed;
}

/// Extension methods for easier GetIt integration.
extension GetItConfidentialExtension on GetItLike {
  /// Adds confidential secret management to this GetIt instance.
  ConfidentialGetItService addConfidentialSecrets({
    GetItIntegrationConfig config = const GetItIntegrationConfig(),
  }) {
    final service = ConfidentialGetItService(this, config: config);

    // Register the service itself
    registerSingleton<ConfidentialGetItService>(service);

    return service;
  }

  /// Gets the confidential service.
  ConfidentialGetItService get confidential {
    return get<ConfidentialGetItService>();
  }

  /// Registers a static obfuscated value directly.
  void registerObfuscated<T>(
    String name,
    ObfuscatedValue<T> obfuscatedValue, {
    String? instanceName,
  }) {
    final service = get<ConfidentialGetItService>();
    service.registerStatic<T>(
      name,
      obfuscatedValue,
      instanceName: instanceName,
    );
  }

  /// Registers an async obfuscated value directly.
  void registerAsyncObfuscated<T>(
    String name,
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    String? instanceName,
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    final service = get<ConfidentialGetItService>();
    service.registerAsync<T>(
      name,
      asyncObfuscatedValue,
      instanceName: instanceName,
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );
  }

  /// Gets a static obfuscated value directly.
  T getObfuscated<T>(String name) {
    final service = get<ConfidentialGetItService>();
    return service.getStatic<T>(name);
  }

  /// Gets an async obfuscated value directly.
  Future<T> getAsyncObfuscated<T>(String name) async {
    final service = get<ConfidentialGetItService>();
    return await service.getAsyncValue<T>(name);
  }
}

/// Factory for creating GetIt-compatible instances.
class ConfidentialGetItFactory {
  /// Creates a confidential service for the given GetIt instance.
  static ConfidentialGetItService createService(
    GetItLike getIt, {
    GetItIntegrationConfig config = const GetItIntegrationConfig(),
  }) {
    return ConfidentialGetItService(getIt, config: config);
  }

  /// Sets up a GetIt instance with confidential secrets from a provider.
  static Future<ConfidentialGetItService> setupWithProvider({
    required GetItLike getIt,
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    GetItIntegrationConfig config = const GetItIntegrationConfig(),
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) async {
    final service = ConfidentialGetItService(getIt, config: config);

    await service.registerFromProvider(
      secretProvider: secretProvider,
      secretNames: secretNames,
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );

    getIt.registerSingleton<ConfidentialGetItService>(service);

    return service;
  }
}
