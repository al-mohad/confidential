/// Expirable secret containers with TTL and rotation support.
library;

import 'dart:async';

import '../obfuscation/secret.dart';

/// Callback function for when a secret expires.
typedef SecretExpiryCallback =
    Future<void> Function(String secretName, ExpirableSecret secret);

/// Callback function for when a secret needs refresh.
typedef SecretRefreshCallback =
    Future<Secret?> Function(String secretName, ExpirableSecret secret);

/// Configuration for secret expiry behavior.
class SecretExpiryConfig {
  /// Time-to-live for the secret.
  final Duration? ttl;

  /// Absolute expiry timestamp.
  final DateTime? expiresAt;

  /// Grace period before hard expiry.
  final Duration gracePeriod;

  /// Whether to auto-refresh before expiry.
  final bool autoRefresh;

  /// How early to trigger refresh before expiry.
  final Duration refreshThreshold;

  /// Maximum number of refresh attempts.
  final int maxRefreshAttempts;

  /// Delay between refresh attempts.
  final Duration refreshRetryDelay;

  const SecretExpiryConfig({
    this.ttl,
    this.expiresAt,
    this.gracePeriod = const Duration(minutes: 5),
    this.autoRefresh = true,
    this.refreshThreshold = const Duration(minutes: 10),
    this.maxRefreshAttempts = 3,
    this.refreshRetryDelay = const Duration(seconds: 30),
  });

  /// Creates config with TTL from now.
  factory SecretExpiryConfig.withTTL(
    Duration ttl, {
    Duration gracePeriod = const Duration(minutes: 5),
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
  }) {
    return SecretExpiryConfig(
      ttl: ttl,
      expiresAt: DateTime.now().add(ttl),
      gracePeriod: gracePeriod,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
    );
  }

  /// Creates config with absolute expiry time.
  factory SecretExpiryConfig.withExpiryTime(
    DateTime expiresAt, {
    Duration gracePeriod = const Duration(minutes: 5),
    bool autoRefresh = true,
    Duration refreshThreshold = const Duration(minutes: 10),
  }) {
    return SecretExpiryConfig(
      expiresAt: expiresAt,
      gracePeriod: gracePeriod,
      autoRefresh: autoRefresh,
      refreshThreshold: refreshThreshold,
    );
  }
}

/// Status of an expirable secret.
enum SecretExpiryStatus {
  /// Secret is valid and not near expiry.
  valid,

  /// Secret is near expiry and should be refreshed.
  nearExpiry,

  /// Secret has expired but is in grace period.
  expired,

  /// Secret has hard expired and cannot be used.
  hardExpired,

  /// Secret is being refreshed.
  refreshing,

  /// Secret refresh failed.
  refreshFailed,
}

/// An expirable secret container with TTL and rotation support.
class ExpirableSecret {
  /// The underlying secret data.
  final Secret _secret;

  /// Expiry configuration.
  final SecretExpiryConfig config;

  /// When this secret was created.
  final DateTime createdAt;

  /// Current expiry status.
  SecretExpiryStatus _status;

  /// Refresh callback for automatic renewal.
  SecretRefreshCallback? _refreshCallback;

  /// Expiry callback for notifications.
  SecretExpiryCallback? _expiryCallback;

  /// Timer for automatic refresh.
  Timer? _refreshTimer;

  /// Current refresh attempt count.
  int _refreshAttempts = 0;

  /// Whether refresh is in progress.
  bool _isRefreshing = false;

  ExpirableSecret({
    required Secret secret,
    required this.config,
    DateTime? createdAt,
  }) : _secret = secret,
       createdAt = createdAt ?? DateTime.now(),
       _status = SecretExpiryStatus.valid {
    _scheduleRefreshIfNeeded();
  }

  /// Gets the underlying secret data.
  Secret get secret {
    _updateStatus();

    if (_status == SecretExpiryStatus.hardExpired) {
      throw SecretExpiredException('Secret has expired and cannot be accessed');
    }

    return _secret;
  }

  /// Gets the current expiry status.
  SecretExpiryStatus get status {
    _updateStatus();
    return _status;
  }

  /// Gets the expiry time.
  DateTime? get expiresAt => config.expiresAt;

  /// Gets the hard expiry time (including grace period).
  DateTime? get hardExpiresAt {
    if (config.expiresAt == null) return null;
    return config.expiresAt!.add(config.gracePeriod);
  }

  /// Gets time until expiry.
  Duration? get timeUntilExpiry {
    if (config.expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(config.expiresAt!)) return Duration.zero;
    return config.expiresAt!.difference(now);
  }

  /// Gets time until hard expiry.
  Duration? get timeUntilHardExpiry {
    final hardExpiry = hardExpiresAt;
    if (hardExpiry == null) return null;
    final now = DateTime.now();
    if (now.isAfter(hardExpiry)) return Duration.zero;
    return hardExpiry.difference(now);
  }

  /// Checks if the secret is expired.
  bool get isExpired {
    if (config.expiresAt == null) return false;
    return DateTime.now().isAfter(config.expiresAt!);
  }

  /// Checks if the secret is hard expired.
  bool get isHardExpired {
    final hardExpiry = hardExpiresAt;
    if (hardExpiry == null) return false;
    return DateTime.now().isAfter(hardExpiry);
  }

  /// Checks if the secret is near expiry.
  bool get isNearExpiry {
    if (config.expiresAt == null) return false;
    final threshold = config.expiresAt!.subtract(config.refreshThreshold);
    return DateTime.now().isAfter(threshold);
  }

  /// Sets the refresh callback.
  void setRefreshCallback(SecretRefreshCallback callback) {
    _refreshCallback = callback;
    _scheduleRefreshIfNeeded();
  }

  /// Sets the expiry callback.
  void setExpiryCallback(SecretExpiryCallback callback) {
    _expiryCallback = callback;
  }

  /// Manually triggers a refresh.
  Future<bool> refresh(String secretName) async {
    if (_isRefreshing) return false;
    if (_refreshCallback == null) return false;

    _isRefreshing = true;
    _status = SecretExpiryStatus.refreshing;

    try {
      final newSecret = await _refreshCallback!(secretName, this);
      if (newSecret != null) {
        // Create new expirable secret with refreshed data
        final newExpirable = ExpirableSecret(secret: newSecret, config: config);

        // Copy callbacks
        newExpirable._refreshCallback = _refreshCallback;
        newExpirable._expiryCallback = _expiryCallback;

        _refreshAttempts = 0;
        _status = SecretExpiryStatus.valid;
        return true;
      }
    } catch (e) {
      _refreshAttempts++;
      _status = SecretExpiryStatus.refreshFailed;

      // Retry if under limit
      if (_refreshAttempts < config.maxRefreshAttempts) {
        Timer(config.refreshRetryDelay, () => refresh(secretName));
      }
    } finally {
      _isRefreshing = false;
    }

    return false;
  }

  /// Updates the current status based on expiry times.
  void _updateStatus() {
    if (_isRefreshing) return;

    if (isHardExpired) {
      _status = SecretExpiryStatus.hardExpired;
      _notifyExpiry();
    } else if (isExpired) {
      _status = SecretExpiryStatus.expired;
      _notifyExpiry();
    } else if (isNearExpiry) {
      _status = SecretExpiryStatus.nearExpiry;
      if (config.autoRefresh && _refreshCallback != null) {
        // Trigger refresh in background
        Timer.run(() => refresh('auto-refresh'));
      }
    } else {
      _status = SecretExpiryStatus.valid;
    }
  }

  /// Schedules automatic refresh if needed.
  void _scheduleRefreshIfNeeded() {
    if (!config.autoRefresh ||
        _refreshCallback == null ||
        config.expiresAt == null) {
      return;
    }

    final refreshTime = config.expiresAt!.subtract(config.refreshThreshold);
    final now = DateTime.now();

    if (refreshTime.isAfter(now)) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(refreshTime.difference(now), () {
        refresh('scheduled-refresh');
      });
    }
  }

  /// Notifies expiry callback if set.
  void _notifyExpiry() async {
    if (_expiryCallback != null) {
      try {
        await _expiryCallback!('expired-secret', this);
      } catch (e) {
        // Ignore callback errors
      }
    }
  }

  /// Disposes resources.
  void dispose() {
    _refreshTimer?.cancel();
  }
}

/// Exception thrown when trying to access an expired secret.
class SecretExpiredException implements Exception {
  final String message;

  const SecretExpiredException(this.message);

  @override
  String toString() => 'SecretExpiredException: $message';
}
