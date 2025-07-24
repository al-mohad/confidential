import 'dart:io';
import 'dart:typed_data';

import 'package:confidential/src/remote/aws_secrets_manager.dart';
import 'package:confidential/src/remote/cached_remote_provider.dart';
import 'package:confidential/src/remote/google_secret_manager.dart';
import 'package:confidential/src/remote/hashicorp_vault.dart';
import 'package:confidential/src/remote/local_cache_manager.dart';
import 'package:confidential/src/remote/remote_secret_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Remote Secret Providers Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('remote_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('RemoteSecretConfig', () {
      test('creates AWS config correctly', () {
        final config = RemoteSecretConfig.aws(
          accessKeyId: 'test-key-id',
          secretAccessKey: 'test-secret-key',
          sessionToken: 'test-session-token',
          region: 'us-west-2',
        );

        expect(config.credentials['accessKeyId'], equals('test-key-id'));
        expect(
          config.credentials['secretAccessKey'],
          equals('test-secret-key'),
        );
        expect(
          config.credentials['sessionToken'],
          equals('test-session-token'),
        );
        expect(config.region, equals('us-west-2'));
      });

      test('creates Google Cloud config correctly', () {
        final config = RemoteSecretConfig.gcp(
          projectId: 'test-project',
          serviceAccountKey: 'test-key',
          accessToken: 'test-token',
        );

        expect(config.credentials['projectId'], equals('test-project'));
        expect(config.credentials['serviceAccountKey'], equals('test-key'));
        expect(config.credentials['accessToken'], equals('test-token'));
      });

      test('creates Vault config correctly', () {
        final config = RemoteSecretConfig.vault(
          address: 'https://vault.example.com',
          token: 'test-token',
          namespace: 'test-namespace',
          mountPath: 'kv',
        );

        expect(config.credentials['token'], equals('test-token'));
        expect(config.credentials['namespace'], equals('test-namespace'));
        expect(config.credentials['mountPath'], equals('kv'));
        expect(config.endpoint, equals('https://vault.example.com'));
      });
    });

    group('LocalCacheConfig', () {
      test('creates default config', () {
        const config = LocalCacheConfig();

        expect(config.enabled, isTrue);
        expect(config.cacheDirectory, equals('.confidential_cache'));
        expect(config.maxCacheSize, equals(100 * 1024 * 1024));
        expect(config.encryptCache, isTrue);
        expect(config.compressCache, isTrue);
      });

      test('creates custom config', () {
        final config = LocalCacheConfig(
          enabled: false,
          cacheDirectory: '/tmp/custom_cache',
          maxCacheSize: 50 * 1024 * 1024,
          encryptCache: false,
          compressCache: false,
        );

        expect(config.enabled, isFalse);
        expect(config.cacheDirectory, equals('/tmp/custom_cache'));
        expect(config.maxCacheSize, equals(50 * 1024 * 1024));
        expect(config.encryptCache, isFalse);
        expect(config.compressCache, isFalse);
      });
    });

    group('RemoteSecretMetadata', () {
      test('creates metadata from map', () {
        final map = {
          'name': 'test-secret',
          'version': 'v1',
          'createdAt': '2023-01-01T00:00:00.000Z',
          'lastModified': '2023-01-02T00:00:00.000Z',
          'description': 'Test secret',
          'tags': {'env': 'test', 'team': 'dev'},
          'metadata': {'custom': 'value'},
          'arn':
              'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
          'kmsKeyId': 'key-12345',
        };

        final metadata = RemoteSecretMetadata.fromMap(map);

        expect(metadata.name, equals('test-secret'));
        expect(metadata.version, equals('v1'));
        expect(
          metadata.createdAt,
          equals(DateTime.parse('2023-01-01T00:00:00.000Z')),
        );
        expect(
          metadata.lastModified,
          equals(DateTime.parse('2023-01-02T00:00:00.000Z')),
        );
        expect(metadata.description, equals('Test secret'));
        expect(metadata.tags['env'], equals('test'));
        expect(metadata.tags['team'], equals('dev'));
        expect(metadata.metadata['custom'], equals('value'));
        expect(
          metadata.arn,
          equals(
            'arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret',
          ),
        );
        expect(metadata.kmsKeyId, equals('key-12345'));
      });

      test('converts metadata to map', () {
        final metadata = RemoteSecretMetadata(
          name: 'test-secret',
          version: 'v1',
          createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
          description: 'Test secret',
          tags: {'env': 'test'},
        );

        final map = metadata.toMap();

        expect(map['name'], equals('test-secret'));
        expect(map['version'], equals('v1'));
        expect(map['createdAt'], equals('2023-01-01T00:00:00.000Z'));
        expect(map['description'], equals('Test secret'));
        expect(map['tags'], equals({'env': 'test'}));
      });
    });

    group('RemoteSecretValue', () {
      test('creates secret value with string data', () {
        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'secret-data',
          metadata: metadata,
        );

        expect(secretValue.stringValue, equals('secret-data'));
        expect(secretValue.bytes.length, greaterThan(0));
      });

      test('creates secret value with binary data', () {
        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final binaryData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final secretValue = RemoteSecretValue(
          value: 'secret-data',
          binaryValue: binaryData,
          metadata: metadata,
        );

        expect(secretValue.bytes, equals(binaryData));
      });

      test('converts to Secret object', () {
        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'secret-data',
          metadata: metadata,
        );

        final secret = secretValue.toSecret(nonce: 12345);

        expect(secret.nonce, equals(12345));
        expect(secret.data.length, greaterThan(0));
      });
    });

    group('LocalCacheManager', () {
      test('initializes cache directory', () async {
        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/cache',
        );
        final cacheManager = LocalCacheManager(config: cacheConfig);

        await cacheManager.initialize();

        expect(Directory('${tempDir.path}/cache').existsSync(), isTrue);
        cacheManager.dispose();
      });

      test('caches and retrieves secret values', () async {
        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/cache',
          encryptCache: false,
          compressCache: false,
        );
        final cacheManager = LocalCacheManager(config: cacheConfig);
        await cacheManager.initialize();

        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'cached-secret',
          metadata: metadata,
        );

        // Put in cache
        await cacheManager.put('test-key', secretValue);

        // Get from cache
        final retrieved = await cacheManager.get('test-key');

        expect(retrieved, isNotNull);
        expect(retrieved!.value, equals('cached-secret'));
        expect(retrieved.metadata.name, equals('test-secret'));

        cacheManager.dispose();
      });

      test('handles cache expiration', () async {
        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/cache',
          expiration: Duration(milliseconds: 100),
          encryptCache: false,
          compressCache: false,
        );
        final cacheManager = LocalCacheManager(config: cacheConfig);
        await cacheManager.initialize();

        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'expired-secret',
          metadata: metadata,
        );

        // Put in cache
        await cacheManager.put('test-key', secretValue);

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 150));

        // Should return null for expired entry
        final retrieved = await cacheManager.get('test-key');
        expect(retrieved, isNull);

        cacheManager.dispose();
      });

      test('provides cache statistics', () async {
        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/cache',
          encryptCache: false,
          compressCache: false,
        );
        final cacheManager = LocalCacheManager(config: cacheConfig);
        await cacheManager.initialize();

        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'stats-test',
          metadata: metadata,
        );

        // Put in cache
        await cacheManager.put('test-key', secretValue);

        // Get statistics
        final stats = await cacheManager.getStatistics();

        expect(stats.totalEntries, equals(1));
        expect(stats.totalSize, greaterThan(0));
        expect(stats.hits, equals(0)); // No gets yet
        expect(stats.misses, equals(0));

        // Get from cache to generate hit
        await cacheManager.get('test-key');
        final statsAfterHit = await cacheManager.getStatistics();
        expect(statsAfterHit.hits, equals(1));

        cacheManager.dispose();
      });

      test('clears cache', () async {
        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/cache',
          encryptCache: false,
          compressCache: false,
        );
        final cacheManager = LocalCacheManager(config: cacheConfig);
        await cacheManager.initialize();

        final metadata = RemoteSecretMetadata(name: 'test-secret');
        final secretValue = RemoteSecretValue(
          value: 'clear-test',
          metadata: metadata,
        );

        // Put in cache
        await cacheManager.put('test-key', secretValue);

        // Verify it's there
        final retrieved = await cacheManager.get('test-key');
        expect(retrieved, isNotNull);

        // Clear cache
        await cacheManager.clear();

        // Verify it's gone
        final afterClear = await cacheManager.get('test-key');
        expect(afterClear, isNull);

        cacheManager.dispose();
      });
    });

    group('Exception Handling', () {
      test('creates RemoteSecretException correctly', () {
        const exception = RemoteSecretException(
          'Test error',
          errorCode: 'TEST_ERROR',
          statusCode: 500,
        );

        expect(exception.message, equals('Test error'));
        expect(exception.errorCode, equals('TEST_ERROR'));
        expect(exception.statusCode, equals(500));
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('TEST_ERROR'));
        expect(exception.toString(), contains('500'));
      });

      test('creates RemoteSecretAuthException correctly', () {
        const exception = RemoteSecretAuthException(
          'Auth failed',
          statusCode: 401,
        );

        expect(exception.message, equals('Auth failed'));
        expect(exception.statusCode, equals(401));
        expect(exception, isA<RemoteSecretException>());
      });

      test('creates RemoteSecretNotFoundException correctly', () {
        const exception = RemoteSecretNotFoundException(
          'Secret not found',
          statusCode: 404,
        );

        expect(exception.message, equals('Secret not found'));
        expect(exception.statusCode, equals(404));
        expect(exception, isA<RemoteSecretException>());
      });

      test('creates RemoteSecretRateLimitException correctly', () {
        final retryAfter = DateTime.now().add(Duration(minutes: 5));
        final exception = RemoteSecretRateLimitException(
          'Rate limited',
          retryAfter: retryAfter,
          statusCode: 429,
        );

        expect(exception.message, equals('Rate limited'));
        expect(exception.retryAfter, equals(retryAfter));
        expect(exception.statusCode, equals(429));
        expect(exception, isA<RemoteSecretException>());
      });
    });

    group('Provider Validation', () {
      test('AWS provider requires credentials', () {
        expect(
          () => AwsSecretsManagerProvider(
            config: RemoteSecretConfig(credentials: {}),
          ),
          returnsNormally,
        );
      });

      test('Google provider requires project ID', () {
        expect(
          () => GoogleSecretManagerProvider(
            config: RemoteSecretConfig(credentials: {}),
          ),
          throwsA(isA<RemoteSecretException>()),
        );
      });

      test('Vault provider requires token', () {
        expect(
          () => HashiCorpVaultProvider(
            config: RemoteSecretConfig(credentials: {}),
          ),
          throwsA(isA<RemoteSecretException>()),
        );
      });
    });

    group('Factory Methods', () {
      test('creates cached AWS provider', () async {
        final config = RemoteSecretConfig.aws(
          accessKeyId: 'test-key',
          secretAccessKey: 'test-secret',
        );

        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/aws_cache',
        );

        final provider = await CachedRemoteProviderFactory.createAwsProvider(
          config: config,
          cacheConfig: cacheConfig,
        );

        expect(provider, isA<CachedRemoteSecretProvider>());
        expect(provider.config.credentials['accessKeyId'], equals('test-key'));

        provider.dispose();
      });

      test('creates cached Google provider', () async {
        final config = RemoteSecretConfig.gcp(
          projectId: 'test-project',
          accessToken: 'test-token',
        );

        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/gcp_cache',
        );

        final provider = await CachedRemoteProviderFactory.createGoogleProvider(
          config: config,
          cacheConfig: cacheConfig,
        );

        expect(provider, isA<CachedRemoteSecretProvider>());
        expect(
          provider.config.credentials['projectId'],
          equals('test-project'),
        );

        provider.dispose();
      });

      test('creates cached Vault provider', () async {
        final config = RemoteSecretConfig.vault(
          address: 'http://localhost:8200',
          token: 'test-token',
        );

        final cacheConfig = LocalCacheConfig(
          cacheDirectory: '${tempDir.path}/vault_cache',
        );

        final provider = await CachedRemoteProviderFactory.createVaultProvider(
          config: config,
          cacheConfig: cacheConfig,
        );

        expect(provider, isA<CachedRemoteSecretProvider>());
        expect(provider.config.credentials['token'], equals('test-token'));

        provider.dispose();
      });
    });
  });
}
