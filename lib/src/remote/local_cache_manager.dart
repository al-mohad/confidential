/// Local cache manager for remote secrets with encryption and compression.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../extensions/encryption_extensions.dart';
import '../obfuscation/secret.dart';
import 'remote_secret_provider.dart';

/// Local cache entry for remote secrets.
class CacheEntry {
  /// The cached secret value.
  final RemoteSecretValue secretValue;
  
  /// When this entry was cached.
  final DateTime cachedAt;
  
  /// When this entry expires.
  final DateTime expiresAt;
  
  /// Size of the cached data in bytes.
  final int size;
  
  /// ETag or version for cache validation.
  final String? etag;

  const CacheEntry({
    required this.secretValue,
    required this.cachedAt,
    required this.expiresAt,
    required this.size,
    this.etag,
  });

  /// Checks if this cache entry is expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'secretValue': {
        'value': secretValue.value,
        'binaryValue': secretValue.binaryValue != null 
            ? base64Encode(secretValue.binaryValue!)
            : null,
        'metadata': secretValue.metadata.toMap(),
      },
      'cachedAt': cachedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'size': size,
      if (etag != null) 'etag': etag,
    };
  }

  /// Creates from a map.
  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    final secretValueMap = map['secretValue'] as Map<String, dynamic>;
    final binaryValueStr = secretValueMap['binaryValue'] as String?;
    
    return CacheEntry(
      secretValue: RemoteSecretValue(
        value: secretValueMap['value'] as String,
        binaryValue: binaryValueStr != null 
            ? base64Decode(binaryValueStr)
            : null,
        metadata: RemoteSecretMetadata.fromMap(
          secretValueMap['metadata'] as Map<String, dynamic>
        ),
      ),
      cachedAt: DateTime.parse(map['cachedAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      size: map['size'] as int,
      etag: map['etag'] as String?,
    );
  }
}

/// Statistics for the local cache.
class CacheStatistics {
  /// Total number of cached entries.
  final int totalEntries;
  
  /// Total cache size in bytes.
  final int totalSize;
  
  /// Number of expired entries.
  final int expiredEntries;
  
  /// Cache hit rate (0.0 to 1.0).
  final double hitRate;
  
  /// Number of cache hits.
  final int hits;
  
  /// Number of cache misses.
  final int misses;
  
  /// When the cache was last cleaned.
  final DateTime? lastCleanup;

  const CacheStatistics({
    required this.totalEntries,
    required this.totalSize,
    required this.expiredEntries,
    required this.hitRate,
    required this.hits,
    required this.misses,
    this.lastCleanup,
  });

  /// Converts to a map.
  Map<String, dynamic> toMap() {
    return {
      'totalEntries': totalEntries,
      'totalSize': totalSize,
      'expiredEntries': expiredEntries,
      'hitRate': hitRate,
      'hits': hits,
      'misses': misses,
      if (lastCleanup != null) 'lastCleanup': lastCleanup!.toIso8601String(),
    };
  }
}

/// Local cache manager for remote secrets.
class LocalCacheManager {
  final LocalCacheConfig config;
  final Directory _cacheDir;
  final Map<String, CacheEntry> _memoryCache = {};
  
  int _hits = 0;
  int _misses = 0;
  DateTime? _lastCleanup;

  LocalCacheManager({
    required this.config,
  }) : _cacheDir = Directory(config.cacheDirectory);

  /// Initializes the cache directory.
  Future<void> initialize() async {
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    
    // Load existing cache entries into memory
    await _loadCacheFromDisk();
    
    // Schedule periodic cleanup
    Timer.periodic(const Duration(hours: 1), (_) => _cleanupExpiredEntries());
  }

  /// Gets a cached secret value.
  Future<RemoteSecretValue?> get(String key) async {
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null) {
      if (!memoryEntry.isExpired) {
        _hits++;
        return memoryEntry.secretValue;
      } else {
        _memoryCache.remove(key);
        await _deleteCacheFile(key);
      }
    }

    // Check disk cache
    final diskEntry = await _loadCacheEntry(key);
    if (diskEntry != null) {
      if (!diskEntry.isExpired) {
        _memoryCache[key] = diskEntry;
        _hits++;
        return diskEntry.secretValue;
      } else {
        await _deleteCacheFile(key);
      }
    }

    _misses++;
    return null;
  }

  /// Puts a secret value in the cache.
  Future<void> put(String key, RemoteSecretValue secretValue, {String? etag}) async {
    final now = DateTime.now();
    final expiresAt = now.add(config.expiration);
    final size = _calculateSize(secretValue);

    final entry = CacheEntry(
      secretValue: secretValue,
      cachedAt: now,
      expiresAt: expiresAt,
      size: size,
      etag: etag,
    );

    // Check cache size limits
    await _ensureCacheSize(size);

    // Store in memory cache
    _memoryCache[key] = entry;

    // Store on disk if enabled
    if (config.enabled) {
      await _saveCacheEntry(key, entry);
    }
  }

  /// Removes a cached entry.
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _deleteCacheFile(key);
  }

  /// Clears all cached entries.
  Future<void> clear() async {
    _memoryCache.clear();
    
    if (await _cacheDir.exists()) {
      await for (final entity in _cacheDir.list()) {
        if (entity is File && entity.path.endsWith('.cache')) {
          await entity.delete();
        }
      }
    }
  }

  /// Gets cache statistics.
  Future<CacheStatistics> getStatistics() async {
    final totalEntries = _memoryCache.length;
    final totalSize = _memoryCache.values.fold<int>(0, (sum, entry) => sum + entry.size);
    final expiredEntries = _memoryCache.values.where((entry) => entry.isExpired).length;
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? _hits / totalRequests : 0.0;

    return CacheStatistics(
      totalEntries: totalEntries,
      totalSize: totalSize,
      expiredEntries: expiredEntries,
      hitRate: hitRate,
      hits: _hits,
      misses: _misses,
      lastCleanup: _lastCleanup,
    );
  }

  /// Cleans up expired cache entries.
  Future<int> cleanupExpiredEntries() async {
    return await _cleanupExpiredEntries();
  }

  /// Validates cache integrity.
  Future<Map<String, dynamic>> validateCache() async {
    final issues = <String>[];
    int validEntries = 0;
    int corruptedEntries = 0;

    for (final entry in _memoryCache.entries) {
      try {
        final diskEntry = await _loadCacheEntry(entry.key);
        if (diskEntry == null) {
          issues.add('Memory entry ${entry.key} not found on disk');
        } else if (diskEntry.etag != entry.value.etag) {
          issues.add('ETag mismatch for ${entry.key}');
        } else {
          validEntries++;
        }
      } catch (e) {
        issues.add('Failed to validate ${entry.key}: $e');
        corruptedEntries++;
      }
    }

    return {
      'validEntries': validEntries,
      'corruptedEntries': corruptedEntries,
      'issues': issues,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Loads cache entries from disk into memory.
  Future<void> _loadCacheFromDisk() async {
    if (!await _cacheDir.exists()) return;

    await for (final entity in _cacheDir.list()) {
      if (entity is File && entity.path.endsWith('.cache')) {
        try {
          final key = entity.path.split('/').last.replaceAll('.cache', '');
          final entry = await _loadCacheEntry(key);
          if (entry != null && !entry.isExpired) {
            _memoryCache[key] = entry;
          } else if (entry?.isExpired == true) {
            await entity.delete();
          }
        } catch (e) {
          // Skip corrupted cache files
          await entity.delete();
        }
      }
    }
  }

  /// Loads a cache entry from disk.
  Future<CacheEntry?> _loadCacheEntry(String key) async {
    final file = File('${_cacheDir.path}/$key.cache');
    
    if (!await file.exists()) {
      return null;
    }

    try {
      Uint8List data = await file.readAsBytes();

      // Decompress if enabled
      if (config.compressCache) {
        final archive = ZipDecoder().decodeBytes(data);
        if (archive.files.isNotEmpty) {
          data = archive.files.first.content as Uint8List;
        }
      }

      // Decrypt if enabled
      if (config.encryptCache) {
        final secret = Secret(data: data, nonce: key.hashCode);
        data = secret.decrypt<Uint8List>(algorithm: config.encryptionAlgorithm);
      }

      final json = utf8.decode(data);
      final map = jsonDecode(json) as Map<String, dynamic>;
      
      return CacheEntry.fromMap(map);
    } catch (e) {
      // Delete corrupted cache file
      await file.delete();
      return null;
    }
  }

  /// Saves a cache entry to disk.
  Future<void> _saveCacheEntry(String key, CacheEntry entry) async {
    final file = File('${_cacheDir.path}/$key.cache');
    
    try {
      final json = jsonEncode(entry.toMap());
      Uint8List data = Uint8List.fromList(utf8.encode(json));

      // Encrypt if enabled
      if (config.encryptCache) {
        data = data.encrypt(
          algorithm: config.encryptionAlgorithm,
          nonce: key.hashCode,
        ).data;
      }

      // Compress if enabled
      if (config.compressCache) {
        final archive = Archive();
        archive.addFile(ArchiveFile('data', data.length, data));
        data = Uint8List.fromList(ZipEncoder().encode(archive)!);
      }

      await file.writeAsBytes(data);
    } catch (e) {
      // If saving fails, remove from memory cache too
      _memoryCache.remove(key);
      rethrow;
    }
  }

  /// Deletes a cache file from disk.
  Future<void> _deleteCacheFile(String key) async {
    final file = File('${_cacheDir.path}/$key.cache');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Ensures cache size is within limits.
  Future<void> _ensureCacheSize(int newEntrySize) async {
    final currentSize = _memoryCache.values.fold<int>(0, (sum, entry) => sum + entry.size);
    
    if (currentSize + newEntrySize > config.maxCacheSize || 
        _memoryCache.length >= config.maxCachedSecrets) {
      await _evictOldestEntries(newEntrySize);
    }
  }

  /// Evicts oldest cache entries to make room.
  Future<void> _evictOldestEntries(int requiredSpace) async {
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

    int freedSpace = 0;
    int evictedCount = 0;

    for (final entry in entries) {
      if (freedSpace >= requiredSpace && 
          _memoryCache.length - evictedCount < config.maxCachedSecrets) {
        break;
      }

      await remove(entry.key);
      freedSpace += entry.value.size;
      evictedCount++;
    }
  }

  /// Cleans up expired entries.
  Future<int> _cleanupExpiredEntries() async {
    final expiredKeys = <String>[];
    
    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      await remove(key);
    }

    _lastCleanup = DateTime.now();
    return expiredKeys.length;
  }

  /// Calculates the size of a secret value.
  int _calculateSize(RemoteSecretValue secretValue) {
    int size = secretValue.value.length;
    if (secretValue.binaryValue != null) {
      size += secretValue.binaryValue!.length;
    }
    size += jsonEncode(secretValue.metadata.toMap()).length;
    return size;
  }

  /// Disposes the cache manager.
  void dispose() {
    _memoryCache.clear();
  }
}
