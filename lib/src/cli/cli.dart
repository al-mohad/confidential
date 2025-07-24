/// Command-line interface for the confidential tool.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'commands/base_command.dart';
import 'commands/generate_assets_command.dart';
import 'commands/generate_env_command.dart';
import 'commands/init_command.dart';
import 'commands/inject_secrets_command.dart';
import 'commands/obfuscate_command.dart';
import 'commands/validate_command.dart';

/// Command-line interface for dart-confidential.
class ConfidentialCli {
  static const String version = '1.0.0';

  /// Available commands.
  static final Map<String, CliCommand> _commands = {
    'init': InitCommand(),
    'obfuscate': ObfuscateCommand(),
    'generate-assets': GenerateAssetsCommand(),
    'generate-env': GenerateEnvCommand(),
    'inject-secrets': InjectSecretsCommand(),
    'validate': ValidateCommand(),
  };

  /// Runs the CLI with the given arguments.
  static Future<int> run(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show usage information',
        negatable: false,
      )
      ..addFlag(
        'version',
        abbr: 'v',
        help: 'Show version information',
        negatable: false,
      )
      ..addFlag('verbose', help: 'Enable verbose output', negatable: false);

    // Add commands
    for (final entry in _commands.entries) {
      parser.addCommand(entry.key, entry.value.createArgParser());
    }

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

      final command = results.command;
      if (command == null) {
        stderr.writeln('Error: No command specified');
        _printUsage(parser);
        return 1;
      }

      final cliCommand = _commands[command.name];
      if (cliCommand == null) {
        stderr.writeln('Error: Unknown command: ${command.name}');
        return 1;
      }

      final verbose = results['verbose'] as bool;
      return await cliCommand.run(command, verbose: verbose);
    } catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }

  static void _printUsage(ArgParser parser) {
    print('Dart Confidential CLI - Build-time secret management');
    print('');
    print('Usage: dart run dart-confidential <command> [options]');
    print('');
    print('Global options:');
    print(parser.usage);
    print('');
    print('Available commands:');

    for (final entry in _commands.entries) {
      print('  ${entry.key.padRight(20)} ${entry.value.description}');
    }

    print('');
    print('Examples:');
    print('  dart run dart-confidential init --project-type flutter');
    print('  dart run dart-confidential obfuscate --config confidential.yaml');
    print(
      '  dart run dart-confidential generate-assets --output-dir assets/encrypted',
    );
    print('  dart run dart-confidential generate-env --format dotenv');
    print('  dart run dart-confidential inject-secrets --target flutter');
    print('  dart run dart-confidential validate --strict');
    print('');
    print('For help on a specific command:');
    print('  dart run dart-confidential <command> --help');
  }
}
