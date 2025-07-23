/// Asynchronous secret loading and providers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../obfuscation/secret.dart';

/// Base interface for secret providers.
abstract class SecretProvider {
  /// Loads a secret by name.
  Future<Secret?> loadSecret(String name);

  /// Loads multiple secrets by names.
  Future<Map<String, Secret>> loadSecrets(List<String> names);

  /// Checks if a secret exists.
  Future<bool> hasSecret(String name);

  /// Lists all available secret names.
  Future<List<String>> listSecrets();
}

/// Configuration for secret providers.
class SecretProviderConfig {
  /// Timeout for loading operations.
  final Duration timeout;

  /// Number of retry attempts.
  final int retryAttempts;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Whether to cache loaded secrets.
  final bool enableCaching;

  /// Cache expiration time.
  final Duration? cacheExpiration;

  /// Encryption algorithm for stored secrets.
  final String? encryptionAlgorithm;

  const SecretProviderConfig({
    this.timeout = const Duration(seconds: 30),
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCaching = true,
    this.cacheExpiration,
    this.encryptionAlgorithm,
  });
}

/// HTTP-based secret provider for loading secrets from remote endpoints.
class HttpSecretProvider implements SecretProvider {
  final String baseUrl;
  final Map<String, String> headers;
  final SecretProviderConfig config;
  final HttpClient _httpClient;
  final Map<String, _CachedSecret> _cache = {};

  HttpSecretProvider({
    required this.baseUrl,
    this.headers = const {},
    this.config = const SecretProviderConfig(),
  }) : _httpClient = HttpClient();

  @override
  Future<Secret?> loadSecret(String name) async {
    // Check cache first
    if (config.enableCaching) {
      final cached = _cache[name];
      if (cached != null && !cached.isExpired) {
        return cached.secret;
      }
    }

    Secret? secret;
    Exception? lastException;

    for (int attempt = 0; attempt <= config.retryAttempts; attempt++) {
      try {
        secret = await _loadSecretFromHttp(name);
        break;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < config.retryAttempts) {
          await Future.delayed(config.retryDelay);
        }
      }
    }

    if (secret == null && lastException != null) {
      throw lastException;
    }

    // Cache the result
    if (secret != null && config.enableCaching) {
      _cache[name] = _CachedSecret(
        secret,
        DateTime.now().add(config.cacheExpiration ?? const Duration(hours: 1)),
      );
    }

    return secret;
  }

  Future<Secret?> _loadSecretFromHttp(String name) async {
    final uri = Uri.parse('$baseUrl/secrets/$name');
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);
    
    // Add headers
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();
    
    if (response.statusCode == 404) {
      return null;
    }
    
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: Failed to load secret $name');
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    final secretData = data['data'] as String;
    final nonce = data['nonce'] as int;
    
    return Secret(
      data: Uint8List.fromList(base64Decode(secretData)),
      nonce: nonce,
    );
  }

  @override
  Future<Map<String, Secret>> loadSecrets(List<String> names) async {
    final results = <String, Secret>{};
    
    // Load secrets in parallel
    final futures = names.map((name) async {
      final secret = await loadSecret(name);
      if (secret != null) {
        results[name] = secret;
      }
    });

    await Future.wait(futures);
    return results;
  }

  @override
  Future<bool> hasSecret(String name) async {
    try {
      final secret = await loadSecret(name);
      return secret != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> listSecrets() async {
    final uri = Uri.parse('$baseUrl/secrets');
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);
    
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();
    
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: Failed to list secrets');
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    
    return (data['secrets'] as List).cast<String>();
  }

  /// Clears the cache.
  void clearCache() {
    _cache.clear();
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
  }
}

/// File-based secret provider for loading secrets from local files.
class FileSecretProvider implements SecretProvider {
  final String basePath;
  final SecretProviderConfig config;
  final Map<String, _CachedSecret> _cache = {};

  FileSecretProvider({
    required this.basePath,
    this.config = const SecretProviderConfig(),
  });

  @override
  Future<Secret?> loadSecret(String name) async {
    // Check cache first
    if (config.enableCaching) {
      final cached = _cache[name];
      if (cached != null && !cached.isExpired) {
        return cached.secret;
      }
    }

    final file = File('$basePath/$name.secret');
    
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final secretData = data['data'] as String;
      final nonce = data['nonce'] as int;
      
      final secret = Secret(
        data: Uint8List.fromList(base64Decode(secretData)),
        nonce: nonce,
      );

      // Cache the result
      if (config.enableCaching) {
        _cache[name] = _CachedSecret(
          secret,
          DateTime.now().add(config.cacheExpiration ?? const Duration(hours: 1)),
        );
      }

      return secret;
    } catch (e) {
      throw Exception('Failed to load secret $name: $e');
    }
  }

  @override
  Future<Map<String, Secret>> loadSecrets(List<String> names) async {
    final results = <String, Secret>{};
    
    for (final name in names) {
      final secret = await loadSecret(name);
      if (secret != null) {
        results[name] = secret;
      }
    }

    return results;
  }

  @override
  Future<bool> hasSecret(String name) async {
    final file = File('$basePath/$name.secret');
    return await file.exists();
  }

  @override
  Future<List<String>> listSecrets() async {
    final directory = Directory(basePath);
    
    if (!await directory.exists()) {
      return [];
    }

    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.secret'))
        .cast<File>()
        .toList();

    return files
        .map((file) => file.path.split('/').last.replaceAll('.secret', ''))
        .toList();
  }

  /// Saves a secret to a file.
  Future<void> saveSecret(String name, Secret secret) async {
    final file = File('$basePath/$name.secret');
    await file.parent.create(recursive: true);

    final data = {
      'data': base64Encode(secret.data),
      'nonce': secret.nonce,
    };

    await file.writeAsString(jsonEncode(data));
  }
}

/// Composite secret provider that tries multiple providers in order.
class CompositeSecretProvider implements SecretProvider {
  final List<SecretProvider> providers;

  CompositeSecretProvider(this.providers);

  @override
  Future<Secret?> loadSecret(String name) async {
    for (final provider in providers) {
      try {
        final secret = await provider.loadSecret(name);
        if (secret != null) {
          return secret;
        }
      } catch (e) {
        // Continue to next provider
        continue;
      }
    }
    return null;
  }

  @override
  Future<Map<String, Secret>> loadSecrets(List<String> names) async {
    final results = <String, Secret>{};
    
    for (final name in names) {
      final secret = await loadSecret(name);
      if (secret != null) {
        results[name] = secret;
      }
    }

    return results;
  }

  @override
  Future<bool> hasSecret(String name) async {
    for (final provider in providers) {
      try {
        if (await provider.hasSecret(name)) {
          return true;
        }
      } catch (e) {
        // Continue to next provider
        continue;
      }
    }
    return false;
  }

  @override
  Future<List<String>> listSecrets() async {
    final allSecrets = <String>{};
    
    for (final provider in providers) {
      try {
        final secrets = await provider.listSecrets();
        allSecrets.addAll(secrets);
      } catch (e) {
        // Continue to next provider
        continue;
      }
    }

    return allSecrets.toList();
  }
}

/// Cached secret with expiration.
class _CachedSecret {
  final Secret secret;
  final DateTime expiresAt;

  _CachedSecret(this.secret, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
