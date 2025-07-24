/// Riverpod integration for dart-confidential.
///
/// This module provides seamless integration with Riverpod,
/// allowing injection of obfuscated secrets via providers.
library;

import 'dart:async';

import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';

/// Riverpod-like interfaces to avoid hard dependency.
///
/// These allow the integration to work without requiring riverpod as a dependency.

/// Provider reference interface.
abstract class ProviderRefLike<T> {
  /// Watches another provider.
  U watch<U>(ProviderLike<U> provider);

  /// Reads another provider.
  U read<U>(ProviderLike<U> provider);

  /// Listens to another provider.
  void listen<U>(
    ProviderLike<U> provider,
    void Function(U? previous, U next) listener,
  );

  /// Invalidates this provider.
  void invalidateSelf();

  /// Called when the provider is disposed.
  void onDispose(void Function() callback);
}

/// Provider interface for Riverpod compatibility.
abstract class ProviderLike<T> {
  /// The provider family argument type.
  Type get argument;

  /// The provider return type.
  Type get returnType;
}

/// Async value interface for Riverpod compatibility.
abstract class AsyncValueLike<T> {
  /// Whether the async operation is loading.
  bool get isLoading;

  /// Whether the async operation has a value.
  bool get hasValue;

  /// Whether the async operation has an error.
  bool get hasError;

  /// The value if available.
  T? get value;

  /// The error if available.
  Object? get error;

  /// The stack trace if available.
  StackTrace? get stackTrace;

  /// Maps the value to another type.
  AsyncValueLike<U> map<U>(U Function(T) mapper);

  /// Handles the async value state.
  R when<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  });
}

/// Simple implementation of AsyncValue for our integration.
class _AsyncValue<T> implements AsyncValueLike<T> {
  final T? _value;
  final Object? _error;
  final StackTrace? _stackTrace;
  final bool _isLoading;

  const _AsyncValue.data(T value)
    : _value = value,
      _error = null,
      _stackTrace = null,
      _isLoading = false;

  const _AsyncValue.error(Object error, StackTrace stackTrace)
    : _value = null,
      _error = error,
      _stackTrace = stackTrace,
      _isLoading = false;

  const _AsyncValue.loading()
    : _value = null,
      _error = null,
      _stackTrace = null,
      _isLoading = true;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasValue => _value != null;

  @override
  bool get hasError => _error != null;

  @override
  T? get value => _value;

  @override
  Object? get error => _error;

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  AsyncValueLike<U> map<U>(U Function(T) mapper) {
    if (hasValue) {
      try {
        return _AsyncValue.data(mapper(_value as T));
      } catch (e, st) {
        return _AsyncValue.error(e, st);
      }
    } else if (hasError) {
      return _AsyncValue.error(_error!, _stackTrace!);
    } else {
      return const _AsyncValue.loading();
    }
  }

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    if (hasValue) {
      return data(_value as T);
    } else if (hasError) {
      return error(_error!, _stackTrace!);
    } else {
      return loading();
    }
  }
}

/// Provider for static obfuscated values.
class RiverpodObfuscatedValueProvider<T> implements ProviderLike<T> {
  final ObfuscatedValue<T> _obfuscatedValue;
  final String name;

  const RiverpodObfuscatedValueProvider(
    this._obfuscatedValue, {
    required this.name,
  });

  /// Gets the deobfuscated value.
  T call(ProviderRefLike<T> ref) {
    return _obfuscatedValue.value;
  }

  @override
  Type get argument => T;

  @override
  Type get returnType => T;

  /// Gets the obfuscated value (for advanced usage).
  ObfuscatedValue<T> get obfuscatedValue => _obfuscatedValue;
}

/// Provider for async obfuscated values.
class RiverpodAsyncObfuscatedValueProvider<T>
    implements ProviderLike<AsyncValueLike<T>> {
  final AsyncObfuscatedValue<T> _asyncObfuscatedValue;
  final String name;
  final Duration _refreshInterval;

  const RiverpodAsyncObfuscatedValueProvider(
    this._asyncObfuscatedValue, {
    required this.name,
    Duration refreshInterval = const Duration(minutes: 5),
  }) : _refreshInterval = refreshInterval;

  /// Gets the async value.
  Future<AsyncValueLike<T>> call(ProviderRefLike<AsyncValueLike<T>> ref) async {
    try {
      // Set up auto-refresh
      Timer.periodic(_refreshInterval, (_) {
        ref.invalidateSelf();
      });

      final value = await _asyncObfuscatedValue.value;
      return _AsyncValue.data(value);
    } catch (e, st) {
      return _AsyncValue.error(e, st);
    }
  }

  @override
  Type get argument => AsyncValueLike<T>;

  @override
  Type get returnType => AsyncValueLike<T>;

  /// Gets the async obfuscated value (for advanced usage).
  AsyncObfuscatedValue<T> get asyncObfuscatedValue => _asyncObfuscatedValue;
}

/// Family provider for parameterized obfuscated values.
class RiverpodObfuscatedValueFamilyProvider<T, Arg> implements ProviderLike<T> {
  final Map<Arg, ObfuscatedValue<T>> _values;
  final String name;

  const RiverpodObfuscatedValueFamilyProvider(
    this._values, {
    required this.name,
  });

  /// Gets the deobfuscated value for the given argument.
  T call(ProviderRefLike<T> ref, Arg arg) {
    final obfuscatedValue = _values[arg];
    if (obfuscatedValue == null) {
      throw ArgumentError('No obfuscated value found for argument: $arg');
    }
    return obfuscatedValue.value;
  }

  @override
  Type get argument => Arg;

  @override
  Type get returnType => T;

  /// Adds a value for the given argument.
  void addValue(Arg arg, ObfuscatedValue<T> value) {
    _values[arg] = value;
  }

  /// Removes a value for the given argument.
  void removeValue(Arg arg) {
    _values.remove(arg);
  }

  /// Gets all available arguments.
  Iterable<Arg> get arguments => _values.keys;
}

/// Provider for managing multiple secrets with Riverpod.
class RiverpodSecretManagerProvider
    implements ProviderLike<RiverpodSecretManager> {
  final String name;

  const RiverpodSecretManagerProvider({required this.name});

  RiverpodSecretManager call(ProviderRefLike<RiverpodSecretManager> ref) {
    final manager = RiverpodSecretManager();

    // Set up disposal
    ref.onDispose(() {
      manager.dispose();
    });

    return manager;
  }

  @override
  Type get argument => RiverpodSecretManager;

  @override
  Type get returnType => RiverpodSecretManager;
}

/// Secret manager for Riverpod integration.
class RiverpodSecretManager {
  final Map<String, RiverpodObfuscatedValueProvider> _staticProviders = {};
  final Map<String, RiverpodAsyncObfuscatedValueProvider> _asyncProviders = {};
  bool _disposed = false;

  /// Adds a static obfuscated value.
  void addStatic<T>(String name, ObfuscatedValue<T> obfuscatedValue) {
    if (_disposed) return;

    final provider = RiverpodObfuscatedValueProvider<T>(
      obfuscatedValue,
      name: name,
    );
    _staticProviders[name] = provider as RiverpodObfuscatedValueProvider;
  }

  /// Adds an async obfuscated value.
  void addAsync<T>(
    String name,
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    Duration refreshInterval = const Duration(minutes: 5),
  }) {
    if (_disposed) return;

    final provider = RiverpodAsyncObfuscatedValueProvider<T>(
      asyncObfuscatedValue,
      name: name,
      refreshInterval: refreshInterval,
    );
    _asyncProviders[name] = provider as RiverpodAsyncObfuscatedValueProvider;
  }

  /// Gets a static provider by name.
  RiverpodObfuscatedValueProvider<T>? getStatic<T>(String name) {
    return _staticProviders[name] as RiverpodObfuscatedValueProvider<T>?;
  }

  /// Gets an async provider by name.
  RiverpodAsyncObfuscatedValueProvider<T>? getAsync<T>(String name) {
    return _asyncProviders[name] as RiverpodAsyncObfuscatedValueProvider<T>?;
  }

  /// Removes a provider by name.
  void remove(String name) {
    if (_disposed) return;

    _staticProviders.remove(name);
    _asyncProviders.remove(name);
  }

  /// Gets all provider names.
  List<String> get providerNames => [
    ..._staticProviders.keys,
    ..._asyncProviders.keys,
  ];

  /// Gets the count of providers.
  int get providerCount => _staticProviders.length + _asyncProviders.length;

  /// Disposes of this manager.
  void dispose() {
    _disposed = true;
    _staticProviders.clear();
    _asyncProviders.clear();
  }

  /// Whether this manager is disposed.
  bool get isDisposed => _disposed;
}

/// Factory for creating Riverpod-compatible providers.
class ConfidentialRiverpodFactory {
  /// Creates a provider for a static obfuscated value.
  static RiverpodObfuscatedValueProvider<T> createStatic<T>(
    ObfuscatedValue<T> obfuscatedValue, {
    required String name,
  }) {
    return RiverpodObfuscatedValueProvider<T>(obfuscatedValue, name: name);
  }

  /// Creates a provider for an async obfuscated value.
  static RiverpodAsyncObfuscatedValueProvider<T> createAsync<T>(
    AsyncObfuscatedValue<T> asyncObfuscatedValue, {
    required String name,
    Duration refreshInterval = const Duration(minutes: 5),
  }) {
    return RiverpodAsyncObfuscatedValueProvider<T>(
      asyncObfuscatedValue,
      name: name,
      refreshInterval: refreshInterval,
    );
  }

  /// Creates a family provider for parameterized values.
  static RiverpodObfuscatedValueFamilyProvider<T, Arg> createFamily<T, Arg>({
    required String name,
    Map<Arg, ObfuscatedValue<T>>? initialValues,
  }) {
    return RiverpodObfuscatedValueFamilyProvider<T, Arg>(
      initialValues ?? {},
      name: name,
    );
  }

  /// Creates a secret manager provider.
  static RiverpodSecretManagerProvider createManager({required String name}) {
    return RiverpodSecretManagerProvider(name: name);
  }

  /// Creates providers from a secret provider.
  static Future<Map<String, RiverpodAsyncObfuscatedValueProvider>>
  createFromProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    Duration refreshInterval = const Duration(minutes: 5),
  }) async {
    final providers = <String, RiverpodAsyncObfuscatedValueProvider>{};

    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );

      providers[entry.key] = RiverpodAsyncObfuscatedValueProvider<String>(
        asyncSecret,
        name: entry.key,
        refreshInterval: refreshInterval,
      );
    }

    return providers;
  }
}

/// Extension methods for easier Riverpod integration.
extension RiverpodConfidentialExtension on ProviderRefLike {
  /// Watches an obfuscated value provider.
  T watchObfuscated<T>(RiverpodObfuscatedValueProvider<T> provider) {
    return watch(provider);
  }

  /// Watches an async obfuscated value provider.
  AsyncValueLike<T> watchAsyncObfuscated<T>(
    RiverpodAsyncObfuscatedValueProvider<T> provider,
  ) {
    return watch(provider);
  }

  /// Reads an obfuscated value provider.
  T readObfuscated<T>(RiverpodObfuscatedValueProvider<T> provider) {
    return read(provider);
  }

  /// Reads an async obfuscated value provider.
  AsyncValueLike<T> readAsyncObfuscated<T>(
    RiverpodAsyncObfuscatedValueProvider<T> provider,
  ) {
    return read(provider);
  }
}
