import 'dart:async';
import 'dart:typed_data';

import 'package:confidential/confidential.dart';
import 'package:test/test.dart';

void main() {
  group('Analytics and Audit Logging Tests', () {
    late AuditLogger logger;
    late AnalyticsConfig config;

    setUp(() {
      config = AnalyticsConfig.production();
      logger = AuditLogger(config);
    });

    tearDown(() {
      logger.dispose();
    });

    group('AnalyticsConfig', () {
      test('default configuration', () {
        final defaultConfig = const AnalyticsConfig();
        expect(defaultConfig.enabled, isFalse);
        expect(defaultConfig.enableAccessCounters, isTrue);
        expect(defaultConfig.enableSuspiciousDetection, isTrue);
        expect(defaultConfig.anonymizeData, isTrue);
      });

      test('disabled configuration', () {
        final disabledConfig = AnalyticsConfig.disabled();
        expect(disabledConfig.enabled, isFalse);
      });

      test('development configuration', () {
        final devConfig = AnalyticsConfig.development();
        expect(devConfig.enabled, isTrue);
        expect(devConfig.enableSuspiciousDetection, isFalse);
        expect(devConfig.maxLogEntries, equals(100));
        expect(devConfig.logSuccessfulAccess, isFalse);
      });

      test('production configuration', () {
        final prodConfig = AnalyticsConfig.production();
        expect(prodConfig.enabled, isTrue);
        expect(prodConfig.enableSuspiciousDetection, isTrue);
        expect(prodConfig.maxLogEntries, equals(5000));
        expect(prodConfig.maxAccessAttemptsPerWindow, equals(20));
      });

      test('JSON serialization', () {
        final config = AnalyticsConfig.production();
        final json = config.toJson();
        final restored = AnalyticsConfig.fromJson(json);

        expect(restored.enabled, equals(config.enabled));
        expect(
          restored.enableAccessCounters,
          equals(config.enableAccessCounters),
        );
        expect(restored.maxLogEntries, equals(config.maxLogEntries));
      });
    });

    group('AuditLogger', () {
      test('logs successful access', () {
        logger.logAccess(
          secretName: 'testSecret',
          success: true,
          metadata: {'type': 'String'},
        );

        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(log.eventType, equals(AccessEventType.success));
        expect(log.severity, equals(AuditSeverity.info));
        expect(log.message, contains('successfully'));
      });

      test('logs failed access', () {
        logger.logAccess(
          secretName: 'testSecret',
          success: false,
          error: 'Decryption failed',
          metadata: {'type': 'String'},
        );

        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(log.eventType, equals(AccessEventType.failure));
        expect(log.severity, equals(AuditSeverity.warning));
        expect(log.message, contains('failed'));
        expect(log.message, contains('Decryption failed'));
      });

      test('logs modification events', () {
        logger.logModification(
          secretName: 'testSecret',
          operation: 'created',
          metadata: {'algorithm': 'aes-256-gcm'},
        );

        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(log.eventType, equals(AccessEventType.modification));
        expect(log.severity, equals(AuditSeverity.warning));
        expect(log.message, contains('created'));
      });

      test('logs deletion events', () {
        logger.logDeletion(
          secretName: 'testSecret',
          metadata: {'reason': 'cleanup'},
        );

        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(log.eventType, equals(AccessEventType.deletion));
        expect(log.severity, equals(AuditSeverity.error));
        expect(log.message, contains('deleted'));
      });

      test('tracks access statistics', () {
        // Log multiple accesses
        for (int i = 0; i < 5; i++) {
          logger.logAccess(secretName: 'testSecret', success: true);
        }
        for (int i = 0; i < 2; i++) {
          logger.logAccess(secretName: 'testSecret', success: false);
        }

        final stats = logger.getSecretStats('testSecret');
        expect(stats, isNotNull);
        expect(stats!.successfulAccesses, equals(5));
        expect(stats.failedAccesses, equals(2));
        expect(stats.totalAccesses, equals(7));
        expect(stats.successRate, closeTo(71.4, 0.1));
      });

      test('detects suspicious behavior', () async {
        final suspiciousEvents = <AuditLogEntry>[];
        logger.suspiciousEvents.listen((event) {
          suspiciousEvents.add(event);
        });

        // Generate many rapid accesses to trigger suspicious detection
        for (int i = 0; i < 25; i++) {
          logger.logAccess(secretName: 'testSecret', success: true);
        }

        // Wait a bit for async processing
        await Future.delayed(const Duration(milliseconds: 100));

        expect(suspiciousEvents, isNotEmpty);
        final suspiciousEvent = suspiciousEvents.first;
        expect(suspiciousEvent.eventType, equals(AccessEventType.suspicious));
        expect(suspiciousEvent.severity, equals(AuditSeverity.critical));
        expect(suspiciousEvent.isSuspicious, isTrue);
      });

      test('anonymizes secret names', () {
        logger.logAccess(secretName: 'verySecretPassword', success: true);

        final logs = logger.getRecentLogs();
        final log = logs.first;

        // Secret ID should be anonymized (not the original name)
        expect(log.secretId, isNot(equals('verySecretPassword')));
        expect(log.secretId, startsWith('secret_'));
      });

      test('limits log entries', () {
        final smallConfig = AnalyticsConfig(enabled: true, maxLogEntries: 5);
        final smallLogger = AuditLogger(smallConfig);

        // Add more logs than the limit
        for (int i = 0; i < 10; i++) {
          smallLogger.logAccess(secretName: 'test$i', success: true);
        }

        final logs = smallLogger.getRecentLogs();
        expect(logs.length, equals(5));

        smallLogger.dispose();
      });

      test('exports and imports logs as JSON', () {
        // Add some test data
        logger.logAccess(secretName: 'secret1', success: true);
        logger.logAccess(
          secretName: 'secret2',
          success: false,
          error: 'Test error',
        );
        logger.logModification(secretName: 'secret1', operation: 'updated');

        // Export logs
        final jsonData = logger.exportLogsAsJson();
        expect(jsonData, isNotEmpty);

        // Create new logger and import
        final newLogger = AuditLogger(config);
        newLogger.importLogsFromJson(jsonData);

        // Verify imported data
        final importedLogs = newLogger.getRecentLogs();
        expect(importedLogs.length, equals(3));

        final importedStats = newLogger.getAllStats();
        expect(importedStats, isNotEmpty);

        newLogger.dispose();
      });

      test('handles custom log handler', () {
        final customLogs = <AuditLogEntry>[];
        final customConfig = AnalyticsConfig(
          enabled: true,
          customLogHandler: (entry) => customLogs.add(entry),
        );
        final customLogger = AuditLogger(customConfig);

        customLogger.logAccess(secretName: 'testSecret', success: true);

        expect(customLogs, hasLength(1));
        expect(customLogs.first.eventType, equals(AccessEventType.success));

        customLogger.dispose();
      });
    });

    group('AnalyticsObfuscatedValue', () {
      test('logs access when value is retrieved', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final analyticsValue = originalValue.withAnalytics(
          logger,
          'testSecret',
        );

        // Access the value
        final value = analyticsValue.value;
        expect(value, equals('test-secret'));

        // Check that access was logged
        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.first.eventType, equals(AccessEventType.success));
      });

      test('logs access failure when decryption fails', () {
        // Create a corrupted secret that will fail to decrypt
        final corruptedSecret = Secret(
          data: Uint8List.fromList([1, 2, 3, 4]), // Invalid data
          nonce: 12345,
        );
        final corruptedValue = _MockObfuscatedValue<String>(
          corruptedSecret,
          (data, nonce) => throw Exception('Decryption failed'),
        );

        final analyticsValue = corruptedValue.withAnalytics(
          logger,
          'corruptedSecret',
        );

        // Try to access the value (should fail)
        expect(() => analyticsValue.value, throwsException);

        // Check that failure was logged
        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.first.eventType, equals(AccessEventType.failure));
        expect(logs.first.severity, equals(AuditSeverity.warning));
      });

      test('provides access statistics', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final analyticsValue = originalValue.withAnalytics(
          logger,
          'testSecret',
        );

        // Access multiple times
        for (int i = 0; i < 3; i++) {
          analyticsValue.value;
        }

        final stats = analyticsValue.stats;
        expect(stats, isNotNull);
        expect(stats!.successfulAccesses, equals(3));
        expect(stats.totalAccesses, equals(3));
      });
    });

    group('AnalyticsObfuscatedFactory', () {
      test('creates analytics-aware values', () {
        final factory = AnalyticsObfuscatedFactory(logger);

        final stringValue = 'test'.obfuscate(algorithm: 'aes-256-gcm');
        final analyticsString = factory.string('testString', stringValue);

        expect(analyticsString.secretName, equals('testString'));
        expect(analyticsString.logger, equals(logger));

        // Test access logging
        analyticsString.value;
        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));
      });

      test('creates different types of analytics values', () {
        final factory = AnalyticsObfuscatedFactory(logger);

        final intValue = 42.obfuscate(algorithm: 'aes-256-gcm');
        final boolValue = true.obfuscate(algorithm: 'aes-256-gcm');
        final listValue = ['a', 'b'].obfuscate(algorithm: 'aes-256-gcm');

        final analyticsInt = factory.integer('testInt', intValue);
        final analyticsBool = factory.boolean('testBool', boolValue);
        final analyticsList = factory.list('testList', listValue);

        expect(analyticsInt.value, equals(42));
        expect(analyticsBool.value, isTrue);
        expect(analyticsList.value, equals(['a', 'b']));

        // Should have logged 3 accesses
        final logs = logger.getRecentLogs();
        expect(logs.length, equals(3));
      });
    });

    group('AnalyticsSecretManager', () {
      test('manages secrets with analytics', () {
        final manager = AnalyticsSecretManager(logger);

        final secret = 'test-value'.obfuscate(algorithm: 'aes-256-gcm');
        manager.registerSecret('testSecret', secret);

        // Check registration was logged
        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.first.eventType, equals(AccessEventType.modification));
        expect(logs.first.message, contains('registered'));

        // Access secret
        final value = manager.getSecretValue<String>('testSecret');
        expect(value, equals('test-value'));

        // Should have logged access
        final allLogs = logger.getRecentLogs();
        expect(allLogs.length, equals(2));
      });

      test('tracks secret removal', () {
        final manager = AnalyticsSecretManager(logger);

        final secret = 'test-value'.obfuscate(algorithm: 'aes-256-gcm');
        manager.registerSecret('testSecret', secret);
        manager.removeSecret('testSecret');

        final logs = logger.getRecentLogs();
        expect(logs.length, equals(2));
        expect(
          logs.first.eventType,
          equals(AccessEventType.deletion),
        ); // removal (most recent)
        expect(
          logs.last.eventType,
          equals(AccessEventType.modification),
        ); // registration (older)
      });
    });

    group('AnalyticsReporter', () {
      test('generates analytics reports', () async {
        final reporter = AnalyticsReporter(logger);

        // Add some test data
        logger.logAccess(secretName: 'secret1', success: true);
        logger.logAccess(secretName: 'secret1', success: true);
        logger.logAccess(secretName: 'secret2', success: false);

        final report = reporter.generateReport();

        expect(report.totalSecrets, equals(2));
        expect(report.totalAccesses, equals(3));
        expect(report.successfulAccesses, equals(2));
        expect(report.failedAccesses, equals(1));
        expect(report.successRate, closeTo(66.7, 0.1));

        reporter.dispose();
      });

      test('streams periodic reports', () async {
        final reporter = AnalyticsReporter(
          logger,
          reportInterval: const Duration(milliseconds: 100),
        );

        final reports = <AnalyticsReport>[];
        final subscription = reporter.reports.listen((report) {
          reports.add(report);
        });

        reporter.startReporting();

        // Add some data
        logger.logAccess(secretName: 'testSecret', success: true);

        // Wait for a few reports
        await Future.delayed(const Duration(milliseconds: 250));

        expect(reports.length, greaterThan(1));

        reporter.stopReporting();
        subscription.cancel();
        reporter.dispose();
      });
    });

    group('Extension Methods', () {
      test('withAnalytics extension', () {
        final originalValue = 'test-secret'.obfuscate(algorithm: 'aes-256-gcm');
        final analyticsValue = originalValue.withAnalytics(
          logger,
          'testSecret',
        );

        expect(analyticsValue, isA<AnalyticsObfuscatedValue<String>>());
        expect(analyticsValue.secretName, equals('testSecret'));

        // Test access logging
        analyticsValue.value;
        final logs = logger.getRecentLogs();
        expect(logs, hasLength(1));
      });
    });
  });
}

// Mock implementation for testing
class _MockObfuscatedValue<T> implements ObfuscatedValue<T> {
  final Secret _secret;
  final T Function(Uint8List, int) _deobfuscate;

  _MockObfuscatedValue(this._secret, this._deobfuscate);

  @override
  T get value => _deobfuscate(_secret.data, _secret.nonce);

  @override
  T get $ => value;

  @override
  Secret get secret => _secret;

  @override
  T Function(Uint8List, int) get deobfuscate => _deobfuscate;
}
