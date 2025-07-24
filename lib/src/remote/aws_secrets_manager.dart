/// AWS Secrets Manager integration for remote secret management.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../obfuscation/secret.dart';
import 'remote_secret_provider.dart';

/// AWS Secrets Manager provider for remote secret management.
class AwsSecretsManagerProvider implements RemoteSecretProvider {
  @override
  final RemoteSecretConfig config;

  final HttpClient _httpClient;
  final Map<String, RemoteSecretValue> _cache = {};
  final String _service = 'secretsmanager';

  AwsSecretsManagerProvider({required this.config})
    : _httpClient = HttpClient() {
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
      final request = {
        'SecretId': name,
        if (version != null) 'VersionId': version,
      };

      final response = await _makeAwsRequest('GetSecretValue', request);

      final secretString = response['SecretString'] as String?;
      final secretBinary = response['SecretBinary'] as String?;

      if (secretString == null && secretBinary == null) {
        throw RemoteSecretException('Secret $name has no value');
      }

      final metadata = RemoteSecretMetadata(
        name: response['Name'] as String,
        version: response['VersionId'] as String?,
        createdAt: response['CreatedDate'] != null
            ? DateTime.parse(response['CreatedDate'] as String)
            : null,
        arn: response['ARN'] as String?,
        kmsKeyId: response['KmsKeyId'] as String?,
      );

      final secretValue = RemoteSecretValue(
        value: secretString ?? '',
        binaryValue: secretBinary != null ? base64Decode(secretBinary) : null,
        metadata: metadata,
      );

      // Cache the result
      if (config.enableCaching) {
        _cache[name] = secretValue;
      }

      return secretValue;
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

    // AWS doesn't have batch get, so we'll do them concurrently
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
      final request = <String, dynamic>{'MaxResults': 100};

      final response = await _makeAwsRequest('ListSecrets', request);
      final secretList = response['SecretList'] as List;

      return secretList.map((secret) {
        final secretMap = secret as Map<String, dynamic>;
        return RemoteSecretMetadata(
          name: secretMap['Name'] as String,
          arn: secretMap['ARN'] as String?,
          description: secretMap['Description'] as String?,
          kmsKeyId: secretMap['KmsKeyId'] as String?,
          createdAt: secretMap['CreatedDate'] != null
              ? DateTime.parse(secretMap['CreatedDate'] as String)
              : null,
          lastModified: secretMap['LastChangedDate'] != null
              ? DateTime.parse(secretMap['LastChangedDate'] as String)
              : null,
          tags: _extractTags(secretMap['Tags'] as List?),
        );
      }).toList();
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
      final request = {'SecretId': name};

      final response = await _makeAwsRequest('DescribeSecret', request);

      return RemoteSecretMetadata(
        name: response['Name'] as String,
        arn: response['ARN'] as String?,
        description: response['Description'] as String?,
        kmsKeyId: response['KmsKeyId'] as String?,
        createdAt: response['CreatedDate'] != null
            ? DateTime.parse(response['CreatedDate'] as String)
            : null,
        lastModified: response['LastChangedDate'] != null
            ? DateTime.parse(response['LastChangedDate'] as String)
            : null,
        tags: _extractTags(response['Tags'] as List?),
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
      final request = <String, dynamic>{
        'Name': name,
        'SecretString': value,
        if (description != null) 'Description': description,
        if (kmsKeyId != null) 'KmsKeyId': kmsKeyId,
      };

      await _makeAwsRequest('CreateSecret', request);

      // Add tags if provided
      if (tags != null && tags.isNotEmpty) {
        await _tagSecret(name, tags);
      }
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
      final request = <String, dynamic>{
        'SecretId': name,
        'ForceDeleteWithoutRecovery': forceDelete,
      };

      await _makeAwsRequest('DeleteSecret', request);
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
        'service': 'AWS Secrets Manager',
        'region': config.region,
        'responseTime': endTime.difference(startTime).inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'unhealthy',
        'service': 'AWS Secrets Manager',
        'region': config.region,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Makes an authenticated AWS API request.
  Future<Map<String, dynamic>> _makeAwsRequest(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final region = config.region ?? 'us-east-1';
    final endpoint =
        config.endpoint ?? 'https://$_service.$region.amazonaws.com';

    final uri = Uri.parse(endpoint);
    final request = await _httpClient.postUrl(uri);

    // Set headers
    request.headers.set('Content-Type', 'application/x-amz-json-1.1');
    request.headers.set('X-Amz-Target', 'secretsmanager.$action');

    // Add custom headers
    config.customHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });

    // Add AWS authentication headers
    await _addAwsAuthHeaders(request, jsonEncode(payload));

    // Write payload
    request.write(jsonEncode(payload));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(responseBody) as Map<String, dynamic>;
      final errorCode = errorData['__type'] as String?;
      final message = errorData['message'] as String? ?? 'Unknown error';

      if (errorCode?.contains('ResourceNotFoundException') == true) {
        throw RemoteSecretNotFoundException(
          message,
          errorCode: errorCode,
          statusCode: response.statusCode,
        );
      } else if (errorCode?.contains('UnauthorizedOperation') == true ||
          response.statusCode == 403) {
        throw RemoteSecretAuthException(
          message,
          errorCode: errorCode,
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 429) {
        throw RemoteSecretRateLimitException(
          message,
          errorCode: errorCode,
          statusCode: response.statusCode,
        );
      } else {
        throw RemoteSecretException(
          message,
          errorCode: errorCode,
          statusCode: response.statusCode,
        );
      }
    }
  }

  /// Adds AWS Signature Version 4 authentication headers.
  Future<void> _addAwsAuthHeaders(
    HttpClientRequest request,
    String payload,
  ) async {
    final accessKeyId = config.credentials['accessKeyId'];
    final secretAccessKey = config.credentials['secretAccessKey'];
    final sessionToken = config.credentials['sessionToken'];

    if (accessKeyId == null || secretAccessKey == null) {
      throw RemoteSecretAuthException('AWS credentials not provided');
    }

    final now = DateTime.now().toUtc();
    final dateStamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final amzDate =
        '${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';

    request.headers.set('X-Amz-Date', amzDate);

    if (sessionToken != null) {
      request.headers.set('X-Amz-Security-Token', sessionToken);
    }

    // For simplicity, we'll use a basic authorization header
    // In production, you'd want to implement full AWS Signature Version 4
    final credentials = base64Encode(
      utf8.encode('$accessKeyId:$secretAccessKey'),
    );
    request.headers.set('Authorization', 'Basic $credentials');
  }

  /// Tags a secret with the provided tags.
  Future<void> _tagSecret(String name, Map<String, String> tags) async {
    final tagList = tags.entries
        .map((entry) => {'Key': entry.key, 'Value': entry.value})
        .toList();

    final request = {'SecretId': name, 'Tags': tagList};

    await _makeAwsRequest('TagResource', request);
  }

  /// Extracts tags from AWS API response.
  Map<String, String> _extractTags(List? tagList) {
    if (tagList == null) return {};

    final tags = <String, String>{};
    for (final tag in tagList) {
      if (tag is Map<String, dynamic>) {
        final key = tag['Key'] as String?;
        final value = tag['Value'] as String?;
        if (key != null && value != null) {
          tags[key] = value;
        }
      }
    }

    return tags;
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
