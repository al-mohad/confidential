import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:confidential/confidential.dart';

void main() {
  group('API Improvements Tests', () {
    group('Extension Methods', () {
      test('String encryption extension', () {
        const testString = 'Hello, World!';
        final secret = testString.encrypt(algorithm: 'aes-256-gcm', nonce: 12345);
        
        expect(secret.data, isNotEmpty);
        expect(secret.nonce, equals(12345));
        
        final decrypted = secret.decryptAsString(algorithm: 'aes-256-gcm');
        expect(decrypted, equals(testString));
      });

      test('String obfuscation extension', () {
        const testString = 'Secret Message';
        final obfuscated = testString.obfuscate(algorithm: 'aes-256-gcm', nonce: 54321);
        
        expect(obfuscated.value, equals(testString));
        expect(obfuscated.$, equals(testString)); // Projected value syntax
      });

      test('List<String> encryption extension', () {
        const testList = ['item1', 'item2', 'item3'];
        final secret = testList.encrypt(algorithm: 'aes-256-gcm', nonce: 98765);
        
        expect(secret.data, isNotEmpty);
        expect(secret.nonce, equals(98765));
        
        final decrypted = secret.decryptAsStringList(algorithm: 'aes-256-gcm');
        expect(decrypted, equals(testList));
      });

      test('Map encryption extension', () {
        const testMap = {'key1': 'value1', 'key2': 'value2'};
        final secret = testMap.encrypt(algorithm: 'aes-256-gcm', nonce: 11111);
        
        expect(secret.data, isNotEmpty);
        expect(secret.nonce, equals(11111));
        
        final decrypted = secret.decryptAsMap(algorithm: 'aes-256-gcm');
        expect(decrypted, equals(testMap));
      });

      test('Integer encryption extension', () {
        const testInt = 42;
        final obfuscated = testInt.obfuscate(algorithm: 'aes-256-gcm', nonce: 22222);
        
        expect(obfuscated.value, equals(testInt));
      });

      test('Boolean encryption extension', () {
        const testBool = true;
        final obfuscated = testBool.obfuscate(algorithm: 'aes-256-gcm', nonce: 33333);
        
        expect(obfuscated.value, equals(testBool));
      });

      test('ObfuscatedValue extensions', () {
        const testString = 'Test Value';
        final obfuscated = testString.obfuscate(algorithm: 'aes-256-gcm');
        
        // Test convenience methods
        expect(obfuscated.getValue(), equals(testString));
        expect(obfuscated.isType<String>(), isTrue);
        expect(obfuscated.isType<int>(), isFalse);
        expect(obfuscated.safeCast<String>(), equals(testString));
        expect(obfuscated.safeCast<int>(), isNull);
        
        // Test async getter
        expectLater(obfuscated.getValueAsync(), completion(equals(testString)));
        
        // Test map transformation
        final mapped = obfuscated.map<int>((s) => s.length);
        expect(mapped.value, equals(testString.length));
      });

      test('Uint8List encryption extension', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final obfuscated = testData.obfuscate(algorithm: 'aes-256-gcm', nonce: 44444);
        
        expect(obfuscated.value, equals(testData));
      });
    });

    group('Secret Groups', () {
      test('GroupedSecretDefinition creation', () {
        final secret = GroupedSecretDefinition(
          name: 'testSecret',
          value: 'testValue',
          group: 'testGroup',
          tags: ['tag1', 'tag2'],
          description: 'Test secret',
          environment: 'development',
          priority: 5,
        );

        expect(secret.name, equals('testSecret'));
        expect(secret.group, equals('testGroup'));
        expect(secret.tags, equals(['tag1', 'tag2']));
        expect(secret.description, equals('Test secret'));
        expect(secret.environment, equals('development'));
        expect(secret.priority, equals(5));
      });

      test('GroupedSecretDefinition from YAML', () {
        final yaml = {
          'name': 'apiKey',
          'value': 'secret-key-123',
          'group': 'api',
          'tags': ['production', 'critical'],
          'description': 'API key for external service',
          'environment': 'production',
          'priority': 10,
          'deprecated': false,
        };

        final secret = GroupedSecretDefinition.fromYaml(yaml);
        
        expect(secret.name, equals('apiKey'));
        expect(secret.group, equals('api'));
        expect(secret.tags, equals(['production', 'critical']));
        expect(secret.description, equals('API key for external service'));
        expect(secret.environment, equals('production'));
        expect(secret.priority, equals(10));
        expect(secret.deprecated, isFalse);
      });

      test('SecretFilter functionality', () {
        final secrets = [
          GroupedSecretDefinition(
            name: 'secret1',
            value: 'value1',
            group: 'group1',
            tags: ['tag1'],
            environment: 'dev',
          ),
          GroupedSecretDefinition(
            name: 'secret2',
            value: 'value2',
            group: 'group2',
            tags: ['tag2'],
            environment: 'prod',
            deprecated: true,
          ),
          GroupedSecretDefinition(
            name: 'secret3',
            value: 'value3',
            group: 'group1',
            tags: ['tag1', 'tag3'],
            environment: 'dev',
          ),
        ];

        // Test group filter
        final groupFilter = SecretFilter.group('group1');
        final groupFiltered = secrets.where((s) => s.matchesFilter(groupFilter)).toList();
        expect(groupFiltered.length, equals(2));

        // Test tag filter
        final tagFilter = SecretFilter.tags(['tag1']);
        final tagFiltered = secrets.where((s) => s.matchesFilter(tagFilter)).toList();
        expect(tagFiltered.length, equals(2));

        // Test environment filter
        final envFilter = SecretFilter.environment('prod');
        final envFiltered = secrets.where((s) => s.matchesFilter(envFilter)).toList();
        expect(envFiltered.length, equals(1));

        // Test exclude deprecated filter
        final deprecatedFilter = SecretFilter.excludeDeprecated();
        final nonDeprecated = secrets.where((s) => s.matchesFilter(deprecatedFilter)).toList();
        expect(nonDeprecated.length, equals(2));
      });

      test('SecretGroup functionality', () {
        final group = SecretGroup(
          name: 'apiSecrets',
          description: 'API-related secrets',
          namespace: 'create ApiSecrets',
          tags: ['api', 'external'],
          secrets: [
            GroupedSecretDefinition(
              name: 'apiKey',
              value: 'key123',
              tags: ['critical'],
              priority: 10,
            ),
            GroupedSecretDefinition(
              name: 'apiUrl',
              value: 'https://api.example.com',
              tags: ['config'],
              priority: 5,
            ),
          ],
        );

        expect(group.name, equals('apiSecrets'));
        expect(group.secrets.length, equals(2));
        expect(group.hasTag('api'), isTrue);
        expect(group.hasTag('critical'), isTrue);
        expect(group.hasTag('nonexistent'), isFalse);

        // Test secrets by priority
        final byPriority = group.secretsByPriority;
        expect(byPriority.first.name, equals('apiKey'));
        expect(byPriority.last.name, equals('apiUrl'));
      });

      test('SecretGroupManager functionality', () {
        final manager = SecretGroupManager(
          groups: [
            SecretGroup(
              name: 'group1',
              secrets: [
                GroupedSecretDefinition(name: 'secret1', value: 'value1', tags: ['tag1']),
                GroupedSecretDefinition(name: 'secret2', value: 'value2', tags: ['tag2']),
              ],
            ),
            SecretGroup(
              name: 'group2',
              secrets: [
                GroupedSecretDefinition(name: 'secret3', value: 'value3', tags: ['tag1']),
              ],
            ),
          ],
        );

        expect(manager.allSecrets.length, equals(3));
        expect(manager.groupNames, equals(['group1', 'group2']));
        expect(manager.allTags, equals({'tag1', 'tag2'}));

        final group1Secrets = manager.getSecretsByGroup('group1');
        expect(group1Secrets.length, equals(2));

        final tag1Secrets = manager.getSecretsByTag('tag1');
        expect(tag1Secrets.length, equals(2));
      });
    });

    group('Async Secret Loading', () {
      late Directory tempDir;
      late FileSecretProvider fileProvider;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('confidential_test');
        fileProvider = FileSecretProvider(basePath: tempDir.path);
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      test('FileSecretProvider save and load', () async {
        final secret = Secret(
          data: Uint8List.fromList([1, 2, 3, 4, 5]),
          nonce: 12345,
        );

        await fileProvider.saveSecret('testSecret', secret);
        
        final loaded = await fileProvider.loadSecret('testSecret');
        expect(loaded, isNotNull);
        expect(loaded!.data, equals(secret.data));
        expect(loaded.nonce, equals(secret.nonce));
      });

      test('FileSecretProvider list secrets', () async {
        final secret1 = Secret(data: Uint8List.fromList([1, 2, 3]), nonce: 111);
        final secret2 = Secret(data: Uint8List.fromList([4, 5, 6]), nonce: 222);

        await fileProvider.saveSecret('secret1', secret1);
        await fileProvider.saveSecret('secret2', secret2);

        final secrets = await fileProvider.listSecrets();
        expect(secrets.length, equals(2));
        expect(secrets, containsAll(['secret1', 'secret2']));
      });

      test('FileSecretProvider has secret', () async {
        final secret = Secret(data: Uint8List.fromList([1, 2, 3]), nonce: 123);
        await fileProvider.saveSecret('existingSecret', secret);

        expect(await fileProvider.hasSecret('existingSecret'), isTrue);
        expect(await fileProvider.hasSecret('nonExistentSecret'), isFalse);
      });

      test('AsyncObfuscatedValue functionality', () async {
        final secret = Secret(
          data: "Hello, Async World!".encrypt(algorithm: 'aes-256-gcm', nonce: 99999).data,
          nonce: 99999,
        );
        
        await fileProvider.saveSecret('asyncTest', secret);

        final asyncObfuscated = AsyncObfuscatedString(
          secretName: 'asyncTest',
          provider: fileProvider,
          algorithm: 'aes-256-gcm',
        );

        final value = await asyncObfuscated.value;
        expect(value, equals('Hello, Async World!'));

        // Test caching
        final value2 = await asyncObfuscated.value;
        expect(value2, equals(value));

        // Test timeout
        final valueWithTimeout = await asyncObfuscated.getValueWithTimeout(
          const Duration(seconds: 5),
        );
        expect(valueWithTimeout, equals(value));

        // Test default value
        asyncObfuscated.clearCache();
        final valueOrDefault = await asyncObfuscated.getValueOrDefault('default');
        expect(valueOrDefault, equals('Hello, Async World!'));
      });

      test('AsyncObfuscatedFactory functionality', () async {
        final factory = AsyncObfuscatedFactory(provider: fileProvider);

        // Save test secrets
        await fileProvider.saveSecret('stringSecret', 
          "Test String".encrypt(algorithm: 'aes-256-gcm', nonce: 111));
        await fileProvider.saveSecret('intSecret', 
          42.encrypt(algorithm: 'aes-256-gcm', nonce: 222));
        await fileProvider.saveSecret('boolSecret', 
          true.encrypt(algorithm: 'aes-256-gcm', nonce: 333));

        final stringSecret = factory.string('stringSecret');
        final intSecret = factory.integer('intSecret');
        final boolSecret = factory.boolean('boolSecret');

        expect(await stringSecret.value, equals('Test String'));
        expect(await intSecret.value, equals(42));
        expect(await boolSecret.value, equals(true));
      });

      test('CompositeSecretProvider functionality', () async {
        final provider1 = FileSecretProvider(basePath: '${tempDir.path}/provider1');
        final provider2 = FileSecretProvider(basePath: '${tempDir.path}/provider2');
        
        await Directory('${tempDir.path}/provider1').create();
        await Directory('${tempDir.path}/provider2').create();

        final composite = CompositeSecretProvider([provider1, provider2]);

        // Save secrets in different providers
        await provider1.saveSecret('secret1', 
          Secret(data: Uint8List.fromList([1, 2, 3]), nonce: 111));
        await provider2.saveSecret('secret2', 
          Secret(data: Uint8List.fromList([4, 5, 6]), nonce: 222));

        // Test loading from composite
        final secret1 = await composite.loadSecret('secret1');
        final secret2 = await composite.loadSecret('secret2');
        final nonExistent = await composite.loadSecret('nonExistent');

        expect(secret1, isNotNull);
        expect(secret2, isNotNull);
        expect(nonExistent, isNull);

        // Test listing all secrets
        final allSecrets = await composite.listSecrets();
        expect(allSecrets.length, equals(2));
        expect(allSecrets, containsAll(['secret1', 'secret2']));
      });
    });
  });
}
