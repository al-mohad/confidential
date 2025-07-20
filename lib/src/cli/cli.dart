/// Command-line interface for the confidential tool.
library;

import 'dart:io';

import 'package:args/args.dart';

import '../code_generation/generator.dart';
import '../configuration/configuration.dart';

class ConfidentialCli {
  static const String version = '0.4.1';

  /// Runs the CLI with the given arguments.
  static Future<int> run(List<String> arguments) async {
    final parser = _createArgParser();

    try {
      final results = parser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage(parser);
        return 0;
      }

      if (results['version'] as bool) {
        print('dart-confidential version $version');
        return 0;
      }

      final command = results.rest.isNotEmpty ? results.rest.first : null;

      switch (command) {
        case 'obfuscate':
          return await _runObfuscate(results);
        case null:
          stderr.writeln('Error: No command specified');
          _printUsage(parser);
          return 1;
        default:
          stderr.writeln('Error: Unknown command: $command');
          _printUsage(parser);
          return 1;
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }

  static ArgParser _createArgParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false,
      )
      ..addFlag(
        'version',
        abbr: 'v',
        help: 'Show version information',
        negatable: false,
      )
      ..addOption(
        'configuration',
        abbr: 'c',
        help: 'Path to the configuration file',
        valueHelp: 'FILE',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file path',
        valueHelp: 'FILE',
      );
  }

  static void _printUsage(ArgParser parser) {
    print(
      'Dart literals obfuscator to defend against static reverse engineering.',
    );
    print('');
    print('Usage: dart-confidential <command> [options]');
    print('');
    print('Commands:');
    print('  obfuscate    Obfuscate literals based on configuration');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print(
      '  dart-confidential obfuscate -c confidential.yaml -o lib/generated/confidential.dart',
    );
    print(
      '  dart-confidential obfuscate --configuration config.yaml --output output.dart',
    );
  }

  static Future<int> _runObfuscate(ArgResults results) async {
    final configPath = results['configuration'] as String?;
    final outputPath = results['output'] as String?;

    if (configPath == null) {
      stderr.writeln(
        'Error: Configuration file is required (use -c or --configuration)',
      );
      return 1;
    }

    if (outputPath == null) {
      stderr.writeln('Error: Output file is required (use -o or --output)');
      return 1;
    }

    try {
      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);

      // Generate code
      final generator = CodeGenerator(config);
      final generatedCode = generator.generate();

      // Write output
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(generatedCode);

      print('Successfully generated obfuscated code: $outputPath');
      return 0;
    } catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }
}

/// Entry point for the CLI tool.
Future<int> main(List<String> arguments) async {
  return await ConfidentialCli.run(arguments);
}
