/// Secret rotation and lifecycle management.
library;

import 'dart:async';
import 'dart:collection';

import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';
import 'expirable_secret.dart';
import 'expirable_obfuscated.dart';

/// Configuration for secret rotation.
class SecretRotationConfig {
  /// Default TTL for new secrets.
  final Duration defaultTTL;
  
  /// How often to check for expired secrets.
  final Duration checkInterval;
  
  /// Whether to automatically rotate secrets.
  final bool autoRotate;
  
  /// Maximum number of concurrent rotations.
  final int maxConcurrentRotations;
  
  /// Whether to preload rotated secrets.
  final bool preloadRotatedSecrets;
  
  /// Grace period for old secrets after rotation.
  final Duration rotationGracePeriod;

  const SecretRotationConfig({
    this.defaultTTL = const Duration(hours: 24),
    this.checkInterval = const Duration(minutes: 1),
    this.autoRotate = true,
    this.maxConcurrentRotations = 5,
    this.preloadRotatedSecrets = true,
    this.rotationGracePeriod = const Duration(minutes: 15),
  });
}

/// Event emitted when a secret rotation occurs.
class SecretRotationEvent {
  /// The name of the secret that was rotated.
  final String secretName;
  
  /// The type of rotation event.
  final SecretRotationEventType type;
  
  /// The old secret (if available).
  final ExpirableSecret? oldSecret;
  
  /// The new secret (if available).
  final ExpirableSecret? newSecret;
  
  /// Error message if rotation failed.
  final String? error;
  
  /// When the event occurred.
  final DateTime timestamp;

  SecretRotationEvent({
    required this.secretName,
    required this.type,
    this.oldSecret,
    this.newSecret,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Types of secret rotation events.
enum SecretRotationEventType {
  /// Secret rotation started.
  rotationStarted,
  
  /// Secret rotation completed successfully.
  rotationCompleted,
  
  /// Secret rotation failed.
  rotationFailed,
  
  /// Secret expired.
  secretExpired,
  
  /// Secret near expiry.
  secretNearExpiry,
  
  /// Secret refresh started.
  refreshStarted,
  
  /// Secret refresh completed.
  refreshCompleted,
  
  /// Secret refresh failed.
  refreshFailed,
}

/// Manages secret rotation and lifecycle.
class SecretRotationManager {
  final SecretRotationConfig config;
  final SecretProvider secretProvider;
  
  /// Map of managed secrets.
  final Map<String, ExpirableObfuscatedValue> _managedSecrets = {};
  
  /// Map of secret refresh callbacks.
  final Map<String, SecretRefreshCallback> _refreshCallbacks = {};
  
  /// Stream controller for rotation events.
  final StreamController<SecretRotationEvent> _eventController = 
      StreamController<SecretRotationEvent>.broadcast();
  
  /// Timer for periodic expiry checks.
  Timer? _checkTimer;
  
  /// Set of secrets currently being rotated.
  final Set<String> _rotatingSecrets = <String>{};
  
  /// Queue of pending rotations.
  final Queue<String> _rotationQueue = Queue<String>();

  SecretRotationManager({
    required this.config,
    required this.secretProvider,
  }) {
    _startPeriodicChecks();
  }

  /// Stream of rotation events.
  Stream<SecretRotationEvent> get events => _eventController.stream;

  /// Registers a secret for rotation management.
  void registerSecret<T>(
    String name,
    ExpirableObfuscatedValue<T> secret, {
    SecretRefreshCallback? refreshCallback,
  }) {
    _managedSecrets[name] = secret;
    
    if (refreshCallback != null) {
      _refreshCallbacks[name] = refreshCallback;
      secret.setRefreshCallback(refreshCallback);
    } else {
      // Default refresh callback that loads from provider
      final defaultCallback = _createDefaultRefreshCallback(name);
      _refreshCallbacks[name] = defaultCallback;
      secret.setRefreshCallback(defaultCallback);
    }

    // Set expiry callback
    secret.setExpiryCallback((secretName, expirableSecret) async {
      _emitEvent(SecretRotationEvent(
        secretName: secretName,
        type: expirableSecret.isHardExpired 
            ? SecretRotationEventType.secretExpired
            : SecretRotationEventType.secretNearExpiry,
        oldSecret: expirableSecret,
      ));
    });
  }

  /// Unregisters a secret from rotation management.
  void unregisterSecret(String name) {
    final secret = _managedSecrets.remove(name);
    secret?.dispose();
    _refreshCallbacks.remove(name);
    _rotatingSecrets.remove(name);
  }

  /// Gets a managed secret by name.
  ExpirableObfuscatedValue<T>? getSecret<T>(String name) {
    return _managedSecrets[name] as ExpirableObfuscatedValue<T>?;
  }

  /// Lists all managed secret names.
  List<String> listSecrets() => _managedSecrets.keys.toList();

  /// Gets secrets by expiry status.
  Map<String, ExpirableObfuscatedValue> getSecretsByStatus(SecretExpiryStatus status) {
    return Map.fromEntries(
      _managedSecrets.entries.where((entry) => entry.value.expiryStatus == status),
    );
  }

  /// Manually triggers rotation for a specific secret.
  Future<bool> rotateSecret(String name) async {
    if (_rotatingSecrets.contains(name)) {
      return false; // Already rotating
    }

    if (_rotatingSecrets.length >= config.maxConcurrentRotations) {
      _rotationQueue.add(name);
      return false; // Queued for later
    }

    return await _performRotation(name);
  }

  /// Manually triggers rotation for all expired secrets.
  Future<void> rotateExpiredSecrets() async {
    final expiredSecrets = getSecretsByStatus(SecretExpiryStatus.expired);
    final nearExpirySecrets = getSecretsByStatus(SecretExpiryStatus.nearExpiry);
    
    final toRotate = {...expiredSecrets.keys, ...nearExpirySecrets.keys};
    
    for (final name in toRotate) {
      if (_rotatingSecrets.length < config.maxConcurrentRotations) {
        unawaited(_performRotation(name));
      } else {
        _rotationQueue.add(name);
      }
    }
  }

  /// Sets a custom refresh callback for a secret.
  void setRefreshCallback(String name, SecretRefreshCallback callback) {
    _refreshCallbacks[name] = callback;
    final secret = _managedSecrets[name];
    secret?.setRefreshCallback(callback);
  }

  /// Gets rotation statistics.
  Map<String, dynamic> getRotationStats() {
    final stats = <String, dynamic>{
      'totalSecrets': _managedSecrets.length,
      'rotatingSecrets': _rotatingSecrets.length,
      'queuedRotations': _rotationQueue.length,
    };

    // Count by status
    for (final status in SecretExpiryStatus.values) {
      final count = getSecretsByStatus(status).length;
      stats['${status.name}Count'] = count;
    }

    return stats;
  }

  /// Performs rotation for a specific secret.
  Future<bool> _performRotation(String name) async {
    if (_rotatingSecrets.contains(name)) return false;
    
    _rotatingSecrets.add(name);
    
    try {
      _emitEvent(SecretRotationEvent(
        secretName: name,
        type: SecretRotationEventType.rotationStarted,
      ));

      final secret = _managedSecrets[name];
      if (secret == null) return false;

      final success = await secret.refresh();
      
      if (success) {
        _emitEvent(SecretRotationEvent(
          secretName: name,
          type: SecretRotationEventType.rotationCompleted,
        ));
      } else {
        _emitEvent(SecretRotationEvent(
          secretName: name,
          type: SecretRotationEventType.rotationFailed,
          error: 'Refresh returned false',
        ));
      }

      return success;
    } catch (e) {
      _emitEvent(SecretRotationEvent(
        secretName: name,
        type: SecretRotationEventType.rotationFailed,
        error: e.toString(),
      ));
      return false;
    } finally {
      _rotatingSecrets.remove(name);
      _processRotationQueue();
    }
  }

  /// Creates a default refresh callback that loads from the provider.
  SecretRefreshCallback _createDefaultRefreshCallback(String name) {
    return (secretName, expirableSecret) async {
      try {
        _emitEvent(SecretRotationEvent(
          secretName: secretName,
          type: SecretRotationEventType.refreshStarted,
        ));

        final newSecret = await secretProvider.loadSecret(name);
        
        if (newSecret != null) {
          _emitEvent(SecretRotationEvent(
            secretName: secretName,
            type: SecretRotationEventType.refreshCompleted,
            newSecret: ExpirableSecret(
              secret: newSecret,
              config: expirableSecret.config,
            ),
          ));
        } else {
          _emitEvent(SecretRotationEvent(
            secretName: secretName,
            type: SecretRotationEventType.refreshFailed,
            error: 'Provider returned null',
          ));
        }

        return newSecret;
      } catch (e) {
        _emitEvent(SecretRotationEvent(
          secretName: secretName,
          type: SecretRotationEventType.refreshFailed,
          error: e.toString(),
        ));
        return null;
      }
    };
  }

  /// Starts periodic expiry checks.
  void _startPeriodicChecks() {
    _checkTimer = Timer.periodic(config.checkInterval, (_) {
      if (config.autoRotate) {
        rotateExpiredSecrets();
      }
    });
  }

  /// Processes the rotation queue.
  void _processRotationQueue() {
    while (_rotationQueue.isNotEmpty && 
           _rotatingSecrets.length < config.maxConcurrentRotations) {
      final name = _rotationQueue.removeFirst();
      unawaited(_performRotation(name));
    }
  }

  /// Emits a rotation event.
  void _emitEvent(SecretRotationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Disposes the rotation manager.
  void dispose() {
    _checkTimer?.cancel();
    for (final secret in _managedSecrets.values) {
      secret.dispose();
    }
    _managedSecrets.clear();
    _refreshCallbacks.clear();
    _rotatingSecrets.clear();
    _rotationQueue.clear();
    _eventController.close();
  }
}

/// Extension to avoid unawaited_futures warnings.
extension _FutureExtension on Future {
  void get unawaited {}
}
