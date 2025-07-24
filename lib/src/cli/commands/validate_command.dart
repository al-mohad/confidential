/// Command for validating configuration and secrets.
library;

import 'dart:io';

import 'package:args/args.dart';

import '../../configuration/configuration.dart';
import '../../grouping/secret_groups.dart';
import '../../platform/platform_support.dart';
import 'base_command.dart';

/// Command for validating configuration files and secrets.
class ValidateCommand extends CliCommand {
  @override
  String get name => 'validate';

  @override
  String get description => 'Validate configuration files and secrets';

  @override
  ArgParser createArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to the configuration file',
        defaultsTo: 'confidential.yaml',
      )
      ..addFlag(
        'strict',
        help: 'Enable strict validation mode',
        negatable: false,
      )
      ..addFlag(
        'check-platform',
        help: 'Check platform-specific security recommendations',
        defaultsTo: true,
      )
      ..addFlag(
        'check-duplicates',
        help: 'Check for duplicate secret names',
        defaultsTo: true,
      )
      ..addFlag(
        'check-algorithms',
        help: 'Validate obfuscation algorithms',
        defaultsTo: true,
      )
      ..addFlag(
        'fix',
        help: 'Attempt to fix validation issues automatically',
        negatable: false,
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
    final strict = results['strict'] as bool;
    final checkPlatform = results['check-platform'] as bool;
    final checkDuplicates = results['check-duplicates'] as bool;
    final checkAlgorithms = results['check-algorithms'] as bool;
    final fix = results['fix'] as bool;

    // Validate input file exists
    if (!validateInputFile(configPath)) {
      return 1;
    }

    try {
      log('Validating configuration: $configPath', verbose: verbose);

      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);
      log(
        'Loaded configuration with ${config.secrets.length} secrets',
        verbose: verbose,
      );

      var hasErrors = false;
      var hasWarnings = false;
      final issues = <ValidationIssue>[];

      // Perform validation checks
      if (checkDuplicates) {
        final duplicateIssues = _checkDuplicateNames(config);
        issues.addAll(duplicateIssues);
      }

      if (checkAlgorithms) {
        final algorithmIssues = _checkAlgorithms(config);
        issues.addAll(algorithmIssues);
      }

      if (checkPlatform) {
        final platformIssues = _checkPlatformSecurity(config);
        issues.addAll(platformIssues);
      }

      // Additional strict mode checks
      if (strict) {
        final strictIssues = _performStrictValidation(config);
        issues.addAll(strictIssues);
      }

      // Report issues
      for (final issue in issues) {
        switch (issue.severity) {
          case ValidationSeverity.error:
            logError(issue.message);
            hasErrors = true;
            break;
          case ValidationSeverity.warning:
            logWarning(issue.message);
            hasWarnings = true;
            break;
          case ValidationSeverity.info:
            print('ℹ️  ${issue.message}');
            break;
        }
      }

      // Attempt fixes if requested
      if (fix && issues.any((i) => i.fixable)) {
        log('Attempting to fix issues...', verbose: verbose);
        final fixedConfig = await _applyFixes(config, issues);

        if (fixedConfig != null) {
          // Write fixed configuration back
          await _writeFixedConfiguration(configPath, fixedConfig);
          logSuccess('Applied fixes to configuration file');
        }
      }

      // Summary
      print('');
      print('Validation Summary:');
      print('  Total issues: ${issues.length}');
      print(
        '  Errors: ${issues.where((i) => i.severity == ValidationSeverity.error).length}',
      );
      print(
        '  Warnings: ${issues.where((i) => i.severity == ValidationSeverity.warning).length}',
      );
      print(
        '  Info: ${issues.where((i) => i.severity == ValidationSeverity.info).length}',
      );

      if (hasErrors) {
        logError('Validation failed with errors');
        return 1;
      } else if (hasWarnings && strict) {
        logWarning('Validation completed with warnings (strict mode)');
        return 1;
      } else {
        logSuccess('Validation completed successfully');
        return 0;
      }
    } catch (e) {
      logError('Validation failed: $e');
      return 1;
    }
  }

  List<ValidationIssue> _checkDuplicateNames(ConfidentialConfiguration config) {
    final issues = <ValidationIssue>[];
    final seenNames = <String>{};

    for (final secret in config.secrets) {
      if (seenNames.contains(secret.name)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            message: 'Duplicate secret name: ${secret.name}',
            fixable: false,
          ),
        );
      } else {
        seenNames.add(secret.name);
      }
    }

    return issues;
  }

  List<ValidationIssue> _checkAlgorithms(ConfidentialConfiguration config) {
    final issues = <ValidationIssue>[];
    final validAlgorithmSteps = [
      'shuffle',
      'xor',
      'encrypt using aes-256-gcm',
      'encrypt using chacha20-poly1305',
      'compress using zlib',
      'compress using gzip',
    ];

    // Check main algorithm steps
    for (final algorithmStep in config.algorithm) {
      if (!validAlgorithmSteps.contains(algorithmStep)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            message: 'Invalid algorithm: $algorithmStep',
            fixable: true,
          ),
        );
      }
    }

    // Check individual secret algorithms (only for GroupedSecretDefinition)
    for (final secret in config.secrets) {
      if (secret is GroupedSecretDefinition) {
        // GroupedSecretDefinition doesn't have algorithm property in current implementation
        // This check would be added if algorithm property is added to GroupedSecretDefinition
      }
    }

    return issues;
  }

  List<ValidationIssue> _checkPlatformSecurity(
    ConfidentialConfiguration config,
  ) {
    final issues = <ValidationIssue>[];
    final platform = PlatformDetector.detectPlatform();
    final securityInfo = PlatformDetector.getSecurityInfo(platform);

    // Platform-specific warnings
    if (platform == ConfidentialPlatform.web) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message:
              'Web platform detected: secrets will not be secure in JavaScript',
          fixable: false,
        ),
      );

      // Check for sensitive secrets on web
      for (final secret in config.secrets) {
        if (_isSensitiveSecret(secret.name)) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              message:
                  'Sensitive secret "${secret.name}" should not be used on web platform',
              fixable: false,
            ),
          );
        }
      }
    }

    // Security level warnings
    if (securityInfo.securityLevel == SecurityLevel.low ||
        securityInfo.securityLevel == SecurityLevel.none) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message:
              'Platform has ${securityInfo.securityLevel.name} security level',
          fixable: false,
        ),
      );
    }

    return issues;
  }

  List<ValidationIssue> _performStrictValidation(
    ConfidentialConfiguration config,
  ) {
    final issues = <ValidationIssue>[];

    // Check for weak secret values
    for (final secret in config.secrets) {
      final value = secret.value.toString();

      if (value.length < 8) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            message: 'Secret "${secret.name}" has weak value (too short)',
            fixable: false,
          ),
        );
      }

      if (value.toLowerCase() == value || value.toUpperCase() == value) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            message: 'Secret "${secret.name}" lacks character diversity',
            fixable: false,
          ),
        );
      }

      if (RegExp(r'^[0-9]+$').hasMatch(value)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            message: 'Secret "${secret.name}" is numeric only',
            fixable: false,
          ),
        );
      }
    }

    // Check namespace consistency
    final namespaces = config.secrets.map((s) => s.namespace).toSet();
    if (namespaces.length > 5) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.info,
          message:
              'Many namespaces detected (${namespaces.length}), consider consolidation',
          fixable: false,
        ),
      );
    }

    return issues;
  }

  Future<ConfidentialConfiguration?> _applyFixes(
    ConfidentialConfiguration config,
    List<ValidationIssue> issues,
  ) async {
    var fixedConfig = config;
    var hasChanges = false;

    for (final issue in issues.where((i) => i.fixable)) {
      if (issue.message.contains('Invalid algorithm')) {
        // Fix invalid algorithms
        fixedConfig = ConfidentialConfiguration(
          algorithm: [
            'encrypt using aes-256-gcm',
            'shuffle',
          ], // Default to secure algorithm
          secrets: fixedConfig.secrets,
          defaultAccessModifier: fixedConfig.defaultAccessModifier,
          defaultNamespace: fixedConfig.defaultNamespace,
        );
        hasChanges = true;
      }
    }

    return hasChanges ? fixedConfig : null;
  }

  Future<void> _writeFixedConfiguration(
    String configPath,
    ConfidentialConfiguration config,
  ) async {
    // Create backup
    final backupPath = '$configPath.backup';
    await File(configPath).copy(backupPath);

    // Write fixed configuration
    // Note: This is simplified - in practice, you'd need to serialize back to YAML
    final content =
        '''
# Fixed configuration file
algorithm:
  - ${config.algorithm.first}

defaultAccessModifier: ${config.defaultAccessModifier}
defaultNamespace: ${config.defaultNamespace}

secrets:
${config.secrets.map((s) => '''  - name: ${s.name}
    value: ${s.value}
    algorithm: ${config.algorithm.first}''').join('\n')}
''';

    await File(configPath).writeAsString(content);
  }

  bool _isSensitiveSecret(String name) {
    final sensitivePatterns = [
      'password',
      'secret',
      'key',
      'token',
      'private',
      'credential',
    ];
    final lowerName = name.toLowerCase();
    return sensitivePatterns.any((pattern) => lowerName.contains(pattern));
  }
}

/// Represents a validation issue.
class ValidationIssue {
  final ValidationSeverity severity;
  final String message;
  final bool fixable;

  const ValidationIssue({
    required this.severity,
    required this.message,
    required this.fixable,
  });
}

/// Severity levels for validation issues.
enum ValidationSeverity { error, warning, info }
