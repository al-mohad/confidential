/// Example demonstrating the enhanced API ergonomics features.
library;

import 'dart:io';
import 'package:confidential/confidential.dart';

void main() async {
  print('🧼 Dart Confidential - Enhanced API Ergonomics Example\n');

  // Example 1: Extension Methods for Easy Encryption
  await demonstrateExtensionMethods();

  // Example 2: Secret Grouping and Organization
  await demonstrateSecretGrouping();

  // Example 3: Asynchronous Secret Loading
  await demonstrateAsyncSecretLoading();

  // Example 4: Advanced Secret Management
  await demonstrateAdvancedSecretManagement();
}

/// Demonstrates the new extension methods for encryption.
Future<void> demonstrateExtensionMethods() async {
  print('📦 Extension Methods Demo');
  print('=' * 40);

  // String encryption with extension methods
  const secretMessage = 'Hello, Enhanced World!';
  print('Original: $secretMessage');

  // Encrypt using extension method
  final encryptedSecret = secretMessage.encrypt(
    algorithm: 'aes-256-gcm',
    nonce: 12345,
  );
  print('Encrypted: ${encryptedSecret.toHex()}');

  // Decrypt using extension method
  final decrypted = encryptedSecret.decryptAsString(algorithm: 'aes-256-gcm');
  print('Decrypted: $decrypted');

  // Create obfuscated value directly
  final obfuscated = secretMessage.obfuscate(algorithm: 'aes-256-gcm');
  print('Obfuscated value: ${obfuscated.value}');
  print('Using \$ syntax: ${obfuscated.$}');

  // List encryption
  const apiEndpoints = [
    'https://api.example.com/v1',
    'https://api.example.com/v2',
    'https://backup-api.example.com/v1',
  ];
  
  final encryptedList = apiEndpoints.encrypt(algorithm: 'chacha20-poly1305');
  final decryptedList = encryptedList.decryptAsStringList(algorithm: 'chacha20-poly1305');
  print('List encryption works: ${decryptedList.length == apiEndpoints.length}');

  // Map encryption
  const config = {
    'database': 'postgresql://localhost:5432/mydb',
    'redis': 'redis://localhost:6379',
    'timeout': '30000',
  };
  
  final encryptedMap = config.encrypt(algorithm: 'aes-256-gcm');
  final decryptedMap = encryptedMap.decryptAsMap(algorithm: 'aes-256-gcm');
  print('Map encryption works: ${decryptedMap.keys.length == config.keys.length}');

  // Integer and boolean encryption
  const secretNumber = 42;
  const secretFlag = true;
  
  final obfuscatedNumber = secretNumber.obfuscate(algorithm: 'aes-256-gcm');
  final obfuscatedFlag = secretFlag.obfuscate(algorithm: 'aes-256-gcm');
  
  print('Number: ${obfuscatedNumber.value}, Flag: ${obfuscatedFlag.value}');

  // Advanced ObfuscatedValue operations
  final mappedValue = obfuscated.map<int>((s) => s.length);
  print('Mapped value (length): ${mappedValue.value}');
  
  print('Is string type: ${obfuscated.isType<String>()}');
  print('Safe cast to string: ${obfuscated.safeCast<String>()}');
  print('Safe cast to int: ${obfuscated.safeCast<int>()}');

  print('\n');
}

/// Demonstrates secret grouping and organization.
Future<void> demonstrateSecretGrouping() async {
  print('🗂️  Secret Grouping Demo');
  print('=' * 40);

  // Create grouped secrets
  final apiSecrets = [
    GroupedSecretDefinition(
      name: 'primaryApiKey',
      value: 'pk_live_secret_key_123',
      group: 'api',
      tags: ['critical', 'production', 'auth'],
      description: 'Primary API key for production',
      environment: 'production',
      priority: 10,
    ),
    GroupedSecretDefinition(
      name: 'secondaryApiKey',
      value: 'pk_live_backup_key_456',
      group: 'api',
      tags: ['backup', 'production', 'auth'],
      description: 'Backup API key for failover',
      environment: 'production',
      priority: 8,
    ),
    GroupedSecretDefinition(
      name: 'testApiKey',
      value: 'pk_test_key_789',
      group: 'api',
      tags: ['testing', 'development'],
      description: 'API key for testing',
      environment: 'development',
      priority: 5,
      deprecated: true,
    ),
  ];

  final databaseSecrets = [
    GroupedSecretDefinition(
      name: 'primaryDbUrl',
      value: 'postgresql://user:pass@prod-db:5432/app',
      group: 'database',
      tags: ['critical', 'production', 'connection'],
      description: 'Primary database connection',
      environment: 'production',
      priority: 10,
    ),
    GroupedSecretDefinition(
      name: 'readOnlyDbUrl',
      value: 'postgresql://readonly:pass@replica-db:5432/app',
      group: 'database',
      tags: ['readonly', 'production', 'connection'],
      description: 'Read-only database connection',
      environment: 'production',
      priority: 7,
    ),
  ];

  // Create secret groups
  final apiGroup = SecretGroup(
    name: 'apiSecrets',
    description: 'API authentication and configuration',
    namespace: 'create ApiSecrets',
    tags: ['api', 'external'],
    secrets: apiSecrets,
  );

  final dbGroup = SecretGroup(
    name: 'databaseSecrets',
    description: 'Database connections and credentials',
    namespace: 'create DatabaseSecrets',
    tags: ['database', 'internal'],
    secrets: databaseSecrets,
  );

  // Create group manager
  final groupManager = SecretGroupManager(groups: [apiGroup, dbGroup]);

  print('Total secrets: ${groupManager.allSecrets.length}');
  print('Groups: ${groupManager.groupNames.join(', ')}');
  print('All tags: ${groupManager.allTags.join(', ')}');
  print('Environments: ${groupManager.allEnvironments.join(', ')}');

  // Filter secrets by various criteria
  final productionSecrets = groupManager.getSecrets(
    SecretFilter.environment('production'),
  );
  print('Production secrets: ${productionSecrets.length}');

  final criticalSecrets = groupManager.getSecrets(
    SecretFilter.tags(['critical']),
  );
  print('Critical secrets: ${criticalSecrets.length}');

  final nonDeprecatedSecrets = groupManager.getSecrets(
    SecretFilter.excludeDeprecated(),
  );
  print('Non-deprecated secrets: ${nonDeprecatedSecrets.length}');

  // Get secrets by group
  final apiGroupSecrets = groupManager.getSecretsByGroup('apiSecrets');
  print('API group secrets: ${apiGroupSecrets.map((s) => s.name).join(', ')}');

  // Get secrets sorted by priority
  final sortedSecrets = apiGroup.secretsByPriority;
  print('API secrets by priority: ${sortedSecrets.map((s) => '${s.name}(${s.priority})').join(', ')}');

  print('\n');
}

/// Demonstrates asynchronous secret loading.
Future<void> demonstrateAsyncSecretLoading() async {
  print('🔄 Async Secret Loading Demo');
  print('=' * 40);

  // Create temporary directory for file-based secrets
  final tempDir = await Directory.systemTemp.createTemp('confidential_demo');
  
  try {
    // Create file-based secret provider
    final fileProvider = FileSecretProvider(
      basePath: tempDir.path,
      config: const SecretProviderConfig(
        timeout: Duration(seconds: 10),
        retryAttempts: 3,
        enableCaching: true,
        cacheExpiration: Duration(minutes: 5),
      ),
    );

    // Save some test secrets
    await fileProvider.saveSecret(
      'apiKey',
      'super-secret-api-key'.encrypt(algorithm: 'aes-256-gcm', nonce: 11111),
    );
    
    await fileProvider.saveSecret(
      'databaseUrl',
      'postgresql://localhost:5432/mydb'.encrypt(algorithm: 'aes-256-gcm', nonce: 22222),
    );

    await fileProvider.saveSecret(
      'config',
      {'timeout': 30000, 'retries': 3}.encrypt(algorithm: 'aes-256-gcm', nonce: 33333),
    );

    // Create async obfuscated values
    final factory = AsyncObfuscatedFactory(provider: fileProvider);
    
    final asyncApiKey = factory.string('apiKey');
    final asyncDbUrl = factory.string('databaseUrl');
    final asyncConfig = factory.map('config');

    // Load secrets asynchronously
    print('Loading API key...');
    final apiKey = await asyncApiKey.value;
    print('API Key: $apiKey');

    print('Loading database URL...');
    final dbUrl = await asyncDbUrl.value;
    print('Database URL: $dbUrl');

    print('Loading configuration...');
    final config = await asyncConfig.value;
    print('Config: $config');

    // Demonstrate caching
    print('\nTesting cache (should be faster):');
    final start = DateTime.now();
    await asyncApiKey.value;
    final cached = DateTime.now().difference(start);
    print('Cached load time: ${cached.inMicroseconds}μs');

    // Test timeout and default values
    final valueWithTimeout = await asyncApiKey.getValueWithTimeout(
      const Duration(seconds: 1),
    );
    print('Value with timeout: $valueWithTimeout');

    final valueOrDefault = await asyncApiKey.getValueOrDefault('default-key');
    print('Value or default: $valueOrDefault');

    // Create async secret manager
    final manager = AsyncSecretManager(provider: fileProvider);
    manager.register('apiKey', asyncApiKey);
    manager.register('databaseUrl', asyncDbUrl);
    manager.register('config', asyncConfig);

    print('\nPreloading all secrets...');
    await manager.preloadAll();
    print('All secrets preloaded successfully!');

    // List all available secrets
    final availableSecrets = await fileProvider.listSecrets();
    print('Available secrets: ${availableSecrets.join(', ')}');

    // Test composite provider (multiple sources)
    final httpProvider = HttpSecretProvider(
      baseUrl: 'https://api.example.com', // This would fail in real usage
      headers: {'Authorization': 'Bearer token'},
    );

    final compositeProvider = CompositeSecretProvider([
      fileProvider,
      httpProvider, // Falls back to HTTP if file not found
    ]);

    // This will load from file provider since HTTP will fail
    final compositeSecret = await compositeProvider.loadSecret('apiKey');
    print('Composite provider loaded: ${compositeSecret != null}');

  } finally {
    // Clean up
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates advanced secret management features.
Future<void> demonstrateAdvancedSecretManagement() async {
  print('⚡ Advanced Secret Management Demo');
  print('=' * 40);

  // Create a complex configuration with groups
  final yaml = {
    'groups': [
      {
        'name': 'production',
        'description': 'Production environment secrets',
        'namespace': 'create ProductionSecrets',
        'tags': ['production', 'critical'],
        'environment': 'production',
        'secrets': [
          {
            'name': 'apiKey',
            'value': 'prod-api-key-123',
            'tags': ['api', 'auth'],
            'priority': 10,
          },
          {
            'name': 'dbPassword',
            'value': 'super-secure-password',
            'tags': ['database', 'auth'],
            'priority': 10,
          },
        ],
      },
      {
        'name': 'development',
        'description': 'Development environment secrets',
        'namespace': 'create DevSecrets',
        'tags': ['development', 'testing'],
        'environment': 'development',
        'secrets': [
          {
            'name': 'testApiKey',
            'value': 'test-api-key-456',
            'tags': ['api', 'testing'],
            'priority': 5,
          },
        ],
      },
    ],
    'namespaces': {
      'ProductionSecrets': 'create ProductionSecrets',
      'DevSecrets': 'create DevSecrets',
    },
    'namespaceMetadata': {
      'ProductionSecrets': {
        'group': 'production',
        'description': 'Production secrets namespace',
        'internal': true,
      },
      'DevSecrets': {
        'group': 'development',
        'description': 'Development secrets namespace',
        'internal': false,
      },
    },
  };

  // Create group manager from configuration
  final groupManager = SecretGroupManager.fromYaml(yaml);

  print('Created group manager with ${groupManager.groups.length} groups');
  
  // Advanced filtering
  final filters = [
    SecretFilter.environment('production'),
    SecretFilter.tags(['api']),
    SecretFilter.excludeDeprecated(),
    SecretFilter(
      tags: ['critical'],
      minPriority: 8,
    ),
  ];

  for (final filter in filters) {
    final filtered = groupManager.getSecrets(filter);
    print('Filter result: ${filtered.length} secrets');
  }

  // Demonstrate namespace grouping
  final namespaceGroups = groupManager.groupByNamespace('create DefaultSecrets');
  print('Namespace groups: ${namespaceGroups.keys.join(', ')}');

  // Show secret organization
  for (final group in groupManager.groups) {
    print('\nGroup: ${group.name}');
    print('  Description: ${group.description}');
    print('  Environment: ${group.environment}');
    print('  Tags: ${group.tags.join(', ')}');
    print('  Secrets: ${group.secrets.map((s) => s.name).join(', ')}');
    
    for (final secret in group.secrets) {
      print('    ${secret.name}: priority=${secret.priority}, tags=[${secret.tags.join(', ')}]');
    }
  }

  print('\n✅ All demos completed successfully!');
}
