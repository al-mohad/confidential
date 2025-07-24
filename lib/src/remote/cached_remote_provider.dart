/// Cached remote secret provider with local caching support.
library;

import 'dart:async';

import '../obfuscation/secret.dart';
import 'aws_secrets_manager.dart';
import 'google_secret_manager.dart';
import 'hashicorp_vault.dart';
import 'local_cache_manager.dart';
import 'remote_secret_provider.dart';

/// Remote secret provider with local caching capabilities.
class CachedRemoteSecretProvider implements RemoteSecretProvider {
  /// The underlying remote provider.
  final RemoteSecretProvider remoteProvider;

  /// Local cache manager.
  final LocalCacheManager? cacheManager;

  /// Whether to use cache-first strategy.
  final bool cacheFirst;

  /// Whether to update cache in background.
  final bool backgroundRefresh;

  CachedRemoteSecretProvider({
    required this.remoteProvider,
    this.cacheManager,
    this.cacheFirst = true,
    this.backgroundRefresh = true,
  });

  @override
  RemoteSecretConfig get config => remoteProvider.config;

  @override
  Future<Secret?> loadSecret(String name) async {
    final secretValue = await getSecretValue(name);
    return secretValue?.toSecret();
  }

  @override
  Future<Map<String, Secret>> loadSecrets(List<String> names) async {
    final results = <String, Secret>{};
    final secretValues = await getSecretValues(names);

    for (final entry in secretValues.entries) {
      results[entry.key] = entry.value.toSecret();
    }

    return results;
  }

  @override
  Future<bool> hasSecret(String name) async {
    // Check cache first if enabled
    if (cacheManager != null && cacheFirst) {
      final cached = await cacheManager!.get(name);
      if (cached != null) {
        return true;
      }
    }

    return await remoteProvider.hasSecret(name);
  }

  @override
  Future<List<String>> listSecrets() async {
    // For listing, always go to remote provider
    return await remoteProvider.listSecrets();
  }

  @override
  Future<RemoteSecretValue?> getSecretValue(
    String name, {
    String? version,
  }) async {
    RemoteSecretValue? cachedValue;

    // Check cache first if enabled and cache-first strategy
    if (cacheManager != null && cacheFirst) {
      cachedValue = await cacheManager!.get(name);
      if (cachedValue != null) {
        // If background refresh is enabled, update cache in background
        if (backgroundRefresh) {
          _refreshCacheInBackground(name, version);
        }
        return cachedValue;
      }
    }

    // Fetch from remote provider
    RemoteSecretValue? remoteValue;
    try {
      remoteValue = await remoteProvider.getSecretValue(name, version: version);

      // Cache the result if cache manager is available
      if (remoteValue != null && cacheManager != null) {
        await cacheManager!.put(
          name,
          remoteValue,
          etag: remoteValue.metadata.version,
        );
      }

      return remoteValue;
    } catch (e) {
      // If remote fetch fails and we have a cached value, return it
      if (cachedValue != null) {
        return cachedValue;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, RemoteSecretValue>> getSecretValues(
    List<String> names,
  ) async {
    final results = <String, RemoteSecretValue>{};
    final uncachedNames = <String>[];

    // Check cache for each name if cache-first strategy
    if (cacheManager != null && cacheFirst) {
      for (final name in names) {
        final cached = await cacheManager!.get(name);
        if (cached != null) {
          results[name] = cached;

          // Schedule background refresh if enabled
          if (backgroundRefresh) {
            _refreshCacheInBackground(name);
          }
        } else {
          uncachedNames.add(name);
        }
      }
    } else {
      uncachedNames.addAll(names);
    }

    // Fetch uncached values from remote provider
    if (uncachedNames.isNotEmpty) {
      try {
        final remoteValues = await remoteProvider.getSecretValues(
          uncachedNames,
        );

        // Add remote values to results and cache them
        for (final entry in remoteValues.entries) {
          results[entry.key] = entry.value;

          // Cache the result if cache manager is available
          if (cacheManager != null) {
            await cacheManager!.put(
              entry.key,
              entry.value,
              etag: entry.value.metadata.version,
            );
          }
        }
      } catch (e) {
        // If remote fetch fails, try to get cached values for failed names
        if (cacheManager != null) {
          for (final name in uncachedNames) {
            if (!results.containsKey(name)) {
              final cached = await cacheManager!.get(name);
              if (cached != null) {
                results[name] = cached;
              }
            }
          }
        }

        // If we still don't have all values, rethrow the error
        if (results.length < names.length) {
          rethrow;
        }
      }
    }

    return results;
  }

  @override
  Future<List<RemoteSecretMetadata>> listSecretsWithMetadata() async {
    return await remoteProvider.listSecretsWithMetadata();
  }

  @override
  Future<RemoteSecretMetadata?> getSecretMetadata(String name) async {
    return await remoteProvider.getSecretMetadata(name);
  }

  @override
  Future<void> putSecret(
    String name,
    String value, {
    String? description,
    Map<String, String>? tags,
    String? kmsKeyId,
  }) async {
    await remoteProvider.putSecret(
      name,
      value,
      description: description,
      tags: tags,
      kmsKeyId: kmsKeyId,
    );

    // Invalidate cache for this secret
    if (cacheManager != null) {
      await cacheManager!.remove(name);
    }
  }

  @override
  Future<void> deleteSecret(String name, {bool forceDelete = false}) async {
    await remoteProvider.deleteSecret(name, forceDelete: forceDelete);

    // Remove from cache
    if (cacheManager != null) {
      await cacheManager!.remove(name);
    }
  }

  @override
  Future<bool> testConnection() async {
    return await remoteProvider.testConnection();
  }

  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    final remoteHealth = await remoteProvider.getHealthStatus();

    // Add cache statistics if cache manager is available
    if (cacheManager != null) {
      final cacheStats = await cacheManager!.getStatistics();
      remoteHealth['cache'] = cacheStats.toMap();
    }

    return remoteHealth;
  }

  /// Gets cache statistics.
  Future<CacheStatistics?> getCacheStatistics() async {
    return await cacheManager?.getStatistics();
  }

  /// Clears the local cache.
  Future<void> clearCache() async {
    await cacheManager?.clear();
  }

  /// Validates cache integrity.
  Future<Map<String, dynamic>?> validateCache() async {
    return await cacheManager?.validateCache();
  }

  /// Cleans up expired cache entries.
  Future<int?> cleanupCache() async {
    return await cacheManager?.cleanupExpiredEntries();
  }

  /// Refreshes a specific secret in the cache.
  Future<void> refreshSecret(String name, {String? version}) async {
    try {
      final remoteValue = await remoteProvider.getSecretValue(
        name,
        version: version,
      );
      if (remoteValue != null && cacheManager != null) {
        await cacheManager!.put(
          name,
          remoteValue,
          etag: remoteValue.metadata.version,
        );
      }
    } catch (e) {
      // Ignore refresh errors in background
    }
  }

  /// Refreshes multiple secrets in the cache.
  Future<void> refreshSecrets(List<String> names) async {
    try {
      final remoteValues = await remoteProvider.getSecretValues(names);
      if (cacheManager != null) {
        for (final entry in remoteValues.entries) {
          await cacheManager!.put(
            entry.key,
            entry.value,
            etag: entry.value.metadata.version,
          );
        }
      }
    } catch (e) {
      // Ignore refresh errors in background
    }
  }

  /// Preloads secrets into the cache.
  Future<void> preloadSecrets(List<String> names) async {
    final uncachedNames = <String>[];

    // Check which secrets are not in cache
    if (cacheManager != null) {
      for (final name in names) {
        final cached = await cacheManager!.get(name);
        if (cached == null) {
          uncachedNames.add(name);
        }
      }
    } else {
      uncachedNames.addAll(names);
    }

    // Preload uncached secrets
    if (uncachedNames.isNotEmpty) {
      await refreshSecrets(uncachedNames);
    }
  }

  /// Refreshes cache in background (fire and forget).
  void _refreshCacheInBackground(String name, [String? version]) {
    Timer.run(() async {
      try {
        await refreshSecret(name, version: version);
      } catch (e) {
        // Ignore background refresh errors
      }
    });
  }

  /// Disposes the provider and cache manager.
  void dispose() {
    cacheManager?.dispose();
  }
}

/// Factory for creating cached remote secret providers.
class CachedRemoteProviderFactory {
  /// Creates a cached AWS Secrets Manager provider.
  static Future<CachedRemoteSecretProvider> createAwsProvider({
    required RemoteSecretConfig config,
    LocalCacheConfig? cacheConfig,
    bool cacheFirst = true,
    bool backgroundRefresh = true,
  }) async {
    final awsProvider = AwsSecretsManagerProvider(config: config);

    LocalCacheManager? cacheManager;
    if (cacheConfig != null) {
      cacheManager = LocalCacheManager(config: cacheConfig);
      await cacheManager.initialize();
    }

    return CachedRemoteSecretProvider(
      remoteProvider: awsProvider,
      cacheManager: cacheManager,
      cacheFirst: cacheFirst,
      backgroundRefresh: backgroundRefresh,
    );
  }

  /// Creates a cached Google Secret Manager provider.
  static Future<CachedRemoteSecretProvider> createGoogleProvider({
    required RemoteSecretConfig config,
    LocalCacheConfig? cacheConfig,
    bool cacheFirst = true,
    bool backgroundRefresh = true,
  }) async {
    final googleProvider = GoogleSecretManagerProvider(config: config);

    LocalCacheManager? cacheManager;
    if (cacheConfig != null) {
      cacheManager = LocalCacheManager(config: cacheConfig);
      await cacheManager.initialize();
    }

    return CachedRemoteSecretProvider(
      remoteProvider: googleProvider,
      cacheManager: cacheManager,
      cacheFirst: cacheFirst,
      backgroundRefresh: backgroundRefresh,
    );
  }

  /// Creates a cached HashiCorp Vault provider.
  static Future<CachedRemoteSecretProvider> createVaultProvider({
    required RemoteSecretConfig config,
    LocalCacheConfig? cacheConfig,
    bool cacheFirst = true,
    bool backgroundRefresh = true,
  }) async {
    final vaultProvider = HashiCorpVaultProvider(config: config);

    LocalCacheManager? cacheManager;
    if (cacheConfig != null) {
      cacheManager = LocalCacheManager(config: cacheConfig);
      await cacheManager.initialize();
    }

    return CachedRemoteSecretProvider(
      remoteProvider: vaultProvider,
      cacheManager: cacheManager,
      cacheFirst: cacheFirst,
      backgroundRefresh: backgroundRefresh,
    );
  }
}
