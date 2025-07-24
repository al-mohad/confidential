/// BLoC pattern integration for dart-confidential.
///
/// This module provides seamless integration with BLoC/Cubit,
/// allowing injection of obfuscated secrets into BLoCs and Cubits.
library;

import 'dart:async';

import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';

/// BLoC-like interfaces to avoid hard dependency.
///
/// These allow the integration to work without requiring bloc as a dependency.

/// Stream interface for BLoC compatibility.
abstract class StreamLike<T> {
  /// Listens to the stream.
  StreamSubscription<T> listen(
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  });

  /// Maps the stream to another type.
  StreamLike<R> map<R>(R Function(T) mapper);

  /// Filters the stream.
  StreamLike<T> where(bool Function(T) test);

  /// Gets the first value.
  Future<T> get first;

  /// Gets the last value.
  Future<T> get last;
}

/// Sink interface for BLoC compatibility.
abstract class SinkLike<T> {
  /// Adds data to the sink.
  void add(T data);

  /// Adds an error to the sink.
  void addError(Object error, [StackTrace? stackTrace]);

  /// Closes the sink.
  Future<void> close();
}

/// BLoC base interface.
abstract class BlocBaseLike<State> {
  /// The current state.
  State get state;

  /// Stream of state changes.
  StreamLike<State> get stream;

  /// Whether the BLoC is closed.
  bool get isClosed;

  /// Closes the BLoC.
  Future<void> close();
}

/// Cubit interface for BLoC compatibility.
abstract class CubitLike<State> implements BlocBaseLike<State> {
  /// Emits a new state.
  void emit(State state);
}

/// Events and states for secret management.
abstract class SecretEvent {}

class LoadSecretEvent extends SecretEvent {
  final String secretName;
  LoadSecretEvent(this.secretName);
}

class RefreshSecretEvent extends SecretEvent {
  final String secretName;
  RefreshSecretEvent(this.secretName);
}

class RefreshAllSecretsEvent extends SecretEvent {}

abstract class SecretState {}

class SecretInitialState extends SecretState {}

class SecretLoadingState extends SecretState {
  final String secretName;
  SecretLoadingState(this.secretName);
}

class SecretLoadedState<T> extends SecretState {
  final String secretName;
  final T value;
  SecretLoadedState(this.secretName, this.value);
}

class SecretErrorState extends SecretState {
  final String secretName;
  final Object error;
  final StackTrace? stackTrace;
  SecretErrorState(this.secretName, this.error, [this.stackTrace]);
}

class MultipleSecretsLoadedState extends SecretState {
  final Map<String, dynamic> secrets;
  MultipleSecretsLoadedState(this.secrets);
}

/// BLoC for managing obfuscated secrets.
class SecretBloc implements BlocBaseLike<SecretState> {
  final Map<String, ObfuscatedValue> _staticSecrets = {};
  final Map<String, AsyncObfuscatedValue> _asyncSecrets = {};
  final Map<String, dynamic> _loadedValues = {};

  final StreamController<SecretEvent> _eventController =
      StreamController<SecretEvent>();
  final StreamController<SecretState> _stateController =
      StreamController<SecretState>.broadcast();

  SecretState _currentState = SecretInitialState();
  bool _isClosed = false;

  SecretBloc() {
    _eventController.stream.listen(_handleEvent);
  }

  @override
  SecretState get state => _currentState;

  @override
  StreamLike<SecretState> get stream => _BlocStream(_stateController.stream);

  @override
  bool get isClosed => _isClosed;

  /// Adds an event to the BLoC.
  void add(SecretEvent event) {
    if (!_isClosed) {
      _eventController.add(event);
    }
  }

  /// Adds a static obfuscated secret.
  void addStaticSecret<T>(String name, ObfuscatedValue<T> secret) {
    _staticSecrets[name] = secret;
    _loadedValues[name] = secret.value;
    _emitState(SecretLoadedState<T>(name, secret.value));
  }

  /// Adds an async obfuscated secret.
  void addAsyncSecret<T>(String name, AsyncObfuscatedValue<T> secret) {
    _asyncSecrets[name] = secret;
  }

  /// Gets a loaded secret value.
  T? getSecret<T>(String name) {
    return _loadedValues[name] as T?;
  }

  /// Gets a loaded secret value with a fallback.
  T getSecretOrDefault<T>(String name, T defaultValue) {
    return _loadedValues[name] as T? ?? defaultValue;
  }

  /// Checks if a secret is loaded.
  bool isSecretLoaded(String name) {
    return _loadedValues.containsKey(name);
  }

  /// Gets all loaded secret names.
  List<String> get loadedSecretNames => _loadedValues.keys.toList();

  /// Gets the count of loaded secrets.
  int get loadedSecretCount => _loadedValues.length;

  Future<void> _handleEvent(SecretEvent event) async {
    if (_isClosed) return;

    try {
      if (event is LoadSecretEvent) {
        await _handleLoadSecret(event);
      } else if (event is RefreshSecretEvent) {
        await _handleRefreshSecret(event);
      } else if (event is RefreshAllSecretsEvent) {
        await _handleRefreshAllSecrets();
      }
    } catch (e, st) {
      if (event is LoadSecretEvent) {
        _emitState(SecretErrorState(event.secretName, e, st));
      } else if (event is RefreshSecretEvent) {
        _emitState(SecretErrorState(event.secretName, e, st));
      } else {
        _emitState(SecretErrorState('unknown', e, st));
      }
    }
  }

  Future<void> _handleLoadSecret(LoadSecretEvent event) async {
    final secretName = event.secretName;

    // Check if it's a static secret
    final staticSecret = _staticSecrets[secretName];
    if (staticSecret != null) {
      final value = staticSecret.value;
      _loadedValues[secretName] = value;
      _emitState(SecretLoadedState(secretName, value));
      return;
    }

    // Check if it's an async secret
    final asyncSecret = _asyncSecrets[secretName];
    if (asyncSecret != null) {
      _emitState(SecretLoadingState(secretName));

      final value = await asyncSecret.value;
      _loadedValues[secretName] = value;
      _emitState(SecretLoadedState(secretName, value));
      return;
    }

    throw ArgumentError('Secret "$secretName" not found');
  }

  Future<void> _handleRefreshSecret(RefreshSecretEvent event) async {
    final secretName = event.secretName;

    // Only async secrets can be refreshed
    final asyncSecret = _asyncSecrets[secretName];
    if (asyncSecret != null) {
      _emitState(SecretLoadingState(secretName));

      asyncSecret.clearCache();
      final value = await asyncSecret.value;
      _loadedValues[secretName] = value;
      _emitState(SecretLoadedState(secretName, value));
    } else {
      throw ArgumentError(
        'Secret "$secretName" is not an async secret or not found',
      );
    }
  }

  Future<void> _handleRefreshAllSecrets() async {
    final futures = <Future>[];

    for (final entry in _asyncSecrets.entries) {
      futures.add(_refreshAsyncSecret(entry.key, entry.value));
    }

    await Future.wait(futures);
    _emitState(MultipleSecretsLoadedState(Map.from(_loadedValues)));
  }

  Future<void> _refreshAsyncSecret(
    String name,
    AsyncObfuscatedValue secret,
  ) async {
    try {
      secret.clearCache();
      final value = await secret.value;
      _loadedValues[name] = value;
    } catch (e) {
      // Individual secret errors are handled separately
      rethrow;
    }
  }

  void _emitState(SecretState newState) {
    if (!_isClosed) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  @override
  Future<void> close() async {
    if (!_isClosed) {
      _isClosed = true;
      await _eventController.close();
      await _stateController.close();
    }
  }
}

/// Cubit for managing a single obfuscated secret.
class SecretCubit<T> implements CubitLike<SecretState> {
  final String secretName;
  final AsyncObfuscatedValue<T>? _asyncSecret;
  final ObfuscatedValue<T>? _staticSecret;

  final StreamController<SecretState> _stateController =
      StreamController<SecretState>.broadcast();
  SecretState _currentState = SecretInitialState();
  bool _isClosed = false;

  SecretCubit.static(this.secretName, ObfuscatedValue<T> secret)
    : _staticSecret = secret,
      _asyncSecret = null {
    _loadStaticSecret();
  }

  SecretCubit.async(this.secretName, AsyncObfuscatedValue<T> secret)
    : _asyncSecret = secret,
      _staticSecret = null {
    _loadAsyncSecret();
  }

  @override
  SecretState get state => _currentState;

  @override
  StreamLike<SecretState> get stream => _BlocStream(_stateController.stream);

  @override
  bool get isClosed => _isClosed;

  /// Gets the current secret value if loaded.
  T? get value {
    if (_currentState is SecretLoadedState<T>) {
      return (_currentState as SecretLoadedState<T>).value;
    }
    return null;
  }

  /// Gets the current secret value with a fallback.
  T getValueOrDefault(T defaultValue) {
    return value ?? defaultValue;
  }

  /// Whether the secret is currently loaded.
  bool get isLoaded => _currentState is SecretLoadedState<T>;

  /// Whether the secret is currently loading.
  bool get isLoading => _currentState is SecretLoadingState;

  /// Whether there was an error loading the secret.
  bool get hasError => _currentState is SecretErrorState;

  /// The error if there was one.
  Object? get error {
    if (_currentState is SecretErrorState) {
      return (_currentState as SecretErrorState).error;
    }
    return null;
  }

  /// Refreshes the secret (only for async secrets).
  Future<void> refresh() async {
    if (_asyncSecret != null) {
      await _loadAsyncSecret();
    }
  }

  @override
  void emit(SecretState state) {
    if (!_isClosed) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  void _loadStaticSecret() {
    try {
      final value = _staticSecret!.value;
      emit(SecretLoadedState<T>(secretName, value));
    } catch (e, st) {
      emit(SecretErrorState(secretName, e, st));
    }
  }

  Future<void> _loadAsyncSecret() async {
    emit(SecretLoadingState(secretName));

    try {
      _asyncSecret?.clearCache();
      final value = await _asyncSecret!.value;
      emit(SecretLoadedState<T>(secretName, value));
    } catch (e, st) {
      emit(SecretErrorState(secretName, e, st));
    }
  }

  @override
  Future<void> close() async {
    if (!_isClosed) {
      _isClosed = true;
      await _stateController.close();
    }
  }
}

/// Stream wrapper for BLoC compatibility.
class _BlocStream<T> implements StreamLike<T> {
  final Stream<T> _stream;

  _BlocStream(this._stream);

  @override
  StreamSubscription<T> listen(
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  StreamLike<R> map<R>(R Function(T) mapper) {
    return _BlocStream(_stream.map(mapper));
  }

  @override
  StreamLike<T> where(bool Function(T) test) {
    return _BlocStream(_stream.where(test));
  }

  @override
  Future<T> get first => _stream.first;

  @override
  Future<T> get last => _stream.last;
}

/// Factory for creating BLoC-compatible instances.
class ConfidentialBlocFactory {
  /// Creates a SecretBloc with pre-configured secrets.
  static SecretBloc createBloc({
    Map<String, ObfuscatedValue>? staticSecrets,
    Map<String, AsyncObfuscatedValue>? asyncSecrets,
  }) {
    final bloc = SecretBloc();

    if (staticSecrets != null) {
      for (final entry in staticSecrets.entries) {
        bloc.addStaticSecret(entry.key, entry.value);
      }
    }

    if (asyncSecrets != null) {
      for (final entry in asyncSecrets.entries) {
        bloc.addAsyncSecret(entry.key, entry.value);
      }
    }

    return bloc;
  }

  /// Creates a SecretCubit for a static secret.
  static SecretCubit<T> createStaticCubit<T>(
    String name,
    ObfuscatedValue<T> secret,
  ) {
    return SecretCubit.static(name, secret);
  }

  /// Creates a SecretCubit for an async secret.
  static SecretCubit<T> createAsyncCubit<T>(
    String name,
    AsyncObfuscatedValue<T> secret,
  ) {
    return SecretCubit.async(name, secret);
  }

  /// Creates a SecretBloc with secrets from a provider.
  static Future<SecretBloc> createBlocWithProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
  }) async {
    final bloc = SecretBloc();

    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );

      bloc.addAsyncSecret(entry.key, asyncSecret);
    }

    return bloc;
  }
}
