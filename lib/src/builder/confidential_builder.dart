/// Build system integration for dart-confidential.
library;

import 'dart:async';

import 'package:build/build.dart';

import '../code_generation/generator.dart';
import '../configuration/configuration.dart';

/// Builder for generating obfuscated code from confidential.yaml files.
class ConfidentialBuilder implements Builder {
  const ConfidentialBuilder();

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

      // Generate code
      final generator = CodeGenerator(config);
      final generatedCode = generator.generate();

      // Write output - use the same directory as the input file
      final inputPath = inputId.path;
      final inputDir = inputPath.contains('/')
          ? inputPath.substring(0, inputPath.lastIndexOf('/'))
          : '';
      final outputPath = inputDir.isEmpty
          ? 'lib/generated/confidential.dart'
          : '$inputDir/lib/generated/confidential.dart';

      final outputId = AssetId(inputId.package, outputPath);

      await buildStep.writeAsString(outputId, generatedCode);

      log.info('Generated obfuscated code: ${outputId.path}');
    } catch (e) {
      log.severe('Failed to generate obfuscated code: $e');
      throw BuildException('Confidential code generation failed: $e');
    }
  }
}

/// Creates a [ConfidentialBuilder] instance.
Builder confidentialBuilder(BuilderOptions options) {
  return const ConfidentialBuilder();
}

/// Exception thrown when the build process fails.
class BuildException implements Exception {
  final String message;

  const BuildException(this.message);

  @override
  String toString() => 'BuildException: $message';
}
