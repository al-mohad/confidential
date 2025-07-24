/// Analytics-aware obfuscated values for dart-confidential.
///
/// This module provides wrappers around obfuscated values that automatically
/// log access attempts and track usage statistics.
library;

import 'dart:async';
import 'dart:typed_data';

import '../obfuscation/secret.dart';
import 'audit_logger.dart';

/// An obfuscated value that automatically logs access attempts.
class AnalyticsObfuscatedValue<T> implements ObfuscatedValue<T> {
  final ObfuscatedValue<T> _wrapped;
  final AuditLogger _logger;
  final String _secretName;

  AnalyticsObfuscatedValue(this._wrapped, this._logger, this._secretName);

  @override
  T get value {
    try {
      final result = _wrapped.value;
      _logger.logAccess(
        secretName: _secretName,
        success: true,
        metadata: {'type': T.toString(), 'accessMethod': 'value_getter'},
      );
      return result;
    } catch (e) {
      _logger.logAccess(
        secretName: _secretName,
        success: false,
        error: e.toString(),
        metadata: {'type': T.toString(), 'accessMethod': 'value_getter'},
      );
      rethrow;
    }
  }

  @override
  T get $ => value;

  @override
  Secret get secret => _wrapped.secret;

  @override
  T Function(Uint8List, int) get deobfuscate => _wrapped.deobfuscate;

  /// Gets the wrapped obfuscated value.
  ObfuscatedValue<T> get wrapped => _wrapped;

  /// Gets the audit logger.
  AuditLogger get logger => _logger;

  /// Gets the secret name.
  String get secretName => _secretName;

  /// Gets access statistics for this secret.
  SecretAccessStats? get stats => _logger.getSecretStats(_secretName);

  @override
  String toString() {
    return 'AnalyticsObfuscatedValue<$T>($_secretName)';
  }
}

/// Factory for creating analytics-aware obfuscated values.
class AnalyticsObfuscatedFactory {
  final AuditLogger _logger;

  AnalyticsObfuscatedFactory(this._logger);

  /// Creates an analytics-aware obfuscated string.
  AnalyticsObfuscatedValue<String> string(
    String secretName,
    ObfuscatedValue<String> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<String>(
      obfuscatedValue,
      _logger,
      secretName,
    );
  }

  /// Creates an analytics-aware obfuscated integer.
  AnalyticsObfuscatedValue<int> integer(
    String secretName,
    ObfuscatedValue<int> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<int>(obfuscatedValue, _logger, secretName);
  }

  /// Creates an analytics-aware obfuscated boolean.
  AnalyticsObfuscatedValue<bool> boolean(
    String secretName,
    ObfuscatedValue<bool> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<bool>(obfuscatedValue, _logger, secretName);
  }

  /// Creates an analytics-aware obfuscated list.
  AnalyticsObfuscatedValue<List<T>> list<T>(
    String secretName,
    ObfuscatedValue<List<T>> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<List<T>>(
      obfuscatedValue,
      _logger,
      secretName,
    );
  }

  /// Creates an analytics-aware obfuscated map.
  AnalyticsObfuscatedValue<Map<String, dynamic>> map(
    String secretName,
    ObfuscatedValue<Map<String, dynamic>> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<Map<String, dynamic>>(
      obfuscatedValue,
      _logger,
      secretName,
    );
  }

  /// Creates an analytics-aware obfuscated value of any type.
  AnalyticsObfuscatedValue<T> generic<T>(
    String secretName,
    ObfuscatedValue<T> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<T>(obfuscatedValue, _logger, secretName);
  }

  /// Wraps an existing obfuscated value with analytics.
  AnalyticsObfuscatedValue<T> wrap<T>(
    String secretName,
    ObfuscatedValue<T> obfuscatedValue,
  ) {
    return AnalyticsObfuscatedValue<T>(obfuscatedValue, _logger, secretName);
  }
}

/// Extension methods for adding analytics to existing obfuscated values.
extension ObfuscatedValueAnalyticsExtension<T> on ObfuscatedValue<T> {
  /// Wraps this obfuscated value with analytics tracking.
  AnalyticsObfuscatedValue<T> withAnalytics(
    AuditLogger logger,
    String secretName,
  ) {
    return AnalyticsObfuscatedValue<T>(this, logger, secretName);
  }
}

/// A manager for analytics-aware secrets.
class AnalyticsSecretManager {
  final AuditLogger _logger;
  final Map<String, AnalyticsObfuscatedValue> _secrets = {};

  AnalyticsSecretManager(this._logger);

  /// Registers a secret with analytics tracking.
  void registerSecret<T>(String name, ObfuscatedValue<T> obfuscatedValue) {
    final analyticsValue = AnalyticsObfuscatedValue<T>(
      obfuscatedValue,
      _logger,
      name,
    );
    _secrets[name] = analyticsValue;

    _logger.logModification(
      secretName: name,
      operation: 'registered',
      metadata: {'type': T.toString()},
    );
  }

  /// Gets a secret by name.
  AnalyticsObfuscatedValue<T>? getSecret<T>(String name) {
    return _secrets[name] as AnalyticsObfuscatedValue<T>?;
  }

  /// Gets a secret value by name.
  T? getSecretValue<T>(String name) {
    final secret = getSecret<T>(name);
    return secret?.value;
  }

  /// Removes a secret.
  void removeSecret(String name) {
    final removed = _secrets.remove(name);
    if (removed != null) {
      _logger.logDeletion(
        secretName: name,
        metadata: {'type': removed.runtimeType.toString()},
      );
    }
  }

  /// Gets all registered secret names.
  List<String> get secretNames => _secrets.keys.toList();

  /// Gets the count of registered secrets.
  int get secretCount => _secrets.length;

  /// Gets access statistics for all secrets.
  Map<String, SecretAccessStats> getAllStats() {
    return _logger.getAllStats();
  }

  /// Gets access statistics for a specific secret.
  SecretAccessStats? getSecretStats(String name) {
    return _logger.getSecretStats(name);
  }

  /// Clears all secrets and logs the action.
  void clearSecrets() {
    final secretNames = List<String>.from(_secrets.keys);
    _secrets.clear();

    for (final name in secretNames) {
      _logger.logDeletion(
        secretName: name,
        metadata: {'operation': 'bulk_clear'},
      );
    }
  }

  /// Gets the audit logger.
  AuditLogger get logger => _logger;
}

/// A stream-based analytics reporter for real-time monitoring.
class AnalyticsReporter {
  final AuditLogger _logger;
  final Duration _reportInterval;
  Timer? _reportTimer;
  final StreamController<AnalyticsReport> _reportController =
      StreamController<AnalyticsReport>.broadcast();

  AnalyticsReporter(
    this._logger, {
    Duration reportInterval = const Duration(minutes: 1),
  }) : _reportInterval = reportInterval;

  /// Stream of analytics reports.
  Stream<AnalyticsReport> get reports => _reportController.stream;

  /// Starts periodic reporting.
  void startReporting() {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      _generateReport();
    });
  }

  /// Stops periodic reporting.
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }

  /// Generates an immediate report.
  AnalyticsReport generateReport() {
    final report = _generateReport();
    return report;
  }

  AnalyticsReport _generateReport() {
    final now = DateTime.now();
    final stats = _logger.getAllStats();
    final recentLogs = _logger.getRecentLogs(limit: 100);
    final suspiciousEvents = _logger.getSuspiciousEvents(limit: 50);

    final report = AnalyticsReport(
      timestamp: now,
      totalSecrets: stats.length,
      totalAccesses: stats.values.fold(
        0,
        (sum, stat) => sum + stat.totalAccesses,
      ),
      successfulAccesses: stats.values.fold(
        0,
        (sum, stat) => sum + stat.successfulAccesses,
      ),
      failedAccesses: stats.values.fold(
        0,
        (sum, stat) => sum + stat.failedAccesses,
      ),
      suspiciousEvents: suspiciousEvents.length,
      topAccessedSecrets: _getTopAccessedSecrets(stats, 5),
      recentSuspiciousEvents: suspiciousEvents.take(10).toList(),
    );

    _reportController.add(report);
    return report;
  }

  List<SecretAccessStats> _getTopAccessedSecrets(
    Map<String, SecretAccessStats> stats,
    int limit,
  ) {
    final sortedStats = stats.values.toList()
      ..sort((a, b) => b.totalAccesses.compareTo(a.totalAccesses));

    return sortedStats.take(limit).toList();
  }

  /// Disposes of the reporter.
  void dispose() {
    _reportTimer?.cancel();
    _reportController.close();
  }
}

/// An analytics report containing usage statistics.
class AnalyticsReport {
  /// Timestamp when the report was generated.
  final DateTime timestamp;

  /// Total number of secrets being tracked.
  final int totalSecrets;

  /// Total number of access attempts.
  final int totalAccesses;

  /// Number of successful accesses.
  final int successfulAccesses;

  /// Number of failed accesses.
  final int failedAccesses;

  /// Number of suspicious events.
  final int suspiciousEvents;

  /// Top accessed secrets.
  final List<SecretAccessStats> topAccessedSecrets;

  /// Recent suspicious events.
  final List<AuditLogEntry> recentSuspiciousEvents;

  const AnalyticsReport({
    required this.timestamp,
    required this.totalSecrets,
    required this.totalAccesses,
    required this.successfulAccesses,
    required this.failedAccesses,
    required this.suspiciousEvents,
    required this.topAccessedSecrets,
    required this.recentSuspiciousEvents,
  });

  /// Success rate as a percentage.
  double get successRate {
    if (totalAccesses == 0) return 0.0;
    return (successfulAccesses / totalAccesses) * 100.0;
  }

  /// Whether there are any security concerns.
  bool get hasSecurityConcerns => suspiciousEvents > 0 || successRate < 95.0;

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'totalSecrets': totalSecrets,
      'totalAccesses': totalAccesses,
      'successfulAccesses': successfulAccesses,
      'failedAccesses': failedAccesses,
      'suspiciousEvents': suspiciousEvents,
      'successRate': successRate,
      'hasSecurityConcerns': hasSecurityConcerns,
      'topAccessedSecrets': topAccessedSecrets.map((s) => s.toJson()).toList(),
      'recentSuspiciousEvents': recentSuspiciousEvents
          .map((e) => e.toJson())
          .toList(),
    };
  }

  @override
  String toString() {
    return 'AnalyticsReport(${timestamp.toIso8601String()}): '
        '$totalSecrets secrets, $totalAccesses accesses, '
        '${successRate.toStringAsFixed(1)}% success rate, '
        '$suspiciousEvents suspicious events';
  }
}
