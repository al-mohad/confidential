/// Analytics and audit logging for dart-confidential.
///
/// This module provides anonymized access tracking and suspicious behavior detection
/// while maintaining privacy and security.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// Configuration for analytics and audit logging.
class AnalyticsConfig {
  /// Whether analytics are enabled.
  final bool enabled;

  /// Whether to enable access counters per secret.
  final bool enableAccessCounters;

  /// Whether to enable suspicious behavior detection.
  final bool enableSuspiciousDetection;

  /// Whether to anonymize all logged data.
  final bool anonymizeData;

  /// Maximum number of access logs to keep in memory.
  final int maxLogEntries;

  /// Time window for suspicious behavior detection (in minutes).
  final int suspiciousTimeWindowMinutes;

  /// Maximum access attempts per secret within time window before flagging as suspicious.
  final int maxAccessAttemptsPerWindow;

  /// Whether to log successful accesses.
  final bool logSuccessfulAccess;

  /// Whether to log failed accesses.
  final bool logFailedAccess;

  /// Custom log handler for external logging systems.
  final void Function(AuditLogEntry)? customLogHandler;

  const AnalyticsConfig({
    this.enabled = false,
    this.enableAccessCounters = true,
    this.enableSuspiciousDetection = true,
    this.anonymizeData = true,
    this.maxLogEntries = 1000,
    this.suspiciousTimeWindowMinutes = 5,
    this.maxAccessAttemptsPerWindow = 50,
    this.logSuccessfulAccess = true,
    this.logFailedAccess = true,
    this.customLogHandler,
  });

  /// Creates a configuration with analytics disabled.
  factory AnalyticsConfig.disabled() {
    return const AnalyticsConfig(enabled: false);
  }

  /// Creates a configuration for development with minimal logging.
  factory AnalyticsConfig.development() {
    return const AnalyticsConfig(
      enabled: true,
      enableAccessCounters: true,
      enableSuspiciousDetection: false,
      anonymizeData: true,
      maxLogEntries: 100,
      logSuccessfulAccess: false,
      logFailedAccess: true,
    );
  }

  /// Creates a configuration for production with full security monitoring.
  factory AnalyticsConfig.production() {
    return const AnalyticsConfig(
      enabled: true,
      enableAccessCounters: true,
      enableSuspiciousDetection: true,
      anonymizeData: true,
      maxLogEntries: 5000,
      suspiciousTimeWindowMinutes: 5,
      maxAccessAttemptsPerWindow: 20,
      logSuccessfulAccess: true,
      logFailedAccess: true,
    );
  }

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'enableAccessCounters': enableAccessCounters,
      'enableSuspiciousDetection': enableSuspiciousDetection,
      'anonymizeData': anonymizeData,
      'maxLogEntries': maxLogEntries,
      'suspiciousTimeWindowMinutes': suspiciousTimeWindowMinutes,
      'maxAccessAttemptsPerWindow': maxAccessAttemptsPerWindow,
      'logSuccessfulAccess': logSuccessfulAccess,
      'logFailedAccess': logFailedAccess,
    };
  }

  /// Creates from JSON.
  factory AnalyticsConfig.fromJson(Map<String, dynamic> json) {
    return AnalyticsConfig(
      enabled: json['enabled'] as bool? ?? false,
      enableAccessCounters: json['enableAccessCounters'] as bool? ?? true,
      enableSuspiciousDetection:
          json['enableSuspiciousDetection'] as bool? ?? true,
      anonymizeData: json['anonymizeData'] as bool? ?? true,
      maxLogEntries: json['maxLogEntries'] as int? ?? 1000,
      suspiciousTimeWindowMinutes:
          json['suspiciousTimeWindowMinutes'] as int? ?? 5,
      maxAccessAttemptsPerWindow:
          json['maxAccessAttemptsPerWindow'] as int? ?? 50,
      logSuccessfulAccess: json['logSuccessfulAccess'] as bool? ?? true,
      logFailedAccess: json['logFailedAccess'] as bool? ?? true,
    );
  }
}

/// Types of access events.
enum AccessEventType {
  /// Successful secret access.
  success,

  /// Failed secret access (e.g., decryption error).
  failure,

  /// Suspicious behavior detected.
  suspicious,

  /// Secret was created or updated.
  modification,

  /// Secret was deleted.
  deletion,
}

/// Severity levels for audit events.
enum AuditSeverity {
  /// Informational events.
  info,

  /// Warning events.
  warning,

  /// Error events.
  error,

  /// Critical security events.
  critical,
}

/// An audit log entry.
class AuditLogEntry {
  /// Unique identifier for this log entry.
  final String id;

  /// Timestamp of the event.
  final DateTime timestamp;

  /// Type of access event.
  final AccessEventType eventType;

  /// Severity level.
  final AuditSeverity severity;

  /// Anonymized secret identifier.
  final String secretId;

  /// Anonymized session identifier.
  final String? sessionId;

  /// Event message.
  final String message;

  /// Additional metadata (anonymized).
  final Map<String, dynamic> metadata;

  /// Whether this event was flagged as suspicious.
  final bool isSuspicious;

  AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.secretId,
    this.sessionId,
    required this.message,
    this.metadata = const {},
    this.isSuspicious = false,
  });

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType.name,
      'severity': severity.name,
      'secretId': secretId,
      'sessionId': sessionId,
      'message': message,
      'metadata': metadata,
      'isSuspicious': isSuspicious,
    };
  }

  /// Creates from JSON.
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventType: AccessEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => AccessEventType.success,
      ),
      severity: AuditSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AuditSeverity.info,
      ),
      secretId: json['secretId'] as String,
      sessionId: json['sessionId'] as String?,
      message: json['message'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isSuspicious: json['isSuspicious'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'AuditLogEntry(${timestamp.toIso8601String()}) [$severity] $eventType: $message';
  }
}

/// Statistics for secret access.
class SecretAccessStats {
  /// Anonymized secret identifier.
  final String secretId;

  /// Total number of successful accesses.
  final int successfulAccesses;

  /// Total number of failed accesses.
  final int failedAccesses;

  /// First access timestamp.
  final DateTime? firstAccess;

  /// Last access timestamp.
  final DateTime? lastAccess;

  /// Number of suspicious events.
  final int suspiciousEvents;

  /// Average time between accesses (in milliseconds).
  final double? averageTimeBetweenAccesses;

  const SecretAccessStats({
    required this.secretId,
    this.successfulAccesses = 0,
    this.failedAccesses = 0,
    this.firstAccess,
    this.lastAccess,
    this.suspiciousEvents = 0,
    this.averageTimeBetweenAccesses,
  });

  /// Total number of accesses.
  int get totalAccesses => successfulAccesses + failedAccesses;

  /// Success rate as a percentage.
  double get successRate {
    if (totalAccesses == 0) return 0.0;
    return (successfulAccesses / totalAccesses) * 100.0;
  }

  /// Whether this secret has suspicious activity.
  bool get hasSuspiciousActivity => suspiciousEvents > 0;

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'secretId': secretId,
      'successfulAccesses': successfulAccesses,
      'failedAccesses': failedAccesses,
      'firstAccess': firstAccess?.toIso8601String(),
      'lastAccess': lastAccess?.toIso8601String(),
      'suspiciousEvents': suspiciousEvents,
      'averageTimeBetweenAccesses': averageTimeBetweenAccesses,
    };
  }

  /// Creates from JSON.
  factory SecretAccessStats.fromJson(Map<String, dynamic> json) {
    return SecretAccessStats(
      secretId: json['secretId'] as String,
      successfulAccesses: json['successfulAccesses'] as int? ?? 0,
      failedAccesses: json['failedAccesses'] as int? ?? 0,
      firstAccess: json['firstAccess'] != null
          ? DateTime.parse(json['firstAccess'] as String)
          : null,
      lastAccess: json['lastAccess'] != null
          ? DateTime.parse(json['lastAccess'] as String)
          : null,
      suspiciousEvents: json['suspiciousEvents'] as int? ?? 0,
      averageTimeBetweenAccesses: json['averageTimeBetweenAccesses'] as double?,
    );
  }

  @override
  String toString() {
    return 'SecretAccessStats($secretId): $totalAccesses accesses, ${successRate.toStringAsFixed(1)}% success rate';
  }
}

/// Main audit logger for tracking secret access and detecting suspicious behavior.
class AuditLogger {
  final AnalyticsConfig _config;
  final List<AuditLogEntry> _logEntries = [];
  final Map<String, SecretAccessStats> _accessStats = {};
  final Map<String, List<DateTime>> _recentAccesses = {};
  final Random _random = Random();

  /// Stream controller for real-time audit events.
  final StreamController<AuditLogEntry> _eventController =
      StreamController<AuditLogEntry>.broadcast();

  /// Stream controller for suspicious behavior alerts.
  final StreamController<AuditLogEntry> _suspiciousController =
      StreamController<AuditLogEntry>.broadcast();

  AuditLogger(this._config);

  /// Stream of all audit events.
  Stream<AuditLogEntry> get events => _eventController.stream;

  /// Stream of suspicious behavior events.
  Stream<AuditLogEntry> get suspiciousEvents => _suspiciousController.stream;

  /// Whether analytics are enabled.
  bool get isEnabled => _config.enabled;

  /// Current configuration.
  AnalyticsConfig get config => _config;

  /// Logs a secret access attempt.
  void logAccess({
    required String secretName,
    required bool success,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    if (!_config.enabled) return;

    final shouldLog = success
        ? _config.logSuccessfulAccess
        : _config.logFailedAccess;
    if (!shouldLog) return;

    final secretId = _anonymizeSecretName(secretName);
    final sessionId = _getCurrentSessionId();
    final timestamp = DateTime.now();

    // Create audit log entry
    final entry = AuditLogEntry(
      id: _generateLogId(),
      timestamp: timestamp,
      eventType: success ? AccessEventType.success : AccessEventType.failure,
      severity: success ? AuditSeverity.info : AuditSeverity.warning,
      secretId: secretId,
      sessionId: sessionId,
      message: success
          ? 'Secret accessed successfully'
          : 'Secret access failed: ${error ?? 'Unknown error'}',
      metadata: _anonymizeMetadata(metadata ?? {}),
      isSuspicious: false,
    );

    _addLogEntry(entry);
    _updateAccessStats(secretId, success, timestamp);

    // Check for suspicious behavior
    if (_config.enableSuspiciousDetection) {
      _checkSuspiciousBehavior(secretId, timestamp);
    }
  }

  /// Logs a secret modification event.
  void logModification({
    required String secretName,
    required String operation,
    Map<String, dynamic>? metadata,
  }) {
    if (!_config.enabled) return;

    final secretId = _anonymizeSecretName(secretName);
    final sessionId = _getCurrentSessionId();

    final entry = AuditLogEntry(
      id: _generateLogId(),
      timestamp: DateTime.now(),
      eventType: AccessEventType.modification,
      severity: AuditSeverity.warning,
      secretId: secretId,
      sessionId: sessionId,
      message: 'Secret $operation',
      metadata: _anonymizeMetadata(metadata ?? {}),
    );

    _addLogEntry(entry);
  }

  /// Logs a secret deletion event.
  void logDeletion({
    required String secretName,
    Map<String, dynamic>? metadata,
  }) {
    if (!_config.enabled) return;

    final secretId = _anonymizeSecretName(secretName);
    final sessionId = _getCurrentSessionId();

    final entry = AuditLogEntry(
      id: _generateLogId(),
      timestamp: DateTime.now(),
      eventType: AccessEventType.deletion,
      severity: AuditSeverity.error,
      secretId: secretId,
      sessionId: sessionId,
      message: 'Secret deleted',
      metadata: _anonymizeMetadata(metadata ?? {}),
    );

    _addLogEntry(entry);
  }

  /// Gets access statistics for a secret.
  SecretAccessStats? getSecretStats(String secretName) {
    if (!_config.enableAccessCounters) return null;

    final secretId = _anonymizeSecretName(secretName);
    return _accessStats[secretId];
  }

  /// Gets access statistics for all secrets.
  Map<String, SecretAccessStats> getAllStats() {
    if (!_config.enableAccessCounters) return {};
    return Map.unmodifiable(_accessStats);
  }

  /// Gets recent audit log entries.
  List<AuditLogEntry> getRecentLogs({int? limit}) {
    final entries = List<AuditLogEntry>.from(_logEntries);
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && limit < entries.length) {
      return entries.take(limit).toList();
    }

    return entries;
  }

  /// Gets suspicious events from recent logs.
  List<AuditLogEntry> getSuspiciousEvents({int? limit}) {
    final suspicious = _logEntries
        .where((entry) => entry.isSuspicious)
        .toList();
    suspicious.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && limit < suspicious.length) {
      return suspicious.take(limit).toList();
    }

    return suspicious;
  }

  /// Clears all audit logs and statistics.
  void clearLogs() {
    _logEntries.clear();
    _accessStats.clear();
    _recentAccesses.clear();
  }

  /// Exports audit logs as JSON.
  String exportLogsAsJson() {
    final data = {
      'exportTimestamp': DateTime.now().toIso8601String(),
      'config': _config.toJson(),
      'logEntries': _logEntries.map((entry) => entry.toJson()).toList(),
      'accessStats': _accessStats.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };

    return jsonEncode(data);
  }

  /// Imports audit logs from JSON.
  void importLogsFromJson(String jsonData) {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Import log entries
      final logEntries = data['logEntries'] as List?;
      if (logEntries != null) {
        _logEntries.clear();
        for (final entryData in logEntries) {
          _logEntries.add(
            AuditLogEntry.fromJson(entryData as Map<String, dynamic>),
          );
        }
      }

      // Import access stats
      final accessStats = data['accessStats'] as Map<String, dynamic>?;
      if (accessStats != null) {
        _accessStats.clear();
        for (final entry in accessStats.entries) {
          _accessStats[entry.key] = SecretAccessStats.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      // Handle import errors gracefully
      logModification(
        secretName: 'audit_system',
        operation: 'import_failed',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Disposes of the audit logger.
  void dispose() {
    _eventController.close();
    _suspiciousController.close();
  }

  void _addLogEntry(AuditLogEntry entry) {
    _logEntries.add(entry);

    // Trim logs if exceeding max entries
    if (_logEntries.length > _config.maxLogEntries) {
      _logEntries.removeRange(0, _logEntries.length - _config.maxLogEntries);
    }

    // Emit event
    _eventController.add(entry);

    // Call custom log handler if provided
    _config.customLogHandler?.call(entry);

    // Emit suspicious event if flagged
    if (entry.isSuspicious) {
      _suspiciousController.add(entry);
    }
  }

  void _updateAccessStats(String secretId, bool success, DateTime timestamp) {
    if (!_config.enableAccessCounters) return;

    final currentStats = _accessStats[secretId];

    if (currentStats == null) {
      _accessStats[secretId] = SecretAccessStats(
        secretId: secretId,
        successfulAccesses: success ? 1 : 0,
        failedAccesses: success ? 0 : 1,
        firstAccess: timestamp,
        lastAccess: timestamp,
      );
    } else {
      _accessStats[secretId] = SecretAccessStats(
        secretId: secretId,
        successfulAccesses: currentStats.successfulAccesses + (success ? 1 : 0),
        failedAccesses: currentStats.failedAccesses + (success ? 0 : 1),
        firstAccess: currentStats.firstAccess,
        lastAccess: timestamp,
        suspiciousEvents: currentStats.suspiciousEvents,
        averageTimeBetweenAccesses: _calculateAverageTimeBetweenAccesses(
          secretId,
          timestamp,
        ),
      );
    }
  }

  void _checkSuspiciousBehavior(String secretId, DateTime timestamp) {
    // Track recent accesses for this secret
    _recentAccesses.putIfAbsent(secretId, () => []);
    _recentAccesses[secretId]!.add(timestamp);

    // Remove accesses outside the time window
    final windowStart = timestamp.subtract(
      Duration(minutes: _config.suspiciousTimeWindowMinutes),
    );
    _recentAccesses[secretId]!.removeWhere(
      (access) => access.isBefore(windowStart),
    );

    // Check if access count exceeds threshold
    final recentAccessCount = _recentAccesses[secretId]!.length;
    if (recentAccessCount > _config.maxAccessAttemptsPerWindow) {
      _flagSuspiciousBehavior(secretId, timestamp, recentAccessCount);
    }
  }

  void _flagSuspiciousBehavior(
    String secretId,
    DateTime timestamp,
    int accessCount,
  ) {
    final entry = AuditLogEntry(
      id: _generateLogId(),
      timestamp: timestamp,
      eventType: AccessEventType.suspicious,
      severity: AuditSeverity.critical,
      secretId: secretId,
      sessionId: _getCurrentSessionId(),
      message:
          'Suspicious behavior detected: $accessCount accesses in ${_config.suspiciousTimeWindowMinutes} minutes',
      metadata: {
        'accessCount': accessCount,
        'timeWindowMinutes': _config.suspiciousTimeWindowMinutes,
        'threshold': _config.maxAccessAttemptsPerWindow,
      },
      isSuspicious: true,
    );

    _addLogEntry(entry);

    // Update stats
    final currentStats = _accessStats[secretId];
    if (currentStats != null) {
      _accessStats[secretId] = SecretAccessStats(
        secretId: secretId,
        successfulAccesses: currentStats.successfulAccesses,
        failedAccesses: currentStats.failedAccesses,
        firstAccess: currentStats.firstAccess,
        lastAccess: currentStats.lastAccess,
        suspiciousEvents: currentStats.suspiciousEvents + 1,
        averageTimeBetweenAccesses: currentStats.averageTimeBetweenAccesses,
      );
    }
  }

  String _anonymizeSecretName(String secretName) {
    if (!_config.anonymizeData) return secretName;

    // Create a consistent hash of the secret name for anonymization
    final hash = secretName.hashCode.abs();
    return 'secret_${hash.toRadixString(16)}';
  }

  String? _getCurrentSessionId() {
    if (!_config.anonymizeData) return null;

    // Generate a simple session identifier
    // In a real implementation, this might be based on actual session data
    return 'session_${_random.nextInt(0xFFFFFF).toRadixString(16)}';
  }

  Map<String, dynamic> _anonymizeMetadata(Map<String, dynamic> metadata) {
    if (!_config.anonymizeData) return metadata;

    // Remove or anonymize sensitive metadata
    final anonymized = <String, dynamic>{};

    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip potentially sensitive keys
      if (_isSensitiveKey(key)) {
        continue;
      }

      // Anonymize string values that might be sensitive
      if (value is String && _isSensitiveValue(value)) {
        anonymized[key] = '[ANONYMIZED]';
      } else {
        anonymized[key] = value;
      }
    }

    return anonymized;
  }

  bool _isSensitiveKey(String key) {
    const sensitiveKeys = [
      'password',
      'secret',
      'key',
      'token',
      'auth',
      'credential',
      'user',
      'username',
      'email',
      'phone',
      'address',
      'ip',
    ];

    final lowerKey = key.toLowerCase();
    return sensitiveKeys.any((sensitive) => lowerKey.contains(sensitive));
  }

  bool _isSensitiveValue(String value) {
    // Check for patterns that might indicate sensitive data
    if (value.length > 50) return true; // Long strings might be sensitive
    if (RegExp(r'^[A-Za-z0-9+/=]{20,}$').hasMatch(value))
      return true; // Base64-like
    if (RegExp(r'^[0-9a-fA-F]{16,}$').hasMatch(value))
      return true; // Hex strings

    return false;
  }

  double? _calculateAverageTimeBetweenAccesses(
    String secretId,
    DateTime currentAccess,
  ) {
    final recentAccesses = _recentAccesses[secretId];
    if (recentAccesses == null || recentAccesses.length < 2) return null;

    final sortedAccesses = List<DateTime>.from(recentAccesses)..sort();
    var totalDifference = 0;

    for (int i = 1; i < sortedAccesses.length; i++) {
      totalDifference += sortedAccesses[i]
          .difference(sortedAccesses[i - 1])
          .inMilliseconds;
    }

    return totalDifference / (sortedAccesses.length - 1);
  }

  String _generateLogId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(0xFFFF);
    return '${timestamp.toRadixString(16)}_${random.toRadixString(16)}';
  }
}
