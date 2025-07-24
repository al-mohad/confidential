/// Base classes and interfaces for remote secret providers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';

/// Configuration for remote secret providers.
class RemoteSecretConfig extends SecretProviderConfig {
  /// Authentication credentials.
  final Map<String, String> credentials;
  
  /// Region or endpoint configuration.
  final String? region;
  
  /// Custom endpoint URL.
  final String? endpoint;
  
  /// Connection timeout.
  final Duration connectionTimeout;
  
  /// Read timeout.
  final Duration readTimeout;
  
  /// Maximum number of concurrent requests.
  final int maxConcurrentRequests;
  
  /// Whether to use SSL/TLS.
  final bool useSSL;
  
  /// Custom headers to include in requests.
  final Map<String, String> customHeaders;
  
  /// Whether to validate SSL certificates.
  final bool validateSSL;
  
  /// Local cache configuration.
  final LocalCacheConfig? localCache;

  const RemoteSecretConfig({
    this.credentials = const {},
    this.region,
    this.endpoint,
    this.connectionTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 60),
    this.maxConcurrentRequests = 10,
    this.useSSL = true,
    this.customHeaders = const {},
    this.validateSSL = true,
    this.localCache,
    super.timeout = const Duration(seconds: 30),
    super.retryAttempts = 3,
    super.retryDelay = const Duration(seconds: 1),
    super.enableCaching = true,
    super.cacheExpiration = const Duration(minutes: 15),
  });

  /// Creates config with AWS credentials.
  factory RemoteSecretConfig.aws({
    required String accessKeyId,
    required String secretAccessKey,
    String? sessionToken,
    String region = 'us-east-1',
    String? endpoint,
    Duration? cacheExpiration,
    LocalCacheConfig? localCache,
  }) {
    final credentials = <String, String>{
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
    };
    
    if (sessionToken != null) {
      credentials['sessionToken'] = sessionToken;
    }

    return RemoteSecretConfig(
      credentials: credentials,
      region: region,
      endpoint: endpoint,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 15),
      localCache: localCache,
    );
  }

  /// Creates config with Google Cloud credentials.
  factory RemoteSecretConfig.gcp({
    required String projectId,
    String? serviceAccountKey,
    String? accessToken,
    String? endpoint,
    Duration? cacheExpiration,
    LocalCacheConfig? localCache,
  }) {
    final credentials = <String, String>{
      'projectId': projectId,
    };
    
    if (serviceAccountKey != null) {
      credentials['serviceAccountKey'] = serviceAccountKey;
    }
    
    if (accessToken != null) {
      credentials['accessToken'] = accessToken;
    }

    return RemoteSecretConfig(
      credentials: credentials,
      endpoint: endpoint,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 15),
      localCache: localCache,
    );
  }

  /// Creates config with HashiCorp Vault credentials.
  factory RemoteSecretConfig.vault({
    required String address,
    required String token,
    String? namespace,
    String? mountPath,
    Duration? cacheExpiration,
    LocalCacheConfig? localCache,
  }) {
    final credentials = <String, String>{
      'token': token,
    };
    
    if (namespace != null) {
      credentials['namespace'] = namespace;
    }
    
    if (mountPath != null) {
      credentials['mountPath'] = mountPath;
    }

    return RemoteSecretConfig(
      credentials: credentials,
      endpoint: address,
      cacheExpiration: cacheExpiration ?? const Duration(minutes: 15),
      localCache: localCache,
    );
  }
}

/// Configuration for local caching of remote secrets.
class LocalCacheConfig {
  /// Whether to enable persistent local caching.
  final bool enabled;
  
  /// Directory for cache files.
  final String cacheDirectory;
  
  /// Maximum cache size in bytes.
  final int maxCacheSize;
  
  /// Cache expiration time.
  final Duration expiration;
  
  /// Whether to encrypt cached secrets.
  final bool encryptCache;
  
  /// Encryption algorithm for cache.
  final String encryptionAlgorithm;
  
  /// Whether to compress cached data.
  final bool compressCache;
  
  /// Maximum number of cached secrets.
  final int maxCachedSecrets;

  const LocalCacheConfig({
    this.enabled = true,
    this.cacheDirectory = '.confidential_cache',
    this.maxCacheSize = 100 * 1024 * 1024, // 100MB
    this.expiration = const Duration(hours: 1),
    this.encryptCache = true,
    this.encryptionAlgorithm = 'aes-256-gcm',
    this.compressCache = true,
    this.maxCachedSecrets = 1000,
  });
}

/// Metadata for remote secrets.
class RemoteSecretMetadata {
  /// Secret name/identifier.
  final String name;
  
  /// Secret version.
  final String? version;
  
  /// When the secret was created.
  final DateTime? createdAt;
  
  /// When the secret was last modified.
  final DateTime? lastModified;
  
  /// Secret description.
  final String? description;
  
  /// Tags associated with the secret.
  final Map<String, String> tags;
  
  /// Custom metadata.
  final Map<String, dynamic> metadata;
  
  /// ARN or full identifier.
  final String? arn;
  
  /// KMS key ID used for encryption.
  final String? kmsKeyId;

  const RemoteSecretMetadata({
    required this.name,
    this.version,
    this.createdAt,
    this.lastModified,
    this.description,
    this.tags = const {},
    this.metadata = const {},
    this.arn,
    this.kmsKeyId,
  });

  /// Creates metadata from a map.
  factory RemoteSecretMetadata.fromMap(Map<String, dynamic> map) {
    return RemoteSecretMetadata(
      name: map['name'] as String,
      version: map['version'] as String?,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      lastModified: map['lastModified'] != null 
          ? DateTime.parse(map['lastModified'] as String)
          : null,
      description: map['description'] as String?,
      tags: (map['tags'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? {},
      arn: map['arn'] as String?,
      kmsKeyId: map['kmsKeyId'] as String?,
    );
  }

  /// Converts metadata to a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (version != null) 'version': version,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
      if (description != null) 'description': description,
      'tags': tags,
      'metadata': metadata,
      if (arn != null) 'arn': arn,
      if (kmsKeyId != null) 'kmsKeyId': kmsKeyId,
    };
  }
}

/// Container for remote secret with metadata.
class RemoteSecretValue {
  /// The secret data.
  final String value;
  
  /// Binary secret data (if applicable).
  final Uint8List? binaryValue;
  
  /// Secret metadata.
  final RemoteSecretMetadata metadata;

  const RemoteSecretValue({
    required this.value,
    this.binaryValue,
    required this.metadata,
  });

  /// Gets the secret as a string.
  String get stringValue => value;

  /// Gets the secret as binary data.
  Uint8List get bytes => binaryValue ?? Uint8List.fromList(utf8.encode(value));

  /// Converts to a Secret object for use with obfuscation.
  Secret toSecret({int? nonce}) {
    return Secret(
      data: bytes,
      nonce: nonce ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Base interface for remote secret providers.
abstract class RemoteSecretProvider implements SecretProvider {
  /// Configuration for this provider.
  RemoteSecretConfig get config;

  /// Gets a secret value with metadata.
  Future<RemoteSecretValue?> getSecretValue(String name, {String? version});

  /// Gets multiple secret values.
  Future<Map<String, RemoteSecretValue>> getSecretValues(List<String> names);

  /// Lists all available secrets with metadata.
  Future<List<RemoteSecretMetadata>> listSecretsWithMetadata();

  /// Gets metadata for a specific secret.
  Future<RemoteSecretMetadata?> getSecretMetadata(String name);

  /// Creates or updates a secret.
  Future<void> putSecret(String name, String value, {
    String? description,
    Map<String, String>? tags,
    String? kmsKeyId,
  });

  /// Deletes a secret.
  Future<void> deleteSecret(String name, {bool forceDelete = false});

  /// Tests the connection to the remote service.
  Future<bool> testConnection();

  /// Gets the service health status.
  Future<Map<String, dynamic>> getHealthStatus();
}

/// Exception thrown by remote secret providers.
class RemoteSecretException implements Exception {
  /// Error message.
  final String message;
  
  /// Error code from the remote service.
  final String? errorCode;
  
  /// HTTP status code (if applicable).
  final int? statusCode;
  
  /// Original exception that caused this error.
  final Exception? cause;

  const RemoteSecretException(
    this.message, {
    this.errorCode,
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('RemoteSecretException: $message');
    
    if (errorCode != null) {
      buffer.write(' (Code: $errorCode)');
    }
    
    if (statusCode != null) {
      buffer.write(' (HTTP: $statusCode)');
    }
    
    if (cause != null) {
      buffer.write(' (Caused by: $cause)');
    }
    
    return buffer.toString();
  }
}

/// Authentication exception for remote providers.
class RemoteSecretAuthException extends RemoteSecretException {
  const RemoteSecretAuthException(
    super.message, {
    super.errorCode,
    super.statusCode,
    super.cause,
  });
}

/// Network exception for remote providers.
class RemoteSecretNetworkException extends RemoteSecretException {
  const RemoteSecretNetworkException(
    super.message, {
    super.errorCode,
    super.statusCode,
    super.cause,
  });
}

/// Rate limiting exception for remote providers.
class RemoteSecretRateLimitException extends RemoteSecretException {
  /// When to retry the request.
  final DateTime? retryAfter;

  const RemoteSecretRateLimitException(
    super.message, {
    this.retryAfter,
    super.errorCode,
    super.statusCode,
    super.cause,
  });
}

/// Secret not found exception.
class RemoteSecretNotFoundException extends RemoteSecretException {
  const RemoteSecretNotFoundException(
    super.message, {
    super.errorCode,
    super.statusCode,
    super.cause,
  });
}
