/// Google Secret Manager integration for remote secret management.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../obfuscation/secret.dart';
import 'remote_secret_provider.dart';

/// Google Secret Manager provider for remote secret management.
class GoogleSecretManagerProvider implements RemoteSecretProvider {
  @override
  final RemoteSecretConfig config;
  
  final HttpClient _httpClient;
  final Map<String, RemoteSecretValue> _cache = {};
  final String _baseUrl;
  final String _projectId;

  GoogleSecretManagerProvider({
    required this.config,
  }) : _httpClient = HttpClient(),
       _projectId = config.credentials['projectId'] ?? '',
       _baseUrl = config.endpoint ?? 'https://secretmanager.googleapis.com' {
    
    if (_projectId.isEmpty) {
      throw RemoteSecretException('Google Cloud Project ID is required');
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
  Future<RemoteSecretValue?> getSecretValue(String name, {String? version}) async {
    // Check cache first
    if (config.enableCaching) {
      final cached = _cache[name];
      if (cached != null) {
        return cached;
      }
    }

    try {
      final versionPath = version ?? 'latest';
      final secretPath = 'projects/$_projectId/secrets/$name/versions/$versionPath';
      final url = '$_baseUrl/v1/$secretPath:access';
      
      final response = await _makeGoogleRequest('GET', url);
      
      final payload = response['payload'] as Map<String, dynamic>;
      final data = payload['data'] as String?;
      
      if (data == null) {
        throw RemoteSecretException('Secret $name has no data');
      }

      final secretBytes = base64Decode(data);
      final secretString = utf8.decode(secretBytes);

      final metadata = RemoteSecretMetadata(
        name: response['name'] as String,
        version: _extractVersionFromName(response['name'] as String),
        createdAt: response['createTime'] != null 
            ? DateTime.parse(response['createTime'] as String)
            : null,
      );

      final secretValue = RemoteSecretValue(
        value: secretString,
        binaryValue: secretBytes,
        metadata: metadata,
      );

      // Cache the result
      if (config.enableCaching) {
        _cache[name] = secretValue;
      }

      return secretValue;
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException('Failed to get secret $name: $e', cause: e as Exception?);
    }
  }

  @override
  Future<Map<String, RemoteSecretValue>> getSecretValues(List<String> names) async {
    final results = <String, RemoteSecretValue>{};
    
    // Google doesn't have batch get, so we'll do them concurrently
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
      final url = '$_baseUrl/v1/projects/$_projectId/secrets';
      final response = await _makeGoogleRequest('GET', url);
      
      final secrets = response['secrets'] as List? ?? [];
      
      return secrets.map((secret) {
        final secretMap = secret as Map<String, dynamic>;
        final labels = secretMap['labels'] as Map<String, dynamic>? ?? {};
        
        return RemoteSecretMetadata(
          name: _extractSecretNameFromPath(secretMap['name'] as String),
          createdAt: secretMap['createTime'] != null 
              ? DateTime.parse(secretMap['createTime'] as String)
              : null,
          tags: labels.cast<String, String>(),
          metadata: {
            'replication': secretMap['replication'],
            'etag': secretMap['etag'],
          },
        );
      }).toList();
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException('Failed to list secrets: $e', cause: e as Exception?);
    }
  }

  @override
  Future<RemoteSecretMetadata?> getSecretMetadata(String name) async {
    try {
      final url = '$_baseUrl/v1/projects/$_projectId/secrets/$name';
      final response = await _makeGoogleRequest('GET', url);
      
      final labels = response['labels'] as Map<String, dynamic>? ?? {};
      
      return RemoteSecretMetadata(
        name: _extractSecretNameFromPath(response['name'] as String),
        createdAt: response['createTime'] != null 
            ? DateTime.parse(response['createTime'] as String)
            : null,
        tags: labels.cast<String, String>(),
        metadata: {
          'replication': response['replication'],
          'etag': response['etag'],
        },
      );
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException('Failed to get metadata for $name: $e', cause: e as Exception?);
    }
  }

  @override
  Future<void> putSecret(String name, String value, {
    String? description,
    Map<String, String>? tags,
    String? kmsKeyId,
  }) async {
    try {
      // First create the secret
      final createUrl = '$_baseUrl/v1/projects/$_projectId/secrets';
      final createPayload = <String, dynamic>{
        'secretId': name,
        'secret': {
          'replication': {
            'automatic': {},
          },
          if (tags != null) 'labels': tags,
        },
      };

      await _makeGoogleRequest('POST', createUrl, createPayload);

      // Then add the secret version with the value
      final addVersionUrl = '$_baseUrl/v1/projects/$_projectId/secrets/$name:addVersion';
      final versionPayload = {
        'payload': {
          'data': base64Encode(utf8.encode(value)),
        },
      };

      await _makeGoogleRequest('POST', addVersionUrl, versionPayload);
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException('Failed to put secret $name: $e', cause: e as Exception?);
    }
  }

  @override
  Future<void> deleteSecret(String name, {bool forceDelete = false}) async {
    try {
      final url = '$_baseUrl/v1/projects/$_projectId/secrets/$name';
      await _makeGoogleRequest('DELETE', url);
    } catch (e) {
      if (e is RemoteSecretException) rethrow;
      throw RemoteSecretException('Failed to delete secret $name: $e', cause: e as Exception?);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await listSecretsWithMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final startTime = DateTime.now();
      await listSecretsWithMetadata();
      final endTime = DateTime.now();
      
      return {
        'status': 'healthy',
        'service': 'Google Secret Manager',
        'projectId': _projectId,
        'responseTime': endTime.difference(startTime).inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'unhealthy',
        'service': 'Google Secret Manager',
        'projectId': _projectId,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Makes an authenticated Google Cloud API request.
  Future<Map<String, dynamic>> _makeGoogleRequest(String method, String url, [Map<String, dynamic>? payload]) async {
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
      default:
        throw RemoteSecretException('Unsupported HTTP method: $method');
    }
    
    // Set headers
    request.headers.set('Content-Type', 'application/json');
    
    // Add authentication
    await _addGoogleAuthHeaders(request);
    
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
      
      final error = errorData['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? 'Unknown error';
      final code = error?['code'] as int?;
      
      if (response.statusCode == 404) {
        throw RemoteSecretNotFoundException(message, statusCode: response.statusCode);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw RemoteSecretAuthException(message, statusCode: response.statusCode);
      } else if (response.statusCode == 429) {
        throw RemoteSecretRateLimitException(message, statusCode: response.statusCode);
      } else {
        throw RemoteSecretException(message, statusCode: response.statusCode);
      }
    }
  }

  /// Adds Google Cloud authentication headers.
  Future<void> _addGoogleAuthHeaders(HttpClientRequest request) async {
    final accessToken = config.credentials['accessToken'];
    final serviceAccountKey = config.credentials['serviceAccountKey'];
    
    if (accessToken != null) {
      request.headers.set('Authorization', 'Bearer $accessToken');
    } else if (serviceAccountKey != null) {
      // In a real implementation, you'd use the service account key to generate a JWT
      // For simplicity, we'll assume the service account key is already a token
      request.headers.set('Authorization', 'Bearer $serviceAccountKey');
    } else {
      throw RemoteSecretAuthException('Google Cloud credentials not provided');
    }
  }

  /// Extracts secret name from Google Cloud resource path.
  String _extractSecretNameFromPath(String path) {
    final parts = path.split('/');
    return parts.last;
  }

  /// Extracts version from Google Cloud resource path.
  String? _extractVersionFromName(String name) {
    final parts = name.split('/');
    if (parts.length >= 2 && parts[parts.length - 2] == 'versions') {
      return parts.last;
    }
    return null;
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
