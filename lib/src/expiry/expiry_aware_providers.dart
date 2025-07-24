/// Secret providers with built-in expiry and rotation support.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';

/// Metadata for stored secrets with expiry information.
class SecretMetadata {
  /// When the secret was created.
  final DateTime createdAt;

  /// When the secret expires.
  final DateTime? expiresAt;

  /// TTL for the secret.
  final Duration? ttl;

  /// Algorithm used for encryption.
  final String algorithm;

  /// Version of the secret.
  final int version;

  /// Tags for categorization.
  final List<String> tags;

  /// Custom metadata.
  final Map<String, dynamic> custom;

  const SecretMetadata({
    required this.createdAt,
    this.expiresAt,
    this.ttl,
    required this.algorithm,
    this.version = 1,
    this.tags = const [],
    this.custom = const {},
  });

  /// Creates metadata from a map.
  factory SecretMetadata.fromMap(Map<String, dynamic> map) {
    return SecretMetadata(
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      ttl: map['ttl'] != null
          ? Duration(milliseconds: map['ttl'] as int)
          : null,
      algorithm: map['algorithm'] as String,
      version: map['version'] as int? ?? 1,
      tags: (map['tags'] as List?)?.cast<String>() ?? [],
      custom: (map['custom'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converts metadata to a map.
  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (ttl != null) 'ttl': ttl!.inMilliseconds,
      'algorithm': algorithm,
      'version': version,
      'tags': tags,
      'custom': custom,
    };
  }

  /// Checks if the secret is expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Gets time until expiry.
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }
}

/// Container for secret with metadata.
class SecretWithMetadata {
  /// The secret data.
  final Secret secret;

  /// The metadata.
  final SecretMetadata metadata;

  const SecretWithMetadata({required this.secret, required this.metadata});

  /// Creates from a map.
  factory SecretWithMetadata.fromMap(Map<String, dynamic> map) {
    final secretData = map['secret'] as Map<String, dynamic>;
    final metadataData = map['metadata'] as Map<String, dynamic>;

    return SecretWithMetadata(
      secret: Secret(
        data: Uint8List.fromList(base64Decode(secretData['data'] as String)),
        nonce: secretData['nonce'] as int,
      ),
      metadata: SecretMetadata.fromMap(metadataData),
    );
  }

  /// Converts to a map.
  Map<String, dynamic> toMap() {
    return {
      'secret': {'data': base64Encode(secret.data), 'nonce': secret.nonce},
      'metadata': metadata.toMap(),
    };
  }
}

/// Enhanced secret provider with expiry support.
abstract class ExpiryAwareSecretProvider extends SecretProvider {
  /// Loads a secret with its metadata.
  Future<SecretWithMetadata?> loadSecretWithMetadata(String name);

  /// Saves a secret with metadata.
  Future<void> saveSecretWithMetadata(
    String name,
    SecretWithMetadata secretWithMetadata,
  );

  /// Lists expired secrets.
  Future<List<String>> listExpiredSecrets();

  /// Lists secrets expiring within the given duration.
  Future<List<String>> listSecretsExpiringWithin(Duration duration);

  /// Cleans up expired secrets.
  Future<int> cleanupExpiredSecrets();

  /// Gets metadata for a secret without loading the secret data.
  Future<SecretMetadata?> getSecretMetadata(String name);
}

/// File-based secret provider with expiry support.
class ExpiryAwareFileSecretProvider extends FileSecretProvider
    implements ExpiryAwareSecretProvider {
  ExpiryAwareFileSecretProvider({required super.basePath, super.config});

  @override
  Future<SecretWithMetadata?> loadSecretWithMetadata(String name) async {
    final file = File('$basePath/$name.secret');

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      return SecretWithMetadata.fromMap(data);
    } catch (e) {
      throw Exception('Failed to load secret with metadata $name: $e');
    }
  }

  @override
  Future<void> saveSecretWithMetadata(
    String name,
    SecretWithMetadata secretWithMetadata,
  ) async {
    final file = File('$basePath/$name.secret');
    await file.parent.create(recursive: true);

    final data = secretWithMetadata.toMap();
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<List<String>> listExpiredSecrets() async {
    final allSecrets = await listSecrets();
    final expired = <String>[];

    for (final name in allSecrets) {
      final metadata = await getSecretMetadata(name);
      if (metadata?.isExpired == true) {
        expired.add(name);
      }
    }

    return expired;
  }

  @override
  Future<List<String>> listSecretsExpiringWithin(Duration duration) async {
    final allSecrets = await listSecrets();
    final expiring = <String>[];
    final threshold = DateTime.now().add(duration);

    for (final name in allSecrets) {
      final metadata = await getSecretMetadata(name);
      if (metadata?.expiresAt != null &&
          metadata!.expiresAt!.isBefore(threshold)) {
        expiring.add(name);
      }
    }

    return expiring;
  }

  @override
  Future<int> cleanupExpiredSecrets() async {
    final expired = await listExpiredSecrets();
    int cleaned = 0;

    for (final name in expired) {
      try {
        final file = File('$basePath/$name.secret');
        if (await file.exists()) {
          await file.delete();
          cleaned++;
        }
      } catch (e) {
        // Continue with other files
      }
    }

    return cleaned;
  }

  @override
  Future<SecretMetadata?> getSecretMetadata(String name) async {
    final file = File('$basePath/$name.secret');

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final metadataData = data['metadata'] as Map<String, dynamic>;

      return SecretMetadata.fromMap(metadataData);
    } catch (e) {
      return null;
    }
  }

  /// Saves a secret with expiry configuration.
  Future<void> saveSecretWithExpiry(
    String name,
    Secret secret,
    String algorithm, {
    Duration? ttl,
    DateTime? expiresAt,
    List<String> tags = const [],
    Map<String, dynamic> custom = const {},
  }) async {
    final metadata = SecretMetadata(
      createdAt: DateTime.now(),
      expiresAt: expiresAt ?? (ttl != null ? DateTime.now().add(ttl) : null),
      ttl: ttl,
      algorithm: algorithm,
      tags: tags,
      custom: custom,
    );

    final secretWithMetadata = SecretWithMetadata(
      secret: secret,
      metadata: metadata,
    );

    await saveSecretWithMetadata(name, secretWithMetadata);
  }
}

/// HTTP-based secret provider with expiry support.
class ExpiryAwareHttpSecretProvider extends HttpSecretProvider
    implements ExpiryAwareSecretProvider {
  /// HTTP client for making requests.
  late final HttpClient _httpClient;

  ExpiryAwareHttpSecretProvider({
    required super.baseUrl,
    super.headers,
    super.config,
  }) {
    _httpClient = HttpClient();
  }

  @override
  Future<SecretWithMetadata?> loadSecretWithMetadata(String name) async {
    final uri = Uri.parse('$baseUrl/secrets/$name/metadata');
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to load secret metadata $name',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    return SecretWithMetadata.fromMap(data);
  }

  @override
  Future<void> saveSecretWithMetadata(
    String name,
    SecretWithMetadata secretWithMetadata,
  ) async {
    final uri = Uri.parse('$baseUrl/secrets/$name/metadata');
    final request = await _httpClient.putUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    request.headers.contentType = ContentType.json;

    final data = jsonEncode(secretWithMetadata.toMap());
    request.write(data);

    final response = await request.close();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to save secret metadata $name',
      );
    }
  }

  @override
  Future<List<String>> listExpiredSecrets() async {
    final uri = Uri.parse('$baseUrl/secrets/expired');
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to list expired secrets',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    return (data['secrets'] as List).cast<String>();
  }

  @override
  Future<List<String>> listSecretsExpiringWithin(Duration duration) async {
    final uri = Uri.parse(
      '$baseUrl/secrets/expiring?within=${duration.inSeconds}',
    );
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to list expiring secrets',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    return (data['secrets'] as List).cast<String>();
  }

  @override
  Future<int> cleanupExpiredSecrets() async {
    final uri = Uri.parse('$baseUrl/secrets/cleanup');
    final request = await _httpClient.deleteUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to cleanup expired secrets',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    return data['cleaned'] as int;
  }

  @override
  Future<SecretMetadata?> getSecretMetadata(String name) async {
    final uri = Uri.parse('$baseUrl/secrets/$name/metadata-only');
    final request = await _httpClient.getUrl(uri).timeout(config.timeout);

    headers.forEach((key, value) {
      request.headers.add(key, value);
    });

    final response = await request.close();

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: Failed to get secret metadata $name',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    return SecretMetadata.fromMap(data);
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
    super.close();
  }
}
