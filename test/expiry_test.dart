import 'dart:async';
import 'dart:io';

import 'package:confidential/src/expiry/async_expirable.dart';
import 'package:confidential/src/expiry/expirable_obfuscated.dart';
import 'package:confidential/src/expiry/expirable_secret.dart';
import 'package:confidential/src/expiry/expiry_aware_providers.dart';
import 'package:confidential/src/expiry/expiry_extensions.dart';
import 'package:confidential/src/expiry/secret_rotation_manager.dart';
import 'package:confidential/src/extensions/encryption_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('Secret Expiry and Rotation Tests', () {
    late Directory tempDir;
    late ExpiryAwareFileSecretProvider provider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expiry_test');
      provider = ExpiryAwareFileSecretProvider(basePath: tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('ExpirableSecret', () {
      test('creates secret with TTL', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final config = SecretExpiryConfig.withTTL(Duration(minutes: 30));

        final expirableSecret = ExpirableSecret(secret: secret, config: config);

        expect(expirableSecret.status, equals(SecretExpiryStatus.valid));
        expect(expirableSecret.isExpired, isFalse);
        expect(expirableSecret.timeUntilExpiry, isNotNull);
        expect(expirableSecret.timeUntilExpiry!.inMinutes, greaterThan(25));
      });

      test('creates secret with absolute expiry time', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final expiryTime = DateTime.now().add(Duration(hours: 1));
        final config = SecretExpiryConfig.withExpiryTime(expiryTime);

        final expirableSecret = ExpirableSecret(secret: secret, config: config);

        expect(expirableSecret.expiresAt, equals(expiryTime));
        expect(expirableSecret.isExpired, isFalse);
        expect(expirableSecret.timeUntilExpiry!.inMinutes, greaterThan(55));
      });

      test('detects expired secret', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final pastTime = DateTime.now().subtract(Duration(minutes: 2));
        final config = SecretExpiryConfig.withExpiryTime(
          pastTime,
          gracePeriod: Duration(
            minutes: 10,
          ), // Long grace period so it's not hard expired
        );

        final expirableSecret = ExpirableSecret(secret: secret, config: config);

        expect(expirableSecret.isExpired, isTrue);
        expect(expirableSecret.status, equals(SecretExpiryStatus.expired));
        expect(expirableSecret.timeUntilExpiry, equals(Duration.zero));
      });

      test('detects near expiry secret', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final nearExpiryTime = DateTime.now().add(Duration(minutes: 5));
        final config = SecretExpiryConfig.withExpiryTime(nearExpiryTime);

        final expirableSecret = ExpirableSecret(secret: secret, config: config);

        expect(expirableSecret.isNearExpiry, isTrue);
        expect(expirableSecret.status, equals(SecretExpiryStatus.nearExpiry));
      });

      test('throws exception for hard expired secret', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final pastTime = DateTime.now().subtract(Duration(minutes: 20));
        final config = SecretExpiryConfig.withExpiryTime(
          pastTime,
          gracePeriod: Duration(minutes: 5),
        );

        final expirableSecret = ExpirableSecret(secret: secret, config: config);

        expect(expirableSecret.isHardExpired, isTrue);
        expect(
          () => expirableSecret.secret,
          throwsA(isA<SecretExpiredException>()),
        );
      });
    });

    group('ExpirableObfuscatedValue', () {
      test('creates expirable obfuscated string', () {
        final secret = 'test-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final config = SecretExpiryConfig.withTTL(Duration(hours: 1));

        final expirableObfuscated = ExpirableObfuscatedFactory.string(
          secret: secret,
          algorithm: 'aes-256-gcm',
          secretName: 'test-secret',
          expiryConfig: config,
        );

        expect(expirableObfuscated.value, equals('test-value'));
        expect(expirableObfuscated.isExpired, isFalse);
        expect(
          expirableObfuscated.expiryStatus,
          equals(SecretExpiryStatus.valid),
        );
      });

      test('creates expirable obfuscated integer', () {
        final value = 42;
        final secret = value.toString().encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final config = SecretExpiryConfig.withTTL(Duration(hours: 1));

        final expirableObfuscated = ExpirableObfuscatedFactory.integer(
          secret: secret,
          algorithm: 'aes-256-gcm',
          secretName: 'test-number',
          expiryConfig: config,
        );

        expect(expirableObfuscated.value, equals(42));
        expect(expirableObfuscated.isExpired, isFalse);
      });

      test('handles refresh callback', () async {
        final secret = 'original-value'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final config = SecretExpiryConfig.withTTL(Duration(minutes: 1));

        final expirableObfuscated = ExpirableObfuscatedFactory.string(
          secret: secret,
          algorithm: 'aes-256-gcm',
          secretName: 'test-refresh',
          expiryConfig: config,
        );

        var refreshCalled = false;
        expirableObfuscated.setRefreshCallback((name, expirable) async {
          refreshCalled = true;
          return 'refreshed-value'.encrypt(
            algorithm: 'aes-256-gcm',
            nonce: 54321,
          );
        });

        final success = await expirableObfuscated.refresh();
        expect(success, isTrue);
        expect(refreshCalled, isTrue);
      });
    });

    group('Extension Methods', () {
      test('string obfuscateWithTTL extension', () {
        final expirableString = 'api-key-123'.obfuscateWithTTL(
          algorithm: 'aes-256-gcm',
          ttl: Duration(hours: 24),
          secretName: 'apiKey',
        );

        expect(expirableString.value, equals('api-key-123'));
        expect(expirableString.isExpired, isFalse);
        expect(expirableString.timeUntilExpiry!.inHours, greaterThanOrEqualTo(23));
      });

      test('string obfuscateWithExpiry extension', () {
        final expiryTime = DateTime.now().add(Duration(hours: 12));
        final expirableString = 'secret-token'.obfuscateWithExpiry(
          algorithm: 'aes-256-gcm',
          expiresAt: expiryTime,
          secretName: 'token',
        );

        expect(expirableString.value, equals('secret-token'));
        expect(expirableString.expiresAt, equals(expiryTime));
        expect(expirableString.isExpired, isFalse);
      });

      test('integer obfuscateWithTTL extension', () {
        final expirableInt = 12345.obfuscateWithTTL(
          algorithm: 'aes-256-gcm',
          ttl: Duration(hours: 6),
          secretName: 'userId',
        );

        expect(expirableInt.value, equals(12345));
        expect(expirableInt.isExpired, isFalse);
      });

      test('list obfuscateWithTTL extension', () {
        final expirableList = ['item1', 'item2', 'item3'].obfuscateWithTTL(
          algorithm: 'aes-256-gcm',
          ttl: Duration(hours: 2),
          secretName: 'itemList',
        );

        expect(expirableList.value, equals(['item1', 'item2', 'item3']));
        expect(expirableList.isExpired, isFalse);
      });
    });

    group('SecretRotationManager', () {
      test('registers and manages secrets', () {
        final config = SecretRotationConfig(
          defaultTTL: Duration(hours: 1),
          checkInterval: Duration(seconds: 30),
        );
        final manager = SecretRotationManager(
          config: config,
          secretProvider: provider,
        );

        final expirableString = 'managed-secret'.obfuscateWithTTL(
          algorithm: 'aes-256-gcm',
          ttl: Duration(hours: 1),
          secretName: 'managedSecret',
        );

        manager.registerSecret('managedSecret', expirableString);

        expect(manager.listSecrets(), contains('managedSecret'));
        expect(manager.getSecret<String>('managedSecret'), isNotNull);

        manager.dispose();
      });

      test('emits rotation events', () async {
        final config = SecretRotationConfig(
          defaultTTL: Duration(minutes: 1),
          checkInterval: Duration(seconds: 10),
        );
        final manager = SecretRotationManager(
          config: config,
          secretProvider: provider,
        );

        final events = <SecretRotationEvent>[];
        manager.events.listen(events.add);

        final expirableString = 'event-test'.obfuscateWithTTL(
          algorithm: 'aes-256-gcm',
          ttl: Duration(minutes: 1),
          secretName: 'eventTest',
        );

        manager.registerSecret('eventTest', expirableString);

        // Trigger manual rotation
        await manager.rotateSecret('eventTest');

        // Wait a bit for events
        await Future.delayed(Duration(milliseconds: 100));

        expect(events, isNotEmpty);
        expect(
          events.any((e) => e.type == SecretRotationEventType.rotationStarted),
          isTrue,
        );

        manager.dispose();
      });

      test('gets rotation statistics', () {
        final config = SecretRotationConfig();
        final manager = SecretRotationManager(
          config: config,
          secretProvider: provider,
        );

        final stats = manager.getRotationStats();
        expect(stats['totalSecrets'], equals(0));
        expect(stats['rotatingSecrets'], equals(0));
        expect(stats['validCount'], equals(0));

        manager.dispose();
      });
    });

    group('ExpiryAwareProviders', () {
      test('saves and loads secret with metadata', () async {
        final secret = 'provider-test'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );

        await provider.saveSecretWithExpiry(
          'providerTest',
          secret,
          'aes-256-gcm',
          ttl: Duration(hours: 24),
          tags: ['test', 'provider'],
          custom: {'source': 'unit-test'},
        );

        final loaded = await provider.loadSecretWithMetadata('providerTest');
        expect(loaded, isNotNull);
        expect(loaded!.metadata.algorithm, equals('aes-256-gcm'));
        expect(loaded.metadata.tags, contains('test'));
        expect(loaded.metadata.custom['source'], equals('unit-test'));
        expect(loaded.metadata.isExpired, isFalse);
      });

      test('lists expired secrets', () async {
        final secret1 = 'expired-secret'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 11111,
        );
        final secret2 = 'valid-secret'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 22222,
        );

        // Save expired secret
        await provider.saveSecretWithExpiry(
          'expiredSecret',
          secret1,
          'aes-256-gcm',
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        // Save valid secret
        await provider.saveSecretWithExpiry(
          'validSecret',
          secret2,
          'aes-256-gcm',
          ttl: Duration(hours: 24),
        );

        final expired = await provider.listExpiredSecrets();
        expect(expired, contains('expiredSecret'));
        expect(expired, isNot(contains('validSecret')));
      });

      test('cleans up expired secrets', () async {
        final secret = 'cleanup-test'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );

        await provider.saveSecretWithExpiry(
          'cleanupTest',
          secret,
          'aes-256-gcm',
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        final cleaned = await provider.cleanupExpiredSecrets();
        expect(cleaned, equals(1));

        final loaded = await provider.loadSecret('cleanupTest');
        expect(loaded, isNull);
      });
    });

    group('Error Handling', () {
      test('handles missing secret gracefully', () async {
        final factory = AsyncExpirableObfuscatedFactory(provider: provider);
        final asyncSecret = factory.string('nonexistent');

        expect(() => asyncSecret.value, throwsA(isA<Exception>()));
      });

      test('handles refresh failures', () async {
        final secret = 'fail-test'.encrypt(
          algorithm: 'aes-256-gcm',
          nonce: 12345,
        );
        final config = SecretExpiryConfig.withTTL(Duration(minutes: 1));

        final expirableObfuscated = ExpirableObfuscatedFactory.string(
          secret: secret,
          algorithm: 'aes-256-gcm',
          secretName: 'failTest',
          expiryConfig: config,
        );

        expirableObfuscated.setRefreshCallback((name, expirable) async {
          throw Exception('Refresh failed');
        });

        final success = await expirableObfuscated.refresh();
        expect(success, isFalse);
      });
    });
  });
}
