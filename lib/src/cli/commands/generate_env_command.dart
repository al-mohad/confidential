/// Command for generating environment files with encrypted secrets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../configuration/configuration.dart';
import '../../grouping/secret_groups.dart';
import 'base_command.dart';

/// Command for generating environment files from configuration.
class GenerateEnvCommand extends CliCommand {
  @override
  String get name => 'generate-env';

  @override
  String get description => 'Generate environment files with encrypted secrets';

  @override
  ArgParser createArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to the configuration file',
        defaultsTo: 'confidential.yaml',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output environment file path',
        defaultsTo: '.env.encrypted',
      )
      ..addOption(
        'format',
        help: 'Environment file format (dotenv, json, yaml, shell)',
        allowed: ['dotenv', 'json', 'yaml', 'shell'],
        defaultsTo: 'dotenv',
      )
      ..addOption(
        'environment',
        abbr: 'e',
        help: 'Target environment (development, staging, production)',
        allowed: ['development', 'staging', 'production'],
        defaultsTo: 'development',
      )
      ..addFlag(
        'encrypt-values',
        help: 'Encrypt the secret values in the environment file',
        defaultsTo: true,
      )
      ..addFlag(
        'include-metadata',
        help: 'Include metadata in the environment file',
        negatable: false,
      )
      ..addOption(
        'prefix',
        help: 'Prefix for environment variable names',
        defaultsTo: 'CONFIDENTIAL_',
      )
      ..addFlag(
        'uppercase',
        help: 'Convert variable names to uppercase',
        defaultsTo: true,
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show help for this command',
        negatable: false,
      );
  }

  @override
  Future<int> run(ArgResults results, {bool verbose = false}) async {
    if (results['help'] as bool) {
      printHelp(createArgParser());
      return 0;
    }

    final configPath = results['config'] as String;
    final outputPath = results['output'] as String;
    final format = results['format'] as String;
    final environment = results['environment'] as String;
    final encryptValues = results['encrypt-values'] as bool;
    final includeMetadata = results['include-metadata'] as bool;
    final prefix = results['prefix'] as String;
    final uppercase = results['uppercase'] as bool;

    // Validate input file
    if (!validateInputFile(configPath)) {
      return 1;
    }

    try {
      log('Loading configuration from: $configPath', verbose: verbose);

      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);
      log('Loaded ${config.secrets.length} secrets', verbose: verbose);

      // Filter secrets by environment if specified
      final filteredSecrets = _filterSecretsByEnvironment(
        config.secrets,
        environment,
      );
      log(
        'Filtered to ${filteredSecrets.length} secrets for environment: $environment',
        verbose: verbose,
      );

      // Generate environment file content
      final content = await _generateEnvironmentFile(
        config,
        filteredSecrets,
        format,
        environment,
        encryptValues,
        includeMetadata,
        prefix,
        uppercase,
        verbose,
      );

      // Ensure output directory exists
      await ensureOutputDirectory(outputPath);

      // Write output
      log('Writing environment file to: $outputPath', verbose: verbose);
      await File(outputPath).writeAsString(content);

      logSuccess('Successfully generated environment file: $outputPath');

      if (verbose) {
        final lines = content.split('\n').length;
        log('Generated $lines lines in environment file', verbose: true);
      }

      return 0;
    } catch (e) {
      logError('Failed to generate environment file: $e');
      return 1;
    }
  }

  List<SecretDefinition> _filterSecretsByEnvironment(
    List<SecretDefinition> secrets,
    String environment,
  ) {
    return secrets.where((secret) {
      // Check if secret is a GroupedSecretDefinition with environment
      if (secret is GroupedSecretDefinition) {
        if (secret.environment != null) {
          return secret.environment == environment;
        }
      }
      // If no environment specified, include in all environments
      return true;
    }).toList();
  }

  Future<String> _generateEnvironmentFile(
    ConfidentialConfiguration config,
    List<SecretDefinition> secrets,
    String format,
    String environment,
    bool encryptValues,
    bool includeMetadata,
    String prefix,
    bool uppercase,
    bool verbose,
  ) async {
    log('Generating $format environment file...', verbose: verbose);

    switch (format) {
      case 'dotenv':
        return _generateDotEnvFile(
          config,
          secrets,
          environment,
          encryptValues,
          includeMetadata,
          prefix,
          uppercase,
          verbose,
        );
      case 'json':
        return _generateJsonEnvFile(
          config,
          secrets,
          environment,
          encryptValues,
          includeMetadata,
          verbose,
        );
      case 'yaml':
        return _generateYamlEnvFile(
          config,
          secrets,
          environment,
          encryptValues,
          includeMetadata,
          verbose,
        );
      case 'shell':
        return _generateShellEnvFile(
          config,
          secrets,
          environment,
          encryptValues,
          includeMetadata,
          prefix,
          uppercase,
          verbose,
        );
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  String _generateDotEnvFile(
    ConfidentialConfiguration config,
    List<SecretDefinition> secrets,
    String environment,
    bool encryptValues,
    bool includeMetadata,
    String prefix,
    bool uppercase,
    bool verbose,
  ) {
    final buffer = StringBuffer();

    if (includeMetadata) {
      buffer.writeln('# Generated environment file');
      buffer.writeln('# Environment: $environment');
      buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('# Secrets: ${secrets.length}');
      buffer.writeln('');
    }

    final obfuscation = encryptValues ? config.createObfuscation() : null;

    for (final secret in secrets) {
      final varName = _formatVariableName(secret.name, prefix, uppercase);

      if (includeMetadata) {
        buffer.writeln('# ${secret.name} (${secret.dartType})');
        if (secret is GroupedSecretDefinition && secret.namespace != null) {
          buffer.writeln('# Namespace: ${secret.namespace}');
        }
      }

      String value;
      if (encryptValues && obfuscation != null) {
        final nonce =
            DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
        final secretData = utf8.encode(jsonEncode(secret.value));
        final obfuscatedData = obfuscation.obfuscate(secretData, nonce);
        value = base64Encode(obfuscatedData);

        // Also store the nonce for decryption
        buffer.writeln('${varName}_NONCE=$nonce');
      } else {
        value = _escapeEnvValue(secret.value.toString());
      }

      buffer.writeln('$varName=$value');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _generateJsonEnvFile(
    ConfidentialConfiguration config,
    List<SecretDefinition> secrets,
    String environment,
    bool encryptValues,
    bool includeMetadata,
    bool verbose,
  ) {
    final result = <String, dynamic>{};

    if (includeMetadata) {
      result['_metadata'] = {
        'environment': environment,
        'generated': DateTime.now().toIso8601String(),
        'secrets': secrets.length,
        'encrypted': encryptValues,
      };
    }

    final obfuscation = encryptValues ? config.createObfuscation() : null;

    for (final secret in secrets) {
      if (encryptValues && obfuscation != null) {
        final nonce =
            DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
        final secretData = utf8.encode(jsonEncode(secret.value));
        final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

        result[secret.name] = {
          'value': base64Encode(obfuscatedData),
          'nonce': nonce,
          'encrypted': true,
          if (includeMetadata) ...{
            'type': secret.dartType,
            'namespace': secret is GroupedSecretDefinition
                ? secret.namespace
                : null,
          },
        };
      } else {
        result[secret.name] = {
          'value': secret.value,
          'encrypted': false,
          if (includeMetadata) ...{
            'type': secret.dartType,
            'namespace': secret is GroupedSecretDefinition
                ? secret.namespace
                : null,
          },
        };
      }
    }

    return const JsonEncoder.withIndent('  ').convert(result);
  }

  String _generateYamlEnvFile(
    ConfidentialConfiguration config,
    List<SecretDefinition> secrets,
    String environment,
    bool encryptValues,
    bool includeMetadata,
    bool verbose,
  ) {
    final buffer = StringBuffer();

    if (includeMetadata) {
      buffer.writeln('# Generated environment file');
      buffer.writeln('# Environment: $environment');
      buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      buffer.writeln('_metadata:');
      buffer.writeln('  environment: $environment');
      buffer.writeln('  generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('  secrets: ${secrets.length}');
      buffer.writeln('  encrypted: $encryptValues');
      buffer.writeln('');
    }

    buffer.writeln('secrets:');

    final obfuscation = encryptValues ? config.createObfuscation() : null;

    for (final secret in secrets) {
      buffer.writeln('  ${secret.name}:');

      if (encryptValues && obfuscation != null) {
        final nonce =
            DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
        final secretData = utf8.encode(jsonEncode(secret.value));
        final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

        buffer.writeln('    value: "${base64Encode(obfuscatedData)}"');
        buffer.writeln('    nonce: $nonce');
        buffer.writeln('    encrypted: true');
      } else {
        buffer.writeln(
          '    value: "${_escapeYamlValue(secret.value.toString())}"',
        );
        buffer.writeln('    encrypted: false');
      }

      if (includeMetadata) {
        buffer.writeln('    type: ${secret.dartType}');
        if (secret is GroupedSecretDefinition && secret.namespace != null) {
          buffer.writeln('    namespace: ${secret.namespace}');
        }
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _generateShellEnvFile(
    ConfidentialConfiguration config,
    List<SecretDefinition> secrets,
    String environment,
    bool encryptValues,
    bool includeMetadata,
    String prefix,
    bool uppercase,
    bool verbose,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('#!/bin/bash');
    buffer.writeln('# Generated environment script');
    if (includeMetadata) {
      buffer.writeln('# Environment: $environment');
      buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('# Secrets: ${secrets.length}');
    }
    buffer.writeln('');

    final obfuscation = encryptValues ? config.createObfuscation() : null;

    for (final secret in secrets) {
      final varName = _formatVariableName(secret.name, prefix, uppercase);

      if (includeMetadata) {
        buffer.writeln('# ${secret.name} (${secret.dartType})');
      }

      String value;
      if (encryptValues && obfuscation != null) {
        final nonce =
            DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
        final secretData = utf8.encode(jsonEncode(secret.value));
        final obfuscatedData = obfuscation.obfuscate(secretData, nonce);
        value = base64Encode(obfuscatedData);

        buffer.writeln('export ${varName}_NONCE=$nonce');
      } else {
        value = _escapeShellValue(secret.value.toString());
      }

      buffer.writeln('export $varName="$value"');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _formatVariableName(String name, String prefix, bool uppercase) {
    var varName = '$prefix$name';
    if (uppercase) {
      varName = varName.toUpperCase();
    }
    // Replace invalid characters with underscores
    return varName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  }

  String _escapeEnvValue(String value) {
    // Escape special characters for .env format
    if (value.contains(' ') || value.contains('"') || value.contains("'")) {
      return '"${value.replaceAll('"', '\\"')}"';
    }
    return value;
  }

  String _escapeYamlValue(String value) {
    // Escape special characters for YAML format
    return value.replaceAll('"', '\\"');
  }

  String _escapeShellValue(String value) {
    // Escape special characters for shell format
    return value.replaceAll('"', '\\"').replaceAll('\$', '\\\$');
  }
}
