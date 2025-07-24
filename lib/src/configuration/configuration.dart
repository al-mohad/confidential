/// Configuration system for obfuscation.
library;

import 'dart:io' if (dart.library.html) 'dart:html';

import 'package:confidential/src/obfuscation/encryption/key_management.dart';
import 'package:yaml/yaml.dart';

import '../analytics/audit_logger.dart';
import '../grouping/secret_groups.dart';
import '../obfuscation/compression/compression.dart';
import '../obfuscation/encryption/encryption.dart';
import '../obfuscation/obfuscation.dart';
import '../obfuscation/randomization/randomization.dart';

/// Configuration for the obfuscation process.
class ConfidentialConfiguration {
  /// The obfuscation algorithm steps.
  final List<String> algorithm;

  /// The default access modifier for generated code.
  final String defaultAccessModifier;

  /// The default namespace for generated code.
  final String defaultNamespace;

  /// Whether to use experimental mode.
  final bool experimentalMode;

  /// Whether to use internal imports.
  final bool internalImport;

  /// The list of secrets to obfuscate.
  final List<SecretDefinition> secrets;

  /// Key management configuration.
  final KeyManagementConfig? keyManagement;

  /// Secret group manager for enhanced organization.
  final SecretGroupManager? groupManager;

  /// Analytics configuration for audit logging.
  final AnalyticsConfig? analytics;

  const ConfidentialConfiguration({
    required this.algorithm,
    this.defaultAccessModifier = 'internal',
    this.defaultNamespace = 'create Secrets',
    this.experimentalMode = false,
    this.internalImport = false,
    required this.secrets,
    this.keyManagement,
    this.groupManager,
    this.analytics,
  });

  /// Loads configuration from a YAML file.
  static ConfidentialConfiguration fromFile(String path) {
    final content = _readFileSync(path);
    return fromYaml(content);
  }

  /// Platform-specific file reading
  static String _readFileSync(String path) {
    // This method is only used in CLI/server environments, not web
    // Web environments should use fromYaml directly with pre-loaded content
    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw ConfigurationException('Configuration file not found: $path');
      }
      return file.readAsStringSync();
    } catch (e) {
      throw ConfigurationException('Failed to read configuration file: $e');
    }
  }

  /// Loads configuration from YAML content.
  static ConfidentialConfiguration fromYaml(String yamlContent) {
    try {
      final yaml = loadYaml(yamlContent) as Map;

      final algorithm = (yaml['algorithm'] as List?)?.cast<String>() ?? [];
      if (algorithm.isEmpty) {
        throw ConfigurationException('Algorithm is required');
      }

      final secretsYaml = yaml['secrets'] as List?;
      if (secretsYaml == null || secretsYaml.isEmpty) {
        throw ConfigurationException('Secrets are required');
      }

      final secrets = secretsYaml
          .map((s) => SecretDefinition.fromYaml(s))
          .toList();

      // Parse key management configuration if present
      KeyManagementConfig? keyManagement;
      final keyMgmtYaml = yaml['keyManagement'] as Map?;
      if (keyMgmtYaml != null) {
        keyManagement = KeyManagementConfig.fromMap(
          keyMgmtYaml.cast<String, dynamic>(),
        );
      }

      // Parse group manager configuration if present
      SecretGroupManager? groupManager;
      if (yaml.containsKey('groups') || yaml.containsKey('namespaces')) {
        groupManager = SecretGroupManager.fromYaml(
          yaml.cast<String, dynamic>(),
        );
      }

      // Parse analytics configuration if present
      AnalyticsConfig? analytics;
      final analyticsYaml = yaml['analytics'] as Map?;
      if (analyticsYaml != null) {
        analytics = AnalyticsConfig.fromJson(
          analyticsYaml.cast<String, dynamic>(),
        );
      }

      return ConfidentialConfiguration(
        algorithm: algorithm,
        defaultAccessModifier:
            yaml['defaultAccessModifier'] as String? ?? 'internal',
        defaultNamespace:
            yaml['defaultNamespace'] as String? ?? 'create Secrets',
        experimentalMode: yaml['experimentalMode'] as bool? ?? false,
        internalImport: yaml['internalImport'] as bool? ?? false,
        secrets: secrets,
        keyManagement: keyManagement,
        groupManager: groupManager,
        analytics: analytics,
      );
    } catch (e) {
      throw ConfigurationException('Failed to parse configuration: $e');
    }
  }

  /// Creates the obfuscation algorithm from the configuration.
  Obfuscation createObfuscation() {
    final steps = <ObfuscationAlgorithm>[];
    KeyManager? keyManager;

    // Create key manager if key management is configured
    if (keyManagement != null) {
      keyManager = KeyManager(keyManagement!);
    }

    for (final step in algorithm) {
      final algorithm = _parseAlgorithmStep(step, keyManager);
      steps.add(algorithm);
    }

    return Obfuscation(steps);
  }

  ObfuscationAlgorithm _parseAlgorithmStep(
    String step,
    KeyManager? keyManager,
  ) {
    final parts = step.toLowerCase().split(' ');

    if (parts.length >= 3 && parts[0] == 'encrypt' && parts[1] == 'using') {
      final algorithm = parts.sublist(2).join('-');
      return EncryptionFactory.create(algorithm, keyManager: keyManager);
    }

    if (parts.length >= 3 && parts[0] == 'compress' && parts[1] == 'using') {
      final algorithm = parts.sublist(2).join('-');
      return CompressionFactory.create(algorithm);
    }

    if (parts.length == 1 && parts[0] == 'shuffle') {
      return const DataShuffler();
    }

    if (parts.length == 1 && parts[0] == 'xor') {
      return const XorRandomization();
    }

    throw ConfigurationException('Unknown algorithm step: $step');
  }
}

/// Definition of a secret to be obfuscated.
class SecretDefinition {
  /// The name of the secret.
  final String name;

  /// The value(s) of the secret.
  final dynamic value;

  /// The access modifier for the generated property.
  final String? accessModifier;

  /// The namespace for the generated property.
  final String? namespace;

  const SecretDefinition({
    required this.name,
    required this.value,
    this.accessModifier,
    this.namespace,
  });

  /// Creates a SecretDefinition from YAML data.
  static SecretDefinition fromYaml(dynamic yaml) {
    if (yaml is! Map) {
      throw ConfigurationException('Secret definition must be a map');
    }

    final name = yaml['name'] as String?;
    if (name == null || name.isEmpty) {
      throw ConfigurationException('Secret name is required');
    }

    final value = yaml['value'];
    if (value == null) {
      throw ConfigurationException('Secret value is required');
    }

    return SecretDefinition(
      name: name,
      value: value,
      accessModifier: yaml['accessModifier'] as String?,
      namespace: yaml['namespace'] as String?,
    );
  }

  /// Gets the Dart type for this secret's value.
  String get dartType {
    if (value is String) {
      return 'String';
    } else if (value is List) {
      return 'List<String>';
    } else if (value is int) {
      return 'int';
    } else if (value is double) {
      return 'double';
    } else if (value is bool) {
      return 'bool';
    } else {
      return 'dynamic';
    }
  }

  /// Gets the effective access modifier.
  String getAccessModifier(String defaultModifier) {
    return accessModifier ?? defaultModifier;
  }

  /// Gets the effective namespace.
  String getNamespace(String defaultNamespace) {
    return namespace ?? defaultNamespace;
  }
}

/// Namespace definition for organizing generated code.
class NamespaceDefinition {
  /// Whether this creates a new namespace or extends an existing one.
  final bool isExtension;

  /// The name of the namespace.
  final String name;

  /// The module to import (for extensions).
  final String? module;

  const NamespaceDefinition({
    required this.isExtension,
    required this.name,
    this.module,
  });

  /// Parses a namespace definition string.
  static NamespaceDefinition parse(String definition) {
    final parts = definition.trim().split(' ');

    if (parts.length >= 2 && parts[0] == 'create') {
      return NamespaceDefinition(
        isExtension: false,
        name: parts.sublist(1).join(' '),
      );
    }

    if (parts.length >= 2 && parts[0] == 'extend') {
      String? module;
      String name;

      final fromIndex = parts.indexOf('from');
      if (fromIndex != -1 && fromIndex < parts.length - 1) {
        name = parts.sublist(1, fromIndex).join(' ');
        module = parts.sublist(fromIndex + 1).join(' ');
      } else {
        name = parts.sublist(1).join(' ');
      }

      return NamespaceDefinition(isExtension: true, name: name, module: module);
    }

    throw ConfigurationException('Invalid namespace definition: $definition');
  }
}

/// Exception thrown when configuration is invalid.
class ConfigurationException implements Exception {
  final String message;

  const ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}
