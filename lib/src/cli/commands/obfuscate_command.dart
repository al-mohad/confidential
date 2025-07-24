/// Command for obfuscating secrets from configuration.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';

import '../../code_generation/generator.dart';
import '../../configuration/configuration.dart';
import 'base_command.dart';

/// Command for obfuscating secrets based on configuration.
class ObfuscateCommand extends CliCommand {
  @override
  String get name => 'obfuscate';

  @override
  String get description => 'Obfuscate secrets based on configuration file';

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
        help: 'Output file path',
        defaultsTo: 'lib/generated/confidential.dart',
      )
      ..addFlag(
        'watch',
        abbr: 'w',
        help: 'Watch for configuration file changes',
        negatable: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing output file',
        negatable: false,
      )
      ..addOption(
        'format',
        help: 'Output format (dart, json, yaml)',
        allowed: ['dart', 'json', 'yaml'],
        defaultsTo: 'dart',
      )
      ..addFlag('minify', help: 'Minify the generated code', negatable: false)
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
    final watch = results['watch'] as bool;
    final force = results['force'] as bool;
    final format = results['format'] as String;
    final minify = results['minify'] as bool;

    // Validate input file
    if (!validateInputFile(configPath)) {
      return 1;
    }

    // Check if output file exists and force flag
    final outputFile = File(outputPath);
    if (outputFile.existsSync() && !force) {
      logError(
        'Output file already exists: $outputPath (use --force to overwrite)',
      );
      return 1;
    }

    if (watch) {
      return await _runWatchMode(
        configPath,
        outputPath,
        format,
        minify,
        verbose,
      );
    } else {
      return await _runSingleGeneration(
        configPath,
        outputPath,
        format,
        minify,
        verbose,
      );
    }
  }

  Future<int> _runSingleGeneration(
    String configPath,
    String outputPath,
    String format,
    bool minify,
    bool verbose,
  ) async {
    try {
      log('Loading configuration from: $configPath', verbose: verbose);

      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);
      log('Loaded ${config.secrets.length} secrets', verbose: verbose);

      // Generate output based on format
      String generatedContent;
      switch (format) {
        case 'dart':
          generatedContent = await _generateDartCode(config, minify, verbose);
          break;
        case 'json':
          generatedContent = await _generateJsonOutput(config, verbose);
          break;
        case 'yaml':
          generatedContent = await _generateYamlOutput(config, verbose);
          break;
        default:
          logError('Unsupported format: $format');
          return 1;
      }

      // Ensure output directory exists
      await ensureOutputDirectory(outputPath);

      // Write output
      log('Writing output to: $outputPath', verbose: verbose);
      await File(outputPath).writeAsString(generatedContent);

      logSuccess('Successfully generated obfuscated code: $outputPath');

      if (verbose) {
        final stats = await File(outputPath).stat();
        log('Output file size: ${stats.size} bytes', verbose: true);
      }

      return 0;
    } catch (e) {
      logError('Failed to generate obfuscated code: $e');
      return 1;
    }
  }

  Future<int> _runWatchMode(
    String configPath,
    String outputPath,
    String format,
    bool minify,
    bool verbose,
  ) async {
    log('Starting watch mode for: $configPath', verbose: verbose);

    final configFile = File(configPath);
    DateTime? lastModified;

    // Initial generation
    await _runSingleGeneration(configPath, outputPath, format, minify, verbose);

    // Watch for changes
    while (true) {
      await Future.delayed(const Duration(seconds: 1));

      if (!configFile.existsSync()) {
        logWarning('Configuration file no longer exists: $configPath');
        continue;
      }

      final stat = await configFile.stat();
      if (lastModified == null || stat.modified.isAfter(lastModified)) {
        lastModified = stat.modified;

        if (lastModified != stat.modified) {
          log('Configuration file changed, regenerating...', verbose: verbose);
          await _runSingleGeneration(
            configPath,
            outputPath,
            format,
            minify,
            verbose,
          );
        }
      }
    }
  }

  Future<String> _generateDartCode(
    ConfidentialConfiguration config,
    bool minify,
    bool verbose,
  ) async {
    log('Generating Dart code...', verbose: verbose);

    final generator = CodeGenerator(config);
    var code = generator.generate();

    if (minify) {
      log('Minifying generated code...', verbose: verbose);
      code = _minifyDartCode(code);
    }

    return code;
  }

  Future<String> _generateJsonOutput(
    ConfidentialConfiguration config,
    bool verbose,
  ) async {
    log('Generating JSON output...', verbose: verbose);

    final obfuscation = config.createObfuscation();
    final result = <String, dynamic>{};

    for (final secret in config.secrets) {
      final obfuscatedData = obfuscation.obfuscate(
        Uint8List.fromList(secret.value.toString().codeUnits),
        DateTime.now().millisecondsSinceEpoch,
      );

      result[secret.name] = {
        'data': obfuscatedData.toList(),
        'type': secret.dartType,
        'namespace': secret.namespace,
      };
    }

    return const JsonEncoder.withIndent('  ').convert(result);
  }

  Future<String> _generateYamlOutput(
    ConfidentialConfiguration config,
    bool verbose,
  ) async {
    log('Generating YAML output...', verbose: verbose);

    // For now, return the original configuration as YAML
    // In a real implementation, you might want to use a YAML encoder
    return '''
# Generated obfuscated configuration
algorithm: ${config.algorithm}
defaultNamespace: "${config.defaultNamespace}"
defaultAccessModifier: "${config.defaultAccessModifier}"

secrets:
${config.secrets.map((s) => '  - name: ${s.name}\n    type: ${s.dartType}\n    namespace: ${s.namespace}').join('\n')}
''';
  }

  String _minifyDartCode(String code) {
    // Simple minification - remove extra whitespace and comments
    return code
        .split('\n')
        .where(
          (line) => line.trim().isNotEmpty && !line.trim().startsWith('//'),
        )
        .map((line) => line.trim())
        .join('\n');
  }
}
