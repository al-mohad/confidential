/// Examples demonstrating secret expiry and rotation features.
library;

import 'dart:async';
import 'dart:io';

// Import only the specific modules we need to avoid Flutter dependencies
import 'package:confidential/src/expiry/expirable_secret.dart';
import 'package:confidential/src/expiry/expirable_obfuscated.dart';
import 'package:confidential/src/expiry/secret_rotation_manager.dart';
import 'package:confidential/src/expiry/expiry_aware_providers.dart';
import 'package:confidential/src/expiry/expiry_extensions.dart';
import 'package:confidential/src/expiry/async_expirable.dart';
import 'package:confidential/src/extensions/encryption_extensions.dart';

/// Example demonstrating basic secret expiry functionality.
Future<void> basicExpiryExample() async {
  print('=== Basic Secret Expiry Example ===');

  // Create an expirable secret with TTL
  final expirableApiKey = 'sk-1234567890abcdef'.obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 24),
    secretName: 'apiKey',
    autoRefresh: true,
    refreshThreshold: Duration(minutes: 30),
  );

  print('API Key: ${expirableApiKey.value}');
  print('Expires at: ${expirableApiKey.expiresAt}');
  print('Time until expiry: ${expirableApiKey.timeUntilExpiry}');
  print('Is expired: ${expirableApiKey.isExpired}');
  print('Is near expiry: ${expirableApiKey.isNearExpiry}');

  // Set up expiry callback
  expirableApiKey.setExpiryCallback((name, secret) async {
    print('⚠️ Secret $name is expiring!');
    // Could send notification, log event, etc.
  });

  // Set up refresh callback
  expirableApiKey.setRefreshCallback((name, secret) async {
    print('🔄 Refreshing secret $name...');
    // In real app, fetch new token from API
    return 'sk-new-refreshed-token'.encrypt(algorithm: 'aes-256-gcm');
  });

  print('✅ Basic expiry example completed\n');
}

/// Example demonstrating OAuth token rotation.
Future<void> oauthTokenRotationExample() async {
  print('=== OAuth Token Rotation Example ===');

  // Simulate OAuth token with 1-hour expiry
  final oauthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'.obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 1),
    secretName: 'oauthToken',
    autoRefresh: true,
    refreshThreshold: Duration(minutes: 5), // Refresh 5 minutes before expiry
  );

  // Set up OAuth refresh callback
  oauthToken.setRefreshCallback((name, secret) async {
    print('🔄 Refreshing OAuth token...');

    // Simulate OAuth refresh request
    await Future.delayed(Duration(milliseconds: 500));

    // Return new token (in real app, call OAuth refresh endpoint)
    final newToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...refreshed';
    return newToken.encrypt(algorithm: 'aes-256-gcm');
  });

  print('OAuth Token: ${oauthToken.value.substring(0, 20)}...');
  print('Expires at: ${oauthToken.expiresAt}');

  // Simulate using the token
  for (int i = 0; i < 3; i++) {
    await Future.delayed(Duration(seconds: 1));
    print(
      'Making API call ${i + 1} with token: ${oauthToken.value.substring(0, 20)}...',
    );
  }

  print('✅ OAuth rotation example completed\n');
}

/// Example demonstrating secret rotation manager.
Future<void> rotationManagerExample() async {
  print('=== Secret Rotation Manager Example ===');

  // Create temporary directory for file provider
  final tempDir = await Directory.systemTemp.createTemp('rotation_example');
  final provider = ExpiryAwareFileSecretProvider(basePath: tempDir.path);

  try {
    // Configure rotation manager
    final rotationConfig = SecretRotationConfig(
      defaultTTL: Duration(minutes: 30),
      checkInterval: Duration(seconds: 10),
      autoRotate: true,
      maxConcurrentRotations: 3,
    );

    final rotationManager = SecretRotationManager(
      config: rotationConfig,
      secretProvider: provider,
    );

    // Listen to rotation events
    rotationManager.events.listen((event) {
      print('📡 Rotation Event: ${event.type.name} for ${event.secretName}');
      if (event.error != null) {
        print('   Error: ${event.error}');
      }
    });

    // Create multiple expirable secrets
    final secrets = [
      'database-password'.obfuscateWithTTL(
        algorithm: 'aes-256-gcm',
        ttl: Duration(minutes: 15),
        secretName: 'dbPassword',
      ),
      'api-key-12345'.obfuscateWithTTL(
        algorithm: 'aes-256-gcm',
        ttl: Duration(minutes: 20),
        secretName: 'apiKey',
      ),
      'jwt-secret'.obfuscateWithTTL(
        algorithm: 'aes-256-gcm',
        ttl: Duration(minutes: 25),
        secretName: 'jwtSecret',
      ),
    ];

    // Register secrets with rotation manager
    final secretNames = ['dbPassword', 'apiKey', 'jwtSecret'];
    for (int i = 0; i < secrets.length; i++) {
      rotationManager.registerSecret(secretNames[i], secrets[i]);
    }

    print('Registered ${secrets.length} secrets for rotation management');

    // Get rotation statistics
    final stats = rotationManager.getRotationStats();
    print('Rotation Stats: $stats');

    // List secrets by status
    final validSecrets = rotationManager.getSecretsByStatus(
      SecretExpiryStatus.valid,
    );
    print('Valid secrets: ${validSecrets.keys.toList()}');

    // Manually trigger rotation for one secret
    print('Manually rotating apiKey...');
    await rotationManager.rotateSecret('apiKey');

    // Wait a bit to see events
    await Future.delayed(Duration(seconds: 2));

    rotationManager.dispose();
    print('✅ Rotation manager example completed\n');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// Example demonstrating async expirable secrets.
Future<void> asyncExpirableExample() async {
  print('=== Async Expirable Secrets Example ===');

  // Create temporary directory for provider
  final tempDir = await Directory.systemTemp.createTemp('async_expirable');
  final provider = ExpiryAwareFileSecretProvider(basePath: tempDir.path);

  try {
    // Save some secrets with expiry metadata
    await provider.saveSecretWithExpiry(
      'userToken',
      'user-token-abc123'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      ttl: Duration(hours: 2),
      tags: ['user', 'authentication'],
      custom: {'userId': '12345', 'scope': 'read:profile'},
    );

    await provider.saveSecretWithExpiry(
      'adminToken',
      'admin-token-xyz789'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      ttl: Duration(hours: 8),
      tags: ['admin', 'authentication'],
      custom: {'userId': '1', 'scope': 'admin:all'},
    );

    // Create async expirable factory
    final factory = AsyncExpirableObfuscatedFactory(
      provider: provider,
      defaultAlgorithm: 'aes-256-gcm',
      defaultExpiryConfig: SecretExpiryConfig(
        ttl: Duration(hours: 4),
        autoRefresh: true,
      ),
    );

    // Create async expirable secrets
    final userToken = factory.string('userToken');
    final adminToken = factory.string('adminToken');

    // Listen to expiry events
    userToken.expiryEvents.listen((event) {
      print('🔔 User token event: ${event.type.name}');
    });

    // Use the async secrets
    print('User Token: ${await userToken.value}');
    print('Admin Token: ${await adminToken.value}');

    print('User token expires at: ${await userToken.expiresAt}');
    print('Admin token expires at: ${await adminToken.expiresAt}');

    print('User token is expired: ${await userToken.isExpired}');
    print('Admin token is near expiry: ${await adminToken.isNearExpiry}');

    // Test refresh
    print('Refreshing user token...');
    final refreshed = await userToken.refresh();
    print('Refresh successful: $refreshed');

    userToken.dispose();
    adminToken.dispose();
    print('✅ Async expirable example completed\n');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// Example demonstrating different data types with expiry.
Future<void> dataTypesExpiryExample() async {
  print('=== Data Types with Expiry Example ===');

  // String with expiry
  final expirableString = 'secret-message'.obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 1),
    secretName: 'message',
  );

  // Integer with expiry
  final expirableInt = 42.obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 2),
    secretName: 'magicNumber',
  );

  // List with expiry
  final expirableList = ['item1', 'item2', 'item3'].obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 3),
    secretName: 'itemList',
  );

  // Boolean with expiry
  final expirableBool = true.obfuscateWithTTL(
    algorithm: 'aes-256-gcm',
    ttl: Duration(hours: 4),
    secretName: 'isEnabled',
  );

  // Map with expiry
  final expirableMap =
      {
        'username': 'john_doe',
        'role': 'admin',
        'permissions': ['read', 'write', 'delete'],
      }.obfuscateWithTTL(
        algorithm: 'aes-256-gcm',
        ttl: Duration(hours: 5),
        secretName: 'userConfig',
      );

  print('String value: ${expirableString.value}');
  print('Integer value: ${expirableInt.value}');
  print('List value: ${expirableList.value}');
  print('Boolean value: ${expirableBool.value}');
  print('Map value: ${expirableMap.value}');

  print('String expires at: ${expirableString.expiresAt}');
  print('Integer expires at: ${expirableInt.expiresAt}');
  print('List expires at: ${expirableList.expiresAt}');
  print('Boolean expires at: ${expirableBool.expiresAt}');
  print('Map expires at: ${expirableMap.expiresAt}');

  print('✅ Data types expiry example completed\n');
}

/// Example demonstrating provider cleanup operations.
Future<void> providerCleanupExample() async {
  print('=== Provider Cleanup Example ===');

  // Create temporary directory for provider
  final tempDir = await Directory.systemTemp.createTemp('cleanup_example');
  final provider = ExpiryAwareFileSecretProvider(basePath: tempDir.path);

  try {
    // Save some secrets with different expiry times
    await provider.saveSecretWithExpiry(
      'expiredSecret1',
      'expired-value-1'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      expiresAt: DateTime.now().subtract(Duration(hours: 1)),
    );

    await provider.saveSecretWithExpiry(
      'expiredSecret2',
      'expired-value-2'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      expiresAt: DateTime.now().subtract(Duration(minutes: 30)),
    );

    await provider.saveSecretWithExpiry(
      'validSecret',
      'valid-value'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      ttl: Duration(hours: 24),
    );

    await provider.saveSecretWithExpiry(
      'soonToExpire',
      'soon-to-expire'.encrypt(algorithm: 'aes-256-gcm'),
      'aes-256-gcm',
      ttl: Duration(minutes: 10),
    );

    // List all secrets
    final allSecrets = await provider.listSecrets();
    print('All secrets: $allSecrets');

    // List expired secrets
    final expiredSecrets = await provider.listExpiredSecrets();
    print('Expired secrets: $expiredSecrets');

    // List secrets expiring within 1 hour
    final expiringSoon = await provider.listSecretsExpiringWithin(
      Duration(hours: 1),
    );
    print('Secrets expiring within 1 hour: $expiringSoon');

    // Get metadata for a specific secret
    final metadata = await provider.getSecretMetadata('validSecret');
    print('Valid secret metadata: ${metadata?.toMap()}');

    // Cleanup expired secrets
    final cleanedCount = await provider.cleanupExpiredSecrets();
    print('Cleaned up $cleanedCount expired secrets');

    // Verify cleanup
    final remainingSecrets = await provider.listSecrets();
    print('Remaining secrets after cleanup: $remainingSecrets');

    print('✅ Provider cleanup example completed\n');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// Main function to run all examples.
Future<void> main() async {
  print('🔁 Secret Expiry and Rotation Examples\n');

  await basicExpiryExample();
  await oauthTokenRotationExample();
  await rotationManagerExample();
  await asyncExpirableExample();
  await dataTypesExpiryExample();
  await providerCleanupExample();

  print('🎉 All expiry examples completed successfully!');
}
