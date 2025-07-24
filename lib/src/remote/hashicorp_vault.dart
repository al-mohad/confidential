/// HashiCorp Vault integration for remote secret management.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../obfuscation/secret.dart';
import 'remote_secret_provider.dart';

/// HashiCorp Vault provider for remote secret management.
class HashiCorpVaultProvider implements RemoteSecretProvider {
  @override
  final RemoteSecretConfig config;

  final HttpClient _httpClient;
  final Map<String, RemoteSecretValue> _cache = {};
  final String _address;
  final String _token;
  final String _namespace;
  final String _mountPath;

  HashiCorpVaultProvider({required this.config})
    : _httpClient = HttpClient(),
      _address = config.endpoint ?? 'http://localhost:8200',
      _token = config.credentials['token'] ?? '',
      _namespace = config.credentials['namespace'] ?? '',
      _mountPath = config.credentials['mountPath'] ?? 'secret' {
    if (_token.isEmpty) {
      throw RemoteSecretException('Vault token is required');
    }

    if (!config.validateSSL) {
      _httpClient.badCertificateCallback = (cert, host, port) => true;
    }
  }

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
    try {
      final metadata = await getSecretMetadata(name);
      return metadata != null;
    } catch (e) {
      if (e is RemoteSecretNotFoundException) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> listSecrets() async {
    final metadata = await listSecretsWithMetadata();
    return metadata.map((m) => m.name).toList();
  }

  @override
  Future<RemoteSecretValue?> getSecretValue(
    String name, {
    String? version,
  }) async {
    // Check cache first
    if (config.enableCaching) {
      final cached = _cache[name];
      if (cached != null) {
        return cached;
      }
    }

    try {
      final path = version != null
          ? '/v1/$_mountPath/data/$name?version=$version'
          : '/v1/$_mountPath/data/$name';

      final response = await _makeVaultRequest('GET', path);

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw RemoteSecretException('Secret $name has no data');
      }

      final secretData = data['data'] as Map<String, dynamic>?;
      if (secretData == null) {
        throw RemoteSecretException('Secret $name has no secret data');
      }

      final metadata = data['metadata'] as Map<String, dynamic>?;

      // Convert secret data to JSON string for consistency
      final secretValue = jsonEncode(secretData);

      final secretMetadata = RemoteSecretMetadata(
        name: name,
        version: metadata?['version']?.toString(),
        createdAt: metadata?['created_time'] != null
            ? DateTime.parse(metadata!['created_time'] as String)
            : null,
        metadata: {
          'deletion_time': metadata?['deletion_time'],
          'destroyed': metadata?['destroyed'],
          'custom_metadata': metadata?['custom_metadata'],
        },
      );

      final remoteSecretValue = RemoteSecretValue(
        value: secretValue,
        metadata: secretMetadata,
      );

      // Cache the result
      if (config.enableCaching) {
        _cache[name] = remoteSecretValue;
      }

      return remoteSecretValue;
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException(
        'Failed to get secret $name: $e',
        cause: e as Exception?,
      );
    }
  }

  @override
  Future<Map<String, RemoteSecretValue>> getSecretValues(
    List<String> names,
  ) async {
    final results = <String, RemoteSecretValue>{};

    // Vault doesn't have batch get, so we'll do them concurrently
    final futures = names.map((name) => getSecretValue(name));
    final values = await Future.wait(futures);

    for (int i = 0; i < names.length; i++) {
      if (values[i] != null) {
        results[names[i]] = values[i]!;
      }
    }

    return results;
  }

  @override
  Future<List<RemoteSecretMetadata>> listSecretsWithMetadata() async {
    try {
      final path = '/v1/$_mountPath/metadata';
      final response = await _makeVaultRequest('LIST', path);

      final keys = response['data']?['keys'] as List? ?? [];

      // Get metadata for each secret
      final futures = keys.cast<String>().map((key) => getSecretMetadata(key));
      final metadataList = await Future.wait(futures);

      return metadataList.whereType<RemoteSecretMetadata>().toList();
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException(
        'Failed to list secrets: $e',
        cause: e as Exception?,
      );
    }
  }

  @override
  Future<RemoteSecretMetadata?> getSecretMetadata(String name) async {
    try {
      final path = '/v1/$_mountPath/metadata/$name';
      final response = await _makeVaultRequest('GET', path);

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }

      final versions = data['versions'] as Map<String, dynamic>? ?? {};
      final currentVersion = data['current_version']?.toString();
      final customMetadata =
          data['custom_metadata'] as Map<String, dynamic>? ?? {};

      return RemoteSecretMetadata(
        name: name,
        version: currentVersion,
        createdAt: data['created_time'] != null
            ? DateTime.parse(data['created_time'] as String)
            : null,
        lastModified: data['updated_time'] != null
            ? DateTime.parse(data['updated_time'] as String)
            : null,
        metadata: {
          'max_versions': data['max_versions'],
          'cas_required': data['cas_required'],
          'delete_version_after': data['delete_version_after'],
          'versions': versions,
          'custom_metadata': customMetadata,
        },
      );
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException(
        'Failed to get metadata for $name: $e',
        cause: e as Exception?,
      );
    }
  }

  @override
  Future<void> putSecret(
    String name,
    String value, {
    String? description,
    Map<String, String>? tags,
    String? kmsKeyId,
  }) async {
    try {
      // Parse value as JSON if it's a valid JSON string, otherwise treat as plain string
      Map<String, dynamic> secretData;
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map<String, dynamic>) {
          secretData = parsed;
        } else {
          secretData = {'value': value};
        }
      } catch (e) {
        secretData = {'value': value};
      }

      final path = '/v1/$_mountPath/data/$name';
      final payload = {'data': secretData, if (tags != null) 'metadata': tags};

      await _makeVaultRequest('POST', path, payload);
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException(
        'Failed to put secret $name: $e',
        cause: e as Exception?,
      );
    }
  }

  @override
  Future<void> deleteSecret(String name, {bool forceDelete = false}) async {
    try {
      final path = forceDelete
          ? '/v1/$_mountPath/metadata/$name'
          : '/v1/$_mountPath/data/$name';

      await _makeVaultRequest('DELETE', path);
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException(
        'Failed to delete secret $name: $e',
        cause: e as Exception?,
      );
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _makeVaultRequest('GET', '/v1/sys/health');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final startTime = DateTime.now();
      final response = await _makeVaultRequest('GET', '/v1/sys/health');
      final endTime = DateTime.now();

      return {
        'status': 'healthy',
        'service': 'HashiCorp Vault',
        'address': _address,
        'responseTime': endTime.difference(startTime).inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
        'vault_status': response,
      };
    } catch (e) {
      return {
        'status': 'unhealthy',
        'service': 'HashiCorp Vault',
        'address': _address,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Makes an authenticated Vault API request.
  Future<Map<String, dynamic>> _makeVaultRequest(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final url = '$_address$path';
    final uri = Uri.parse(url);
    late HttpClientRequest request;

    switch (method.toUpperCase()) {
      case 'GET':
        request = await _httpClient.getUrl(uri);
        break;
      case 'POST':
        request = await _httpClient.postUrl(uri);
        break;
      case 'PUT':
        request = await _httpClient.putUrl(uri);
        break;
      case 'DELETE':
        request = await _httpClient.deleteUrl(uri);
        break;
      case 'LIST':
        request = await _httpClient.getUrl(uri);
        request.headers.set('X-Vault-Request', 'true');
        break;
      default:
        throw RemoteSecretException('Unsupported HTTP method: $method');
    }

    // Set headers
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('X-Vault-Token', _token);

    if (_namespace.isNotEmpty) {
      request.headers.set('X-Vault-Namespace', _namespace);
    }

    // Add custom headers
    config.customHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });

    // Write payload if provided
    if (payload != null) {
      request.write(jsonEncode(payload));
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseBody.isEmpty) {
        return {};
      }
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      final errorData = responseBody.isNotEmpty
          ? jsonDecode(responseBody) as Map<String, dynamic>
          : <String, dynamic>{};

      final errors = errorData['errors'] as List?;
      final message = errors?.isNotEmpty == true
          ? errors!.first.toString()
          : 'Unknown error';

      if (response.statusCode == 404) {
        throw RemoteSecretNotFoundException(
          message,
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw RemoteSecretAuthException(
          message,
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 429) {
        throw RemoteSecretRateLimitException(
          message,
          statusCode: response.statusCode,
        );
      } else {
        throw RemoteSecretException(message, statusCode: response.statusCode);
      }
    }
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
