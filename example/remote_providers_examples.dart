/// Examples demonstrating remote secret provider integrations.
library;

import 'dart:async';
import 'dart:io';

import 'package:confidential/src/async/async_obfuscated.dart';
import 'package:confidential/src/remote/aws_secrets_manager.dart';
import 'package:confidential/src/remote/cached_remote_provider.dart';
import 'package:confidential/src/remote/google_secret_manager.dart';
import 'package:confidential/src/remote/hashicorp_vault.dart';
// Import only the specific modules we need to avoid Flutter dependencies
import 'package:confidential/src/remote/remote_secret_provider.dart';

/// Example demonstrating AWS Secrets Manager integration.
Future<void> awsSecretsManagerExample() async {
  print('=== AWS Secrets Manager Example ===');

  // Configure AWS Secrets Manager
  final awsConfig = RemoteSecretConfig.aws(
    accessKeyId: 'AKIA...', // Your AWS Access Key ID
    secretAccessKey: 'your-secret-access-key',
    sessionToken: 'optional-session-token', // For temporary credentials
    region: 'us-east-1',
    cacheExpiration: Duration(minutes: 15),
  );

  final awsProvider = AwsSecretsManagerProvider(config: awsConfig);

  try {
    // Test connection
    print('Testing AWS connection...');
    final isConnected = await awsProvider.testConnection();
    print('AWS connection: ${isConnected ? "✅ Success" : "❌ Failed"}');

    if (isConnected) {
      // List available secrets
      print('\nListing AWS secrets...');
      final secrets = await awsProvider.listSecrets();
      print('Found ${secrets.length} secrets: $secrets');

      // Get a specific secret (example)
      if (secrets.isNotEmpty) {
        final secretName = secrets.first;
        print('\nGetting secret: $secretName');

        final secretValue = await awsProvider.getSecretValue(secretName);
        if (secretValue != null) {
          print('Secret value: ${secretValue.value.substring(0, 10)}...');
          print('Secret version: ${secretValue.metadata.version}');
          print('Created at: ${secretValue.metadata.createdAt}');
        }
      }

      // Create a new secret (example)
      print('\nCreating a new secret...');
      await awsProvider.putSecret(
        'example-api-key',
        'sk-1234567890abcdef',
        description: 'Example API key for testing',
        tags: {'Environment': 'Development', 'Team': 'Backend'},
      );
      print('✅ Secret created successfully');

      // Get health status
      final health = await awsProvider.getHealthStatus();
      print('\nAWS Health Status: ${health['status']}');
      print('Response time: ${health['responseTime']}ms');
    }
  } catch (e) {
    print('❌ AWS Error: $e');
  } finally {
    awsProvider.close();
  }

  print('✅ AWS Secrets Manager example completed\n');
}

/// Example demonstrating Google Secret Manager integration.
Future<void> googleSecretManagerExample() async {
  print('=== Google Secret Manager Example ===');

  // Configure Google Secret Manager
  final googleConfig = RemoteSecretConfig.gcp(
    projectId: 'your-gcp-project-id',
    serviceAccountKey: 'your-service-account-key-json',
    // OR use access token:
    // accessToken: 'your-oauth-access-token',
    cacheExpiration: Duration(minutes: 10),
  );

  final googleProvider = GoogleSecretManagerProvider(config: googleConfig);

  try {
    // Test connection
    print('Testing Google Cloud connection...');
    final isConnected = await googleProvider.testConnection();
    print('Google connection: ${isConnected ? "✅ Success" : "❌ Failed"}');

    if (isConnected) {
      // List available secrets
      print('\nListing Google secrets...');
      final secrets = await googleProvider.listSecrets();
      print('Found ${secrets.length} secrets: $secrets');

      // Get secrets with metadata
      print('\nGetting secrets with metadata...');
      final secretsMetadata = await googleProvider.listSecretsWithMetadata();
      for (final metadata in secretsMetadata.take(3)) {
        print('Secret: ${metadata.name}');
        print('  Created: ${metadata.createdAt}');
        print('  Tags: ${metadata.tags}');
      }

      // Create a new secret (example)
      print('\nCreating a new secret...');
      await googleProvider.putSecret(
        'example-database-password',
        'super-secure-password-123',
        tags: {'env': 'development', 'type': 'database'},
      );
      print('✅ Secret created successfully');

      // Get health status
      final health = await googleProvider.getHealthStatus();
      print('\nGoogle Health Status: ${health['status']}');
      print('Project ID: ${health['projectId']}');
      print('Response time: ${health['responseTime']}ms');
    }
  } catch (e) {
    print('❌ Google Error: $e');
  } finally {
    googleProvider.close();
  }

  print('✅ Google Secret Manager example completed\n');
}

/// Example demonstrating HashiCorp Vault integration.
Future<void> hashiCorpVaultExample() async {
  print('=== HashiCorp Vault Example ===');

  // Configure HashiCorp Vault
  final vaultConfig = RemoteSecretConfig.vault(
    address: 'https://vault.example.com:8200',
    token: 'hvs.your-vault-token',
    namespace: 'admin', // Optional
    mountPath: 'secret', // KV mount path
    cacheExpiration: Duration(minutes: 5),
  );

  final vaultProvider = HashiCorpVaultProvider(config: vaultConfig);

  try {
    // Test connection
    print('Testing Vault connection...');
    final isConnected = await vaultProvider.testConnection();
    print('Vault connection: ${isConnected ? "✅ Success" : "❌ Failed"}');

    if (isConnected) {
      // List available secrets
      print('\nListing Vault secrets...');
      final secrets = await vaultProvider.listSecrets();
      print('Found ${secrets.length} secrets: $secrets');

      // Get a specific secret (example)
      if (secrets.isNotEmpty) {
        final secretName = secrets.first;
        print('\nGetting secret: $secretName');

        final secretValue = await vaultProvider.getSecretValue(secretName);
        if (secretValue != null) {
          print('Secret data: ${secretValue.value.substring(0, 50)}...');
          print('Secret version: ${secretValue.metadata.version}');
        }
      }

      // Create a new secret with structured data
      print('\nCreating a structured secret...');
      final secretData = {
        'username': 'admin',
        'password': 'secure-password-456',
        'host': 'database.example.com',
        'port': 5432,
      };

      await vaultProvider.putSecret(
        'database-config',
        secretData.toString(), // In real usage, use jsonEncode(secretData)
        tags: {'environment': 'production', 'service': 'database'},
      );
      print('✅ Structured secret created successfully');

      // Get health status
      final health = await vaultProvider.getHealthStatus();
      print('\nVault Health Status: ${health['status']}');
      print('Address: ${health['address']}');
      print('Response time: ${health['responseTime']}ms');
    }
  } catch (e) {
    print('❌ Vault Error: $e');
  } finally {
    vaultProvider.close();
  }

  print('✅ HashiCorp Vault example completed\n');
}

/// Example demonstrating local caching with remote providers.
Future<void> localCachingExample() async {
  print('=== Local Caching Example ===');

  // Create temporary directory for cache
  final tempDir = await Directory.systemTemp.createTemp('cache_example');

  try {
    // Configure local cache
    final cacheConfig = LocalCacheConfig(
      enabled: true,
      cacheDirectory: '${tempDir.path}/secret_cache',
      maxCacheSize: 10 * 1024 * 1024, // 10MB
      expiration: Duration(minutes: 30),
      encryptCache: true,
      compressCache: true,
      maxCachedSecrets: 100,
    );

    // Create cached AWS provider
    final awsConfig = RemoteSecretConfig.aws(
      accessKeyId: 'AKIA...',
      secretAccessKey: 'your-secret-access-key',
      region: 'us-east-1',
    );

    final cachedProvider = await CachedRemoteProviderFactory.createAwsProvider(
      config: awsConfig,
      cacheConfig: cacheConfig,
      cacheFirst: true,
      backgroundRefresh: true,
    );

    print('Created cached AWS provider with local caching');

    // Simulate secret access (would normally fetch from AWS)
    print('\nSimulating secret access...');

    // First access - would fetch from remote and cache
    print('First access (cache miss):');
    try {
      final secret1 = await cachedProvider.getSecretValue('example-secret');
      print('Secret retrieved: ${secret1 != null ? "✅" : "❌"}');
    } catch (e) {
      print('Expected error (no real AWS credentials): $e');
    }

    // Get cache statistics
    final stats = await cachedProvider.getCacheStatistics();
    if (stats != null) {
      print('\nCache Statistics:');
      print('Total entries: ${stats.totalEntries}');
      print('Total size: ${stats.totalSize} bytes');
      print('Hit rate: ${(stats.hitRate * 100).toStringAsFixed(1)}%');
      print('Hits: ${stats.hits}, Misses: ${stats.misses}');
    }

    // Validate cache integrity
    final validation = await cachedProvider.validateCache();
    if (validation != null) {
      print('\nCache Validation:');
      print('Valid entries: ${validation['validEntries']}');
      print('Corrupted entries: ${validation['corruptedEntries']}');
      print('Issues: ${validation['issues']}');
    }

    // Clean up cache
    final cleaned = await cachedProvider.cleanupCache();
    print('\nCleaned up $cleaned expired cache entries');

    cachedProvider.dispose();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('✅ Local caching example completed\n');
}

/// Example demonstrating async obfuscated values with remote providers.
Future<void> asyncObfuscatedRemoteExample() async {
  print('=== Async Obfuscated Remote Example ===');

  // Create a mock remote provider for demonstration
  final tempDir = await Directory.systemTemp.createTemp('async_remote');

  try {
    // Configure Vault provider
    final vaultConfig = RemoteSecretConfig.vault(
      address: 'http://localhost:8200',
      token: 'dev-token',
      mountPath: 'secret',
    );

    final vaultProvider = HashiCorpVaultProvider(config: vaultConfig);

    // Create async obfuscated factory with remote provider
    final asyncFactory = AsyncObfuscatedFactory(
      provider: vaultProvider,
      defaultAlgorithm: 'aes-256-gcm',
    );

    print('Created async obfuscated factory with Vault provider');

    // Create async obfuscated values
    final apiKey = asyncFactory.string('api-key');
    final databaseUrl = asyncFactory.string('database-url');
    final config = asyncFactory.string('app-config');

    print('\nCreated async obfuscated values for remote secrets');

    // Simulate usage (would normally fetch from Vault)
    print('\nSimulating async secret access...');

    try {
      // These would normally fetch from Vault and decrypt
      print('API Key: ${(await apiKey.value).substring(0, 10)}...');
      print('Database URL: ${(await databaseUrl.value).substring(0, 20)}...');
      print('Config: ${(await config.value).substring(0, 15)}...');

      // Map values for transformation
      final maskedApiKey = apiKey.map(
        (value) => '***${value.substring(value.length - 4)}',
      );
      print('\nMasked API Key: ${await maskedApiKey.value}');
    } catch (e) {
      print('Expected error (no real Vault instance): $e');
    }

    vaultProvider.close();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('✅ Async obfuscated remote example completed\n');
}

/// Example demonstrating multi-provider fallback.
Future<void> multiProviderFallbackExample() async {
  print('=== Multi-Provider Fallback Example ===');

  // Configure multiple providers
  final awsConfig = RemoteSecretConfig.aws(
    accessKeyId: 'AKIA...',
    secretAccessKey: 'aws-secret',
    region: 'us-east-1',
  );

  final vaultConfig = RemoteSecretConfig.vault(
    address: 'http://localhost:8200',
    token: 'vault-token',
  );

  final googleConfig = RemoteSecretConfig.gcp(
    projectId: 'gcp-project',
    accessToken: 'gcp-token',
  );

  // Create providers
  final awsProvider = AwsSecretsManagerProvider(config: awsConfig);
  final vaultProvider = HashiCorpVaultProvider(config: vaultConfig);
  final googleProvider = GoogleSecretManagerProvider(config: googleConfig);

  print('Created multiple remote providers');

  // Test each provider's health
  print('\nTesting provider health:');

  final awsHealth = await awsProvider.testConnection();
  print('AWS: ${awsHealth ? "✅ Healthy" : "❌ Unhealthy"}');

  final vaultHealth = await vaultProvider.testConnection();
  print('Vault: ${vaultHealth ? "✅ Healthy" : "❌ Unhealthy"}');

  final googleHealth = await googleProvider.testConnection();
  print('Google: ${googleHealth ? "✅ Healthy" : "❌ Unhealthy"}');

  // In a real application, you could implement a composite provider
  // that tries providers in order until one succeeds
  print('\nIn production, you could implement a CompositeRemoteProvider');
  print('that tries providers in order: AWS → Vault → Google');

  // Clean up
  awsProvider.close();
  vaultProvider.close();
  googleProvider.close();

  print('✅ Multi-provider fallback example completed\n');
}

/// Example demonstrating secret rotation with remote providers.
Future<void> secretRotationRemoteExample() async {
  print('=== Secret Rotation with Remote Providers Example ===');

  final vaultConfig = RemoteSecretConfig.vault(
    address: 'http://localhost:8200',
    token: 'rotation-token',
    mountPath: 'secret',
  );

  final vaultProvider = HashiCorpVaultProvider(config: vaultConfig);

  try {
    print('Setting up secret rotation with Vault...');

    // Simulate secret rotation workflow
    final secretName = 'rotating-api-key';

    print('\n1. Creating initial secret...');
    await vaultProvider.putSecret(
      secretName,
      'initial-api-key-value',
      tags: {'rotation': 'enabled', 'version': '1'},
    );

    print('2. Simulating secret rotation...');
    await vaultProvider.putSecret(
      secretName,
      'rotated-api-key-value',
      tags: {'rotation': 'enabled', 'version': '2'},
    );

    print('3. Getting rotated secret...');
    final rotatedSecret = await vaultProvider.getSecretValue(secretName);
    if (rotatedSecret != null) {
      print('Rotated secret version: ${rotatedSecret.metadata.version}');
      print('Secret value: ${rotatedSecret.value.substring(0, 15)}...');
    }

    print('✅ Secret rotation workflow completed');
  } catch (e) {
    print('Expected error (no real Vault instance): $e');
  } finally {
    vaultProvider.close();
  }

  print('✅ Secret rotation remote example completed\n');
}

/// Main function to run all examples.
Future<void> main() async {
  print('📦 Remote Secret Providers Examples\n');

  await awsSecretsManagerExample();
  await googleSecretManagerExample();
  await hashiCorpVaultExample();
  await localCachingExample();
  await asyncObfuscatedRemoteExample();
  await multiProviderFallbackExample();
  await secretRotationRemoteExample();

  print('🎉 All remote provider examples completed successfully!');
  print('\n💡 Note: Most examples show expected errors since they require');
  print('   real credentials and running services. In production, provide');
  print('   valid credentials and ensure services are accessible.');
}
