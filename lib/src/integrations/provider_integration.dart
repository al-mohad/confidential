/// Provider package integration for dart-confidential.
/// 
/// This module provides seamless integration with the Provider package,
/// allowing injection of obfuscated secrets via dependency injection.
library;

import 'dart:async';

import '../obfuscation/secret.dart';
import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';

/// Provider-like interface to avoid hard dependency.
/// 
/// This allows the integration to work without requiring provider as a dependency.
abstract class ProviderLike<T> {
  /// The current value.
  T get value;
  
  /// Whether this provider has listeners.
  bool get hasListeners;
  
  /// Adds a listener.
  void addListener(VoidCallback listener);
  
  /// Removes a listener.
  void removeListener(VoidCallback listener);
  
  /// Notifies listeners of changes.
  void notifyListeners();
  
  /// Disposes of this provider.
  void dispose();
}

/// Change notifier interface for Provider compatibility.
abstract class ChangeNotifierLike {
  /// Adds a listener.
  void addListener(VoidCallback listener);
  
  /// Removes a listener.
  void removeListener(VoidCallback listener);
  
  /// Notifies listeners of changes.
  void notifyListeners();
  
  /// Disposes of this notifier.
  void dispose();
}

/// Void callback type.
typedef VoidCallback = void Function();

/// Provider for obfuscated values that implements ChangeNotifier pattern.
class ObfuscatedValueProvider<T> implements ChangeNotifierLike {
  final ObfuscatedValue<T> _obfuscatedValue;
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  ObfuscatedValueProvider(this._obfuscatedValue);

  /// Gets the deobfuscated value.
  T get value => _obfuscatedValue.value;

  /// Gets the obfuscated value (for advanced usage).
  ObfuscatedValue<T> get obfuscatedValue => _obfuscatedValue;

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }

  /// Whether this provider has listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Whether this provider is disposed.
  bool get isDisposed => _disposed;
}

/// Provider for async obfuscated values with automatic updates.
class AsyncObfuscatedValueProvider<T> implements ChangeNotifierLike {
  final AsyncObfuscatedValue<T> _asyncObfuscatedValue;
  final List<VoidCallback> _listeners = [];
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

  /// Gets the async obfuscated value (for advanced usage).
  AsyncObfuscatedValue<T> get asyncObfuscatedValue => _asyncObfuscatedValue;

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
    notifyListeners();

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
        notifyListeners();
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

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _listeners.clear();
  }

  /// Whether this provider has listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Whether this provider is disposed.
  bool get isDisposed => _disposed;
}

/// Provider for managing multiple obfuscated secrets.
class SecretManagerProvider implements ChangeNotifierLike {
  final Map<String, ObfuscatedValueProvider> _staticProviders = {};
  final Map<String, AsyncObfuscatedValueProvider> _asyncProviders = {};
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  /// Adds a static obfuscated value provider.
  void addStatic<T>(String name, ObfuscatedValue<T> obfuscatedValue) {
    if (_disposed) return;
    
    final provider = ObfuscatedValueProvider<T>(obfuscatedValue);
    _staticProviders[name] = provider as ObfuscatedValueProvider;
    notifyListeners();
  }

  /// Adds an async obfuscated value provider.
  void addAsync<T>(
    String name, 
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    if (_disposed) return;
    
    final provider = AsyncObfuscatedValueProvider<T>(
      asyncObfuscatedValue,
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );
    _asyncProviders[name] = provider as AsyncObfuscatedValueProvider;
    notifyListeners();
  }

  /// Gets a static provider by name.
  ObfuscatedValueProvider<T>? getStatic<T>(String name) {
    return _staticProviders[name] as ObfuscatedValueProvider<T>?;
  }

  /// Gets an async provider by name.
  AsyncObfuscatedValueProvider<T>? getAsync<T>(String name) {
    return _asyncProviders[name] as AsyncObfuscatedValueProvider<T>?;
  }

  /// Gets a static value by name.
  T? getStaticValue<T>(String name) {
    return getStatic<T>(name)?.value;
  }

  /// Gets an async value by name (may be null if not loaded).
  T? getAsyncValue<T>(String name) {
    return getAsync<T>(name)?.value;
  }

  /// Gets an async value by name, waiting for it to load.
  Future<T?> getAsyncValueAsync<T>(String name) async {
    final provider = getAsync<T>(name);
    if (provider == null) return null;
    
    try {
      return await provider.getValueAsync();
    } catch (e) {
      return null;
    }
  }

  /// Removes a provider by name.
  void remove(String name) {
    if (_disposed) return;
    
    _staticProviders[name]?.dispose();
    _staticProviders.remove(name);
    
    _asyncProviders[name]?.dispose();
    _asyncProviders.remove(name);
    
    notifyListeners();
  }

  /// Refreshes all async providers.
  Future<void> refreshAll() async {
    final futures = _asyncProviders.values.map((provider) => provider.refresh());
    await Future.wait(futures);
  }

  /// Gets all provider names.
  List<String> get providerNames => [
    ..._staticProviders.keys,
    ..._asyncProviders.keys,
  ];

  /// Gets the count of providers.
  int get providerCount => _staticProviders.length + _asyncProviders.length;

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    
    for (final provider in _staticProviders.values) {
      provider.dispose();
    }
    _staticProviders.clear();
    
    for (final provider in _asyncProviders.values) {
      provider.dispose();
    }
    _asyncProviders.clear();
    
    _listeners.clear();
  }

  /// Whether this provider has listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Whether this provider is disposed.
  bool get isDisposed => _disposed;
}

/// Factory for creating Provider-compatible instances.
class ConfidentialProviderFactory {
  /// Creates a provider for a static obfuscated value.
  static ObfuscatedValueProvider<T> createStatic<T>(ObfuscatedValue<T> obfuscatedValue) {
    return ObfuscatedValueProvider<T>(obfuscatedValue);
  }

  /// Creates a provider for an async obfuscated value.
  static AsyncObfuscatedValueProvider<T> createAsync<T>(
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    return AsyncObfuscatedValueProvider<T>(
      asyncObfuscatedValue,
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );
  }

  /// Creates a secret manager provider.
  static SecretManagerProvider createManager() {
    return SecretManagerProvider();
  }

  /// Creates a secret manager with secrets from a provider.
  static Future<SecretManagerProvider> createManagerWithProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) async {
    final manager = SecretManagerProvider();

    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );
      
      manager.addAsync(
        entry.key,
        asyncSecret,
        refreshInterval: refreshInterval,
        autoRefresh: autoRefresh,
      );
    }

    return manager;
  }
}
