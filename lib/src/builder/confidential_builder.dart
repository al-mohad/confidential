/// Build system integration for dart-confidential.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:build/build.dart';
import 'package:path/path.dart' as path;

import '../code_generation/generator.dart';
import '../configuration/configuration.dart';
import '../platform/platform_support.dart';

/// Enhanced builder for generating obfuscated code with platform support.
class ConfidentialBuilder implements Builder {
  final BuilderOptions options;

  const ConfidentialBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => {
    'confidential.yaml': ['lib/generated/confidential.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    log.info('Processing ${inputId.path}');

    // Read the configuration file
    final configContent = await buildStep.readAsString(inputId);

    try {
      // Parse configuration
      final config = ConfidentialConfiguration.fromYaml(configContent);

      // Platform detection and warnings
      final platform = PlatformDetector.detectPlatform();
      final securityInfo = PlatformDetector.getSecurityInfo(platform);

      if (securityInfo.shouldShowWarnings) {
        log.warning(
          'Platform ${platform.name} has ${securityInfo.securityLevel.name} security level',
        );
        for (final warning in securityInfo.warnings.take(2)) {
          log.warning('Security: $warning');
        }
      }

      // Generate enhanced code with platform awareness
      final generator = EnhancedCodeGenerator(config, options);
      final generatedCode = await generator.generateWithPlatformSupport(
        platform,
      );

      // Write output
      final outputPath = _getOutputPath(inputId, options);
      final outputId = AssetId(inputId.package, outputPath);
      await buildStep.writeAsString(outputId, generatedCode);

      // Generate additional assets if configured
      await _generateAdditionalAssets(buildStep, config, options);

      log.info(
        'Generated obfuscated code: ${outputId.path} (${config.secrets.length} secrets)',
      );

      if (platform == ConfidentialPlatform.web) {
        log.warning(
          'Web platform detected - secrets will not be secure in JavaScript',
        );
      }
    } catch (e) {
      log.severe('Failed to generate obfuscated code: $e');
      throw BuildException('Confidential code generation failed: $e');
    }
  }

  String _getOutputPath(AssetId inputId, BuilderOptions options) {
    final customOutput = options.config['output_file'] as String?;
    if (customOutput != null) {
      return customOutput;
    }

    final inputPath = inputId.path;
    final inputDir = inputPath.contains('/')
        ? inputPath.substring(0, inputPath.lastIndexOf('/'))
        : '';
    return inputDir.isEmpty
        ? 'lib/generated/confidential.dart'
        : '$inputDir/lib/generated/confidential.dart';
  }

  Future<void> _generateAdditionalAssets(
    BuildStep buildStep,
    ConfidentialConfiguration config,
    BuilderOptions options,
  ) async {
    // Generate encrypted assets if configured
    final generateAssets = options.config['generate_assets'] as bool? ?? false;
    if (generateAssets) {
      final assetsDir =
          options.config['assets_dir'] as String? ?? 'assets/encrypted';
      await _generateEncryptedAssets(buildStep, config, assetsDir);
    }

    // Generate environment files if configured
    final generateEnv = options.config['generate_env'] as bool? ?? false;
    if (generateEnv) {
      final envFormat = options.config['env_format'] as String? ?? 'dotenv';
      await _generateEnvironmentFile(buildStep, config, envFormat);
    }
  }

  Future<void> _generateEncryptedAssets(
    BuildStep buildStep,
    ConfidentialConfiguration config,
    String assetsDir,
  ) async {
    final obfuscation = config.createObfuscation();

    for (final secret in config.secrets) {
      final nonce =
          DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
      final secretData = Uint8List.fromList(secret.value.toString().codeUnits);
      final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

      final assetPath = path.join(assetsDir, '${secret.name}.bin');
      final assetId = AssetId(buildStep.inputId.package, assetPath);

      await buildStep.writeAsBytes(assetId, obfuscatedData);
    }

    log.info('Generated ${config.secrets.length} encrypted asset files');
  }

  Future<void> _generateEnvironmentFile(
    BuildStep buildStep,
    ConfidentialConfiguration config,
    String format,
  ) async {
    final envContent = _generateEnvContent(config, format);
    final envPath = '.env.encrypted';
    final envId = AssetId(buildStep.inputId.package, envPath);

    await buildStep.writeAsString(envId, envContent);
    log.info('Generated environment file: $envPath');
  }

  String _generateEnvContent(ConfidentialConfiguration config, String format) {
    final buffer = StringBuffer();

    switch (format) {
      case 'dotenv':
        buffer.writeln('# Generated environment file');
        buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
        buffer.writeln('');

        for (final secret in config.secrets) {
          final varName = 'CONFIDENTIAL_${secret.name.toUpperCase()}';
          buffer.writeln('$varName=${secret.value}');
        }
        break;

      case 'json':
        final envData = <String, dynamic>{};
        for (final secret in config.secrets) {
          envData[secret.name] = secret.value;
        }
        buffer.write(const JsonEncoder.withIndent('  ').convert(envData));
        break;
    }

    return buffer.toString();
  }
}

/// Enhanced code generator with platform support and additional features.
class EnhancedCodeGenerator extends CodeGenerator {
  final BuilderOptions options;

  EnhancedCodeGenerator(super.config, this.options);

  /// Generates code with platform-specific optimizations and warnings.
  Future<String> generateWithPlatformSupport(
    ConfidentialPlatform platform,
  ) async {
    final buffer = StringBuffer();

    // Add platform-specific header
    buffer.writeln('// Generated by dart-confidential build_runner');
    buffer.writeln('// Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('// Platform: ${platform.name}');
    buffer.writeln('// Secrets: ${config.secrets.length}');

    if (platform == ConfidentialPlatform.web) {
      buffer.writeln(
        '// ⚠️  WARNING: Web platform detected - secrets are not secure in JavaScript',
      );
    }

    buffer.writeln('');

    // Add imports
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:confidential/confidential.dart';");
    buffer.writeln('');

    // Generate the main secrets class
    buffer.writeln('/// Generated secrets class with platform-aware handling.');
    buffer.writeln('class Secrets {');

    // Add platform detection
    buffer.writeln('  /// Current platform detection.');
    buffer.writeln(
      '  static ConfidentialPlatform get currentPlatform => PlatformDetector.detectPlatform();',
    );
    buffer.writeln('');
    buffer.writeln('  /// Whether secrets are secure on current platform.');
    buffer.writeln(
      '  static bool get areSecretsSecure => PlatformDetector.areSecretsSecure;',
    );
    buffer.writeln('');

    // Generate individual secrets
    for (final secret in config.secrets) {
      await _generateSecretProperty(buffer, secret, platform);
    }

    buffer.writeln('}');

    // Add platform-specific utilities
    await _generatePlatformUtilities(buffer, platform);

    return buffer.toString();
  }

  Future<void> _generateSecretProperty(
    StringBuffer buffer,
    SecretDefinition secret,
    ConfidentialPlatform platform,
  ) async {
    final obfuscation = config.createObfuscation();
    final nonce = DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
    final secretData = Uint8List.fromList(secret.value.toString().codeUnits);
    final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

    // Generate data arrays
    buffer.writeln(
      '  static const _${secret.name}Data = [${obfuscatedData.join(', ')}];',
    );
    buffer.writeln('  static const _${secret.name}Nonce = $nonce;');
    buffer.writeln('');

    // Generate getter with platform awareness
    buffer.writeln('  /// ${secret.name} secret with platform-aware handling.');
    if (platform == ConfidentialPlatform.web) {
      buffer.writeln('  /// ⚠️  WARNING: Not secure on web platform');
    }
    buffer.writeln('  static String get ${secret.name} {');

    if (platform == ConfidentialPlatform.web) {
      buffer.writeln('    if (PlatformDetector.shouldShowWarnings) {');
      buffer.writeln(
        '      print("⚠️  Accessing secret \'${secret.name}\' on web platform - not secure");',
      );
      buffer.writeln('    }');
    }

    buffer.writeln(
      '    // Deobfuscate the data using the same algorithm as build time',
    );
    buffer.writeln('    final obfuscation = ${_generateObfuscationCode()};');
    buffer.writeln(
      '    final deobfuscated = obfuscation.deobfuscate(Uint8List.fromList(_${secret.name}Data), _${secret.name}Nonce);',
    );
    buffer.writeln('    return String.fromCharCodes(deobfuscated);');
    buffer.writeln('  }');
    buffer.writeln('');

    // Generate web-aware version
    buffer.writeln('  /// ${secret.name} with web-aware handling.');
    buffer.writeln(
      '  static WebAwareObfuscatedValue<String> get ${secret.name}WebAware {',
    );
    buffer.writeln(
      '    final obfuscatedValue = ${secret.name}.obfuscate(algorithm: \'aes-256-gcm\');',
    );
    buffer.writeln(
      '    return obfuscatedValue.withWebWarnings(\'${secret.name}\');',
    );
    buffer.writeln('  }');
    buffer.writeln('');
  }

  Future<void> _generatePlatformUtilities(
    StringBuffer buffer,
    ConfidentialPlatform platform,
  ) async {
    buffer.writeln('/// Platform-specific utilities for secret management.');
    buffer.writeln('class SecretUtils {');
    buffer.writeln('  /// Shows platform security information.');
    buffer.writeln('  static void showPlatformInfo() {');
    buffer.writeln('    final platform = PlatformDetector.detectPlatform();');
    buffer.writeln(
      '    final securityInfo = PlatformDetector.getSecurityInfo(platform);',
    );
    buffer.writeln('    print("Platform: \${platform.name}");');
    buffer.writeln(
      '    print("Security Level: \${securityInfo.securityLevel.name}");',
    );
    buffer.writeln(
      '    print("Secure: \${PlatformDetector.areSecretsSecure}");',
    );
    buffer.writeln('  }');
    buffer.writeln('');
    buffer.writeln(
      '  /// Validates platform security before accessing secrets.',
    );
    buffer.writeln('  static bool validatePlatformSecurity() {');
    buffer.writeln('    return PlatformDetector.areSecretsSecure;');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  String _generateObfuscationCode() {
    // Generate the obfuscation instance creation code
    // For simplicity, use the same configuration as build time
    final algorithms = config.algorithm.map((a) => "'$a'").join(', ');
    return 'Obfuscation.create([$algorithms])';
  }
}

/// Creates a [ConfidentialBuilder] instance.
Builder confidentialBuilder(BuilderOptions options) {
  return ConfidentialBuilder(options);
}

/// Exception thrown when the build process fails.
class BuildException implements Exception {
  final String message;

  const BuildException(this.message);

  @override
  String toString() => 'BuildException: $message';
}
