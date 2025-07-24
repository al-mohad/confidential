/// Example demonstrating analytics and audit logging functionality.
library;

import 'dart:async';

import 'package:confidential/confidential.dart';

void main() async {
  print('📊 Dart Confidential - Analytics & Audit Logging Example\n');

  // Example 1: Basic Analytics Configuration
  await demonstrateBasicAnalytics();

  // Example 2: Suspicious Behavior Detection
  await demonstrateSuspiciousDetection();

  // Example 3: Analytics-Aware Obfuscated Values
  await demonstrateAnalyticsObfuscatedValues();

  // Example 4: Secret Manager with Analytics
  await demonstrateSecretManagerAnalytics();

  // Example 5: Real-time Analytics Reporting
  await demonstrateRealtimeReporting();

  // Example 6: Configuration and Export/Import
  await demonstrateConfigurationAndExport();
}

/// Demonstrates basic analytics configuration and logging.
Future<void> demonstrateBasicAnalytics() async {
  print('📈 Basic Analytics Configuration');
  print('=' * 40);

  // Create analytics configuration for production
  final config = AnalyticsConfig.production();
  print('✅ Production analytics config:');
  print('  - Enabled: ${config.enabled}');
  print('  - Access counters: ${config.enableAccessCounters}');
  print('  - Suspicious detection: ${config.enableSuspiciousDetection}');
  print('  - Data anonymization: ${config.anonymizeData}');
  print('  - Max log entries: ${config.maxLogEntries}');

  // Create audit logger
  final logger = AuditLogger(config);

  // Log various types of events
  logger.logAccess(
    secretName: 'apiKey',
    success: true,
    metadata: {'type': 'String', 'algorithm': 'aes-256-gcm'},
  );

  logger.logAccess(
    secretName: 'databasePassword',
    success: false,
    error: 'Decryption failed - invalid nonce',
    metadata: {'type': 'String', 'algorithm': 'chacha20-poly1305'},
  );

  logger.logModification(
    secretName: 'apiKey',
    operation: 'updated',
    metadata: {'reason': 'key_rotation'},
  );

  // Get recent logs
  final logs = logger.getRecentLogs(limit: 5);
  print('\n📋 Recent audit logs:');
  for (final log in logs) {
    print('  [${log.severity.name.toUpperCase()}] ${log.timestamp.toIso8601String()}');
    print('    ${log.eventType.name}: ${log.message}');
    print('    Secret: ${log.secretId}');
  }

  // Get access statistics
  final stats = logger.getAllStats();
  print('\n📊 Access statistics:');
  for (final stat in stats.values) {
    print('  ${stat.secretId}:');
    print('    - Total accesses: ${stat.totalAccesses}');
    print('    - Success rate: ${stat.successRate.toStringAsFixed(1)}%');
    print('    - Suspicious events: ${stat.suspiciousEvents}');
  }

  logger.dispose();
  print('\n');
}

/// Demonstrates suspicious behavior detection.
Future<void> demonstrateSuspiciousDetection() async {
  print('🚨 Suspicious Behavior Detection');
  print('=' * 40);

  // Create configuration with aggressive suspicious detection
  final config = AnalyticsConfig(
    enabled: true,
    enableSuspiciousDetection: true,
    suspiciousTimeWindowMinutes: 1,
    maxAccessAttemptsPerWindow: 5,
    anonymizeData: true,
  );

  final logger = AuditLogger(config);

  // Set up suspicious event monitoring
  final suspiciousEvents = <AuditLogEntry>[];
  final subscription = logger.suspiciousEvents.listen((event) {
    suspiciousEvents.add(event);
    print('🚨 SUSPICIOUS ACTIVITY DETECTED:');
    print('  Secret: ${event.secretId}');
    print('  Message: ${event.message}');
    print('  Timestamp: ${event.timestamp.toIso8601String()}');
  });

  print('⏱️  Simulating rapid access attempts...');

  // Simulate rapid access attempts (should trigger suspicious detection)
  for (int i = 0; i < 8; i++) {
    logger.logAccess(
      secretName: 'sensitiveApiKey',
      success: true,
      metadata: {'attempt': i + 1},
    );
    
    // Small delay between attempts
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Wait for suspicious detection to process
  await Future.delayed(const Duration(milliseconds: 500));

  print('\n📊 Detection results:');
  print('  - Total access attempts: 8');
  print('  - Suspicious events detected: ${suspiciousEvents.length}');
  print('  - Threshold: ${config.maxAccessAttemptsPerWindow} attempts per ${config.suspiciousTimeWindowMinutes} minute(s)');

  if (suspiciousEvents.isNotEmpty) {
    print('  - First suspicious event: ${suspiciousEvents.first.message}');
  }

  subscription.cancel();
  logger.dispose();
  print('\n');
}

/// Demonstrates analytics-aware obfuscated values.
Future<void> demonstrateAnalyticsObfuscatedValues() async {
  print('🔍 Analytics-Aware Obfuscated Values');
  print('=' * 40);

  final config = AnalyticsConfig.development();
  final logger = AuditLogger(config);
  final factory = AnalyticsObfuscatedFactory(logger);

  // Create analytics-aware secrets
  final apiKey = 'sk_live_abc123def456'.obfuscate(algorithm: 'aes-256-gcm');
  final analyticsApiKey = factory.string('apiKey', apiKey);

  final databaseConfig = {
    'host': 'localhost',
    'port': 5432,
    'username': 'admin',
    'password': 'super_secret_password'
  }.obfuscate(algorithm: 'aes-256-gcm');
  final analyticsDatabaseConfig = factory.map('databaseConfig', databaseConfig);

  print('✅ Created analytics-aware secrets:');
  print('  - API Key: ${analyticsApiKey.secretName}');
  print('  - Database Config: ${analyticsDatabaseConfig.secretName}');

  // Access secrets multiple times
  print('\n🔄 Accessing secrets...');
  for (int i = 0; i < 3; i++) {
    final key = analyticsApiKey.value;
    final config = analyticsDatabaseConfig.value;
    
    print('  Access ${i + 1}:');
    print('    - API Key: ${key.substring(0, 10)}...');
    print('    - DB Host: ${config['host']}');
  }

  // Check access statistics
  print('\n📊 Access statistics:');
  final apiKeyStats = analyticsApiKey.stats;
  final dbConfigStats = analyticsDatabaseConfig.stats;

  if (apiKeyStats != null) {
    print('  API Key:');
    print('    - Total accesses: ${apiKeyStats.totalAccesses}');
    print('    - Success rate: ${apiKeyStats.successRate.toStringAsFixed(1)}%');
    print('    - First access: ${apiKeyStats.firstAccess?.toIso8601String()}');
    print('    - Last access: ${apiKeyStats.lastAccess?.toIso8601String()}');
  }

  if (dbConfigStats != null) {
    print('  Database Config:');
    print('    - Total accesses: ${dbConfigStats.totalAccesses}');
    print('    - Success rate: ${dbConfigStats.successRate.toStringAsFixed(1)}%');
  }

  logger.dispose();
  print('\n');
}

/// Demonstrates secret manager with analytics.
Future<void> demonstrateSecretManagerAnalytics() async {
  print('🗂️  Secret Manager with Analytics');
  print('=' * 40);

  final config = AnalyticsConfig(
    enabled: true,
    enableAccessCounters: true,
    logSuccessfulAccess: true,
    logFailedAccess: true,
  );

  final logger = AuditLogger(config);
  final manager = AnalyticsSecretManager(logger);

  // Register various secrets
  final secrets = {
    'jwtSecret': 'jwt_secret_key_12345'.obfuscate(algorithm: 'aes-256-gcm'),
    'encryptionKey': 'encryption_key_67890'.obfuscate(algorithm: 'chacha20-poly1305'),
    'apiToken': 'api_token_abcdef'.obfuscate(algorithm: 'aes-256-gcm'),
  };

  print('📝 Registering secrets...');
  for (final entry in secrets.entries) {
    manager.registerSecret(entry.key, entry.value);
    print('  ✅ Registered: ${entry.key}');
  }

  print('\n🔄 Accessing secrets...');
  // Access secrets with different patterns
  for (int i = 0; i < 5; i++) {
    manager.getSecretValue<String>('jwtSecret');
  }
  for (int i = 0; i < 3; i++) {
    manager.getSecretValue<String>('encryptionKey');
  }
  for (int i = 0; i < 7; i++) {
    manager.getSecretValue<String>('apiToken');
  }

  print('📊 Manager statistics:');
  print('  - Total secrets: ${manager.secretCount}');
  print('  - Secret names: ${manager.secretNames.join(', ')}');

  final allStats = manager.getAllStats();
  print('\n📈 Individual secret statistics:');
  for (final stat in allStats.values) {
    print('  ${stat.secretId}:');
    print('    - Accesses: ${stat.totalAccesses}');
    print('    - Success rate: ${stat.successRate.toStringAsFixed(1)}%');
  }

  // Demonstrate secret removal
  print('\n🗑️  Removing a secret...');
  manager.removeSecret('encryptionKey');
  print('  ✅ Removed: encryptionKey');
  print('  - Remaining secrets: ${manager.secretCount}');

  logger.dispose();
  print('\n');
}

/// Demonstrates real-time analytics reporting.
Future<void> demonstrateRealtimeReporting() async {
  print('📡 Real-time Analytics Reporting');
  print('=' * 40);

  final config = AnalyticsConfig.production();
  final logger = AuditLogger(config);
  final reporter = AnalyticsReporter(
    logger,
    reportInterval: const Duration(seconds: 2),
  );

  // Set up report monitoring
  final reports = <AnalyticsReport>[];
  final subscription = reporter.reports.listen((report) {
    reports.add(report);
    print('📊 Analytics Report ${reports.length}:');
    print('  - Timestamp: ${report.timestamp.toIso8601String()}');
    print('  - Total secrets: ${report.totalSecrets}');
    print('  - Total accesses: ${report.totalAccesses}');
    print('  - Success rate: ${report.successRate.toStringAsFixed(1)}%');
    print('  - Suspicious events: ${report.suspiciousEvents}');
    print('  - Security concerns: ${report.hasSecurityConcerns ? 'YES' : 'NO'}');
  });

  print('🚀 Starting real-time reporting...');
  reporter.startReporting();

  // Simulate activity over time
  print('⏱️  Simulating secret access activity...');
  
  for (int round = 1; round <= 3; round++) {
    print('\n  Round $round:');
    
    // Add some successful accesses
    for (int i = 0; i < 3; i++) {
      logger.logAccess(secretName: 'secret$round', success: true);
    }
    
    // Add a failed access
    logger.logAccess(
      secretName: 'secret$round',
      success: false,
      error: 'Invalid key',
    );
    
    // Add a modification
    logger.logModification(
      secretName: 'secret$round',
      operation: 'rotated',
    );
    
    print('    - Added 3 successful accesses, 1 failure, 1 modification');
    
    // Wait for next round
    await Future.delayed(const Duration(seconds: 2));
  }

  // Wait for final report
  await Future.delayed(const Duration(seconds: 3));

  print('\n📈 Final reporting summary:');
  print('  - Total reports generated: ${reports.length}');
  print('  - Reporting interval: 2 seconds');
  
  if (reports.isNotEmpty) {
    final finalReport = reports.last;
    print('  - Final total accesses: ${finalReport.totalAccesses}');
    print('  - Final success rate: ${finalReport.successRate.toStringAsFixed(1)}%');
  }

  reporter.stopReporting();
  subscription.cancel();
  reporter.dispose();
  logger.dispose();
  print('\n');
}

/// Demonstrates configuration and export/import functionality.
Future<void> demonstrateConfigurationAndExport() async {
  print('⚙️  Configuration and Export/Import');
  print('=' * 40);

  // Create custom configuration
  final customConfig = AnalyticsConfig(
    enabled: true,
    enableAccessCounters: true,
    enableSuspiciousDetection: true,
    anonymizeData: true,
    maxLogEntries: 100,
    suspiciousTimeWindowMinutes: 2,
    maxAccessAttemptsPerWindow: 10,
    logSuccessfulAccess: true,
    logFailedAccess: true,
  );

  print('⚙️  Custom configuration:');
  print('  - Max log entries: ${customConfig.maxLogEntries}');
  print('  - Suspicious window: ${customConfig.suspiciousTimeWindowMinutes} minutes');
  print('  - Max attempts per window: ${customConfig.maxAccessAttemptsPerWindow}');

  final logger = AuditLogger(customConfig);

  // Generate some test data
  print('\n📝 Generating test data...');
  for (int i = 0; i < 10; i++) {
    logger.logAccess(
      secretName: 'testSecret$i',
      success: i % 4 != 0, // 75% success rate
      error: i % 4 == 0 ? 'Test error $i' : null,
      metadata: {'iteration': i},
    );
  }

  logger.logModification(
    secretName: 'testSecret1',
    operation: 'updated',
    metadata: {'version': '2.0'},
  );

  logger.logDeletion(
    secretName: 'testSecret9',
    metadata: {'reason': 'cleanup'},
  );

  print('  ✅ Generated 10 access logs, 1 modification, 1 deletion');

  // Export logs
  print('\n📤 Exporting audit logs...');
  final exportedData = logger.exportLogsAsJson();
  final exportSize = exportedData.length;
  print('  ✅ Exported ${exportSize} characters of JSON data');

  // Create new logger and import
  print('\n📥 Importing to new logger...');
  final newLogger = AuditLogger(customConfig);
  newLogger.importLogsFromJson(exportedData);

  // Verify imported data
  final importedLogs = newLogger.getRecentLogs();
  final importedStats = newLogger.getAllStats();

  print('  ✅ Import verification:');
  print('    - Imported logs: ${importedLogs.length}');
  print('    - Imported stats: ${importedStats.length} secrets');

  // Show configuration as JSON
  print('\n⚙️  Configuration as JSON:');
  final configJson = customConfig.toJson();
  print('  ${configJson.toString()}');

  // Save to file (in real usage)
  print('\n💾 Export capabilities:');
  print('  - JSON export size: ${exportSize} bytes');
  print('  - Includes: logs, statistics, configuration');
  print('  - Can be saved to file or sent to external systems');
  print('  - Supports backup and restore workflows');

  logger.dispose();
  newLogger.dispose();
  print('\n✅ All analytics examples completed successfully!');
}
