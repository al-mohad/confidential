import 'dart:io';

import 'package:confidential/src/async/secret_providers.dart';
import 'package:confidential/src/extensions/encryption_extensions.dart';
import 'package:confidential/src/integrations/provider_integration.dart'
    as provider_integration;
import 'package:test/test.dart';

void main() {
  group('Basic Integration Tests', () {
    late Directory tempDir;
    late FileSecretProvider secretProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'confidential_integrations_test',
      );
      secretProvider = FileSecretProvider(basePath: tempDir.path);

      // Save test secrets
      await secretProvider.saveSecret(
        'apiKey',
        'test-api-key-123'.encrypt(algorithm: 'aes-256-gcm', nonce: 11111),
      );
      await secretProvider.saveSecret(
        'password',
        'super-secret-password'.encrypt(algorithm: 'aes-256-gcm', nonce: 22222),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('Basic Functionality', () {
      test('can create obfuscated values', () {
        final staticToken = 'static-token-123'.obfuscate(
          algorithm: 'aes-256-gcm',
        );

        expect(staticToken.value, equals('static-token-123'));
      });

      test('can use file secret provider', () async {
        final secret = await secretProvider.loadSecret('apiKey');
        expect(secret, isNotNull);
        // For Secret objects, we need to decrypt them
        final decrypted = secret!.decrypt<String>(algorithm: 'aes-256-gcm');
        expect(decrypted, equals('test-api-key-123'));
      });

      test('can create custom obfuscated values', () {
        final staticToken = 'custom-token'.obfuscate(algorithm: 'aes-256-gcm');
        expect(staticToken.value, equals('custom-token'));
      });

      test('can load multiple secrets', () async {
        final apiKey = await secretProvider.loadSecret('apiKey');
        final password = await secretProvider.loadSecret('password');

        expect(apiKey, isNotNull);
        expect(password, isNotNull);
        final decryptedApiKey = apiKey!.decrypt<String>(
          algorithm: 'aes-256-gcm',
        );
        final decryptedPassword = password!.decrypt<String>(
          algorithm: 'aes-256-gcm',
        );
        expect(decryptedApiKey, equals('test-api-key-123'));
        expect(decryptedPassword, equals('super-secret-password'));
      });
    });

    group('Provider Integration', () {
      test('can create provider-like interface', () {
        final obfuscated = 'test-value'.obfuscate(algorithm: 'aes-256-gcm');
        final provider = provider_integration.ObfuscatedValueProvider(
          obfuscated,
        );

        expect(provider.value, equals('test-value'));
      });

      test('provider interface works with async loading', () async {
        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        final manager = provider_integration.SecretManagerProvider();

        // Use the correct method name
        manager.addStatic('static', staticSecret);

        final retrieved = manager.getStatic<String>('static');
        expect(retrieved, isNotNull);
        expect(retrieved!.value, equals('static-value'));
      });
    });

    group('Extension Methods', () {
      test('string encryption extension works', () {
        final encrypted = 'test-string'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final decrypted = encrypted.decrypt<String>(algorithm: 'aes-256-gcm');
        expect(decrypted, equals('test-string'));
      });

      test('string obfuscation extension works', () {
        final obfuscated = 'test-value'.obfuscate(algorithm: 'aes-256-gcm');
        expect(obfuscated.value, equals('test-value'));
      });

      test('can use different algorithms', () {
        final aes = 'test'.obfuscate(algorithm: 'aes-256-gcm');
        final chacha = 'test'.obfuscate(algorithm: 'chacha20-poly1305');

        expect(aes.value, equals('test'));
        expect(chacha.value, equals('test'));
      });
    });

    group('Error Handling', () {
      test('handles missing secrets gracefully', () async {
        final missing = await secretProvider.loadSecret('nonexistent');
        expect(missing, isNull);
      });

      test('handles invalid algorithms gracefully', () {
        expect(
          () => 'test'.obfuscate(algorithm: 'invalid-algorithm'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
