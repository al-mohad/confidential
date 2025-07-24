/// GetX state management and dependency injection integration for dart-confidential.
/// 
/// This module provides seamless integration with GetX,
/// allowing injection of obfuscated secrets via GetX controllers and services.
library;

import 'dart:async';

import '../obfuscation/secret.dart';
import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';

/// GetX-like interfaces to avoid hard dependency.
/// 
/// These allow the integration to work without requiring get as a dependency.

/// GetX controller interface.
abstract class GetxControllerLike {
  /// Called when the controller is initialized.
  void onInit();
  
  /// Called when the controller is ready.
  void onReady();
  
  /// Called when the controller is closed.
  void onClose();
  
  /// Updates the UI.
  void update([List<Object>? ids]);
}

/// GetX service interface.
abstract class GetxServiceLike {
  /// Called when the service is initialized.
  void onInit();
  
  /// Called when the service is ready.
  void onReady();
  
  /// Called when the service is closed.
  void onClose();
}

/// Reactive value interface for GetX compatibility.
abstract class RxLike<T> {
  /// The current value.
  T get value;
  set value(T val);
  
  /// Stream of value changes.
  Stream<T> get stream;
  
  /// Listens to value changes.
  StreamSubscription<T> listen(void Function(T) onData);
  
  /// Updates the value.
  void call(T val);
  
  /// Closes the reactive value.
  void close();
}

/// Simple implementation of Rx for our integration.
class _SimpleRx<T> implements RxLike<T> {
  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  _SimpleRx(this._value);

  @override
  T get value => _value;

  @override
  set value(T val) {
    _value = val;
    _controller.add(val);
  }

  @override
  Stream<T> get stream => _controller.stream;

  @override
  StreamSubscription<T> listen(void Function(T) onData) {
    return _controller.stream.listen(onData);
  }

  @override
  void call(T val) {
    value = val;
  }

  @override
  void close() {
    _controller.close();
  }
}

/// GetX controller for managing obfuscated secrets.
class SecretController implements GetxControllerLike {
  final Map<String, ObfuscatedValue> _staticSecrets = {};
  final Map<String, AsyncObfuscatedValue> _asyncSecrets = {};
  final Map<String, RxLike> _reactiveValues = {};
  final Map<String, Timer> _refreshTimers = {};
  
  bool _initialized = false;
  bool _closed = false;

  /// Adds a static obfuscated secret.
  void addStaticSecret<T>(String name, ObfuscatedValue<T> secret) {
    if (_closed) return;
    
    _staticSecrets[name] = secret;
    final rx = _SimpleRx<T>(secret.value);
    _reactiveValues[name] = rx;
    
    if (_initialized) {
      update([name]);
    }
  }

  /// Adds an async obfuscated secret.
  void addAsyncSecret<T>(
    String name, 
    AsyncObfuscatedValue<T> secret, {
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    if (_closed) return;
    
    _asyncSecrets[name] = secret;
    final rx = _SimpleRx<T?>(null);
    _reactiveValues[name] = rx;
    
    // Load initial value
    _loadAsyncSecret<T>(name, secret, rx as _SimpleRx<T?>);
    
    // Set up auto-refresh
    if (autoRefresh) {
      _refreshTimers[name] = Timer.periodic(refreshInterval, (_) {
        if (!_closed) {
          _loadAsyncSecret<T>(name, secret, rx);
        }
      });
    }
  }

  /// Gets a reactive value by name.
  RxLike<T>? getRx<T>(String name) {
    return _reactiveValues[name] as RxLike<T>?;
  }

  /// Gets a static secret value.
  T? getStatic<T>(String name) {
    final rx = _reactiveValues[name] as RxLike<T>?;
    return rx?.value;
  }

  /// Gets an async secret value (may be null if not loaded).
  T? getAsync<T>(String name) {
    final rx = _reactiveValues[name] as RxLike<T?>?;
    return rx?.value;
  }

  /// Gets an async secret value with a fallback.
  T getAsyncOrDefault<T>(String name, T defaultValue) {
    return getAsync<T>(name) ?? defaultValue;
  }

  /// Manually refreshes an async secret.
  Future<void> refreshSecret(String name) async {
    final asyncSecret = _asyncSecrets[name];
    final rx = _reactiveValues[name];
    
    if (asyncSecret != null && rx != null) {
      asyncSecret.clearCache();
      await _loadAsyncSecret(name, asyncSecret, rx as _SimpleRx);
    }
  }

  /// Refreshes all async secrets.
  Future<void> refreshAll() async {
    final futures = _asyncSecrets.keys.map((name) => refreshSecret(name));
    await Future.wait(futures);
  }

  /// Removes a secret.
  void removeSecret(String name) {
    if (_closed) return;
    
    _staticSecrets.remove(name);
    _asyncSecrets.remove(name);
    
    final rx = _reactiveValues.remove(name);
    rx?.close();
    
    final timer = _refreshTimers.remove(name);
    timer?.cancel();
    
    if (_initialized) {
      update([name]);
    }
  }

  /// Gets all secret names.
  List<String> get secretNames => [
    ..._staticSecrets.keys,
    ..._asyncSecrets.keys,
  ];

  /// Gets the count of secrets.
  int get secretCount => _staticSecrets.length + _asyncSecrets.length;

  /// Whether the controller is initialized.
  bool get isInitialized => _initialized;

  /// Whether the controller is closed.
  bool get isClosed => _closed;

  Future<void> _loadAsyncSecret<T>(
    String name,
    AsyncObfuscatedValue<T> secret,
    _SimpleRx rx,
  ) async {
    try {
      final value = await secret.value;
      if (!_closed) {
        rx.value = value;
        if (_initialized) {
          update([name]);
        }
      }
    } catch (e) {
      // Handle error silently or log it
      if (!_closed && _initialized) {
        update([name]);
      }
    }
  }

  @override
  void onInit() {
    _initialized = true;
  }

  @override
  void onReady() {
    // Called when the controller is ready
  }

  @override
  void onClose() {
    _closed = true;
    
    // Cancel all timers
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    
    // Close all reactive values
    for (final rx in _reactiveValues.values) {
      rx.close();
    }
    _reactiveValues.clear();
    
    _staticSecrets.clear();
    _asyncSecrets.clear();
  }

  @override
  void update([List<Object>? ids]) {
    // In real GetX, this would trigger UI updates
    // For our mock implementation, we'll just notify reactive values
  }
}

/// GetX service for managing secrets across the application.
class SecretService implements GetxServiceLike {
  final Map<String, SecretController> _controllers = {};
  bool _initialized = false;
  bool _closed = false;

  /// Creates or gets a secret controller by name.
  SecretController controller(String name) {
    if (_closed) {
      throw StateError('SecretService is closed');
    }
    
    return _controllers.putIfAbsent(name, () {
      final controller = SecretController();
      if (_initialized) {
        controller.onInit();
        controller.onReady();
      }
      return controller;
    });
  }

  /// Gets the default secret controller.
  SecretController get secrets => controller('default');

  /// Adds a static secret to the default controller.
  void addStaticSecret<T>(String name, ObfuscatedValue<T> secret) {
    secrets.addStaticSecret(name, secret);
  }

  /// Adds an async secret to the default controller.
  void addAsyncSecret<T>(
    String name, 
    AsyncObfuscatedValue<T> secret, {
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    secrets.addAsyncSecret(
      name, 
      secret, 
      refreshInterval: refreshInterval,
      autoRefresh: autoRefresh,
    );
  }

  /// Gets a reactive value from the default controller.
  RxLike<T>? getRx<T>(String name) {
    return secrets.getRx<T>(name);
  }

  /// Gets a static secret value from the default controller.
  T? getStatic<T>(String name) {
    return secrets.getStatic<T>(name);
  }

  /// Gets an async secret value from the default controller.
  T? getAsync<T>(String name) {
    return secrets.getAsync<T>(name);
  }

  /// Gets an async secret value with a fallback.
  T getAsyncOrDefault<T>(String name, T defaultValue) {
    return secrets.getAsyncOrDefault<T>(name, defaultValue);
  }

  /// Refreshes all secrets in all controllers.
  Future<void> refreshAll() async {
    final futures = _controllers.values.map((controller) => controller.refreshAll());
    await Future.wait(futures);
  }

  /// Gets all controller names.
  List<String> get controllerNames => _controllers.keys.toList();

  /// Gets the count of controllers.
  int get controllerCount => _controllers.length;

  /// Whether the service is initialized.
  bool get isInitialized => _initialized;

  /// Whether the service is closed.
  bool get isClosed => _closed;

  @override
  void onInit() {
    _initialized = true;
    
    // Initialize all existing controllers
    for (final controller in _controllers.values) {
      controller.onInit();
    }
  }

  @override
  void onReady() {
    // Initialize all existing controllers
    for (final controller in _controllers.values) {
      controller.onReady();
    }
  }

  @override
  void onClose() {
    _closed = true;
    
    // Close all controllers
    for (final controller in _controllers.values) {
      controller.onClose();
    }
    _controllers.clear();
  }
}

/// Factory for creating GetX-compatible instances.
class ConfidentialGetXFactory {
  /// Creates a secret controller.
  static SecretController createController() {
    return SecretController();
  }

  /// Creates a secret service.
  static SecretService createService() {
    return SecretService();
  }

  /// Creates a secret controller with secrets from a provider.
  static Future<SecretController> createControllerWithProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) async {
    final controller = SecretController();
    
    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );
      
      controller.addAsyncSecret(
        entry.key,
        asyncSecret,
        refreshInterval: refreshInterval,
        autoRefresh: autoRefresh,
      );
    }
    
    controller.onInit();
    controller.onReady();
    
    return controller;
  }

  /// Creates a secret service with secrets from a provider.
  static Future<SecretService> createServiceWithProvider({
    required SecretProvider secretProvider,
    required Map<String, String> secretNames, // name -> algorithm
    Duration refreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) async {
    final service = SecretService();
    
    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );
      
      service.addAsyncSecret(
        entry.key,
        asyncSecret,
        refreshInterval: refreshInterval,
        autoRefresh: autoRefresh,
      );
    }
    
    service.onInit();
    service.onReady();
    
    return service;
  }
}

/// Extension methods for easier GetX integration.
extension GetXConfidentialExtension on SecretController {
  /// Binds a secret to a reactive variable.
  RxLike<T> bindSecret<T>(String name) {
    final rx = getRx<T>(name);
    if (rx == null) {
      throw ArgumentError('Secret "$name" not found');
    }
    return rx;
  }

  /// Creates a computed reactive value based on secrets.
  RxLike<R> computed<R>(R Function() computation) {
    final rx = _SimpleRx<R>(computation());
    
    // In a real implementation, this would track dependencies
    // and update when any dependent secret changes
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) {
        try {
          rx.value = computation();
        } catch (e) {
          // Handle computation errors
        }
      }
    });
    
    return rx;
  }

  /// Creates a worker that reacts to secret changes.
  StreamSubscription<T> worker<T>(
    String secretName,
    void Function(T) callback,
  ) {
    final rx = getRx<T>(secretName);
    if (rx == null) {
      throw ArgumentError('Secret "$secretName" not found');
    }
    
    return rx.listen(callback);
  }
}
