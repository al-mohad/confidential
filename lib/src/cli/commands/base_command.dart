/// Base class for CLI commands.
library;

import 'dart:io';
import 'package:args/args.dart';

/// Base interface for CLI commands.
abstract class CliCommand {
  /// The name of the command.
  String get name;
  
  /// The description of the command.
  String get description;
  
  /// Creates the argument parser for this command.
  ArgParser createArgParser();
  
  /// Runs the command with the given arguments.
  Future<int> run(ArgResults results, {bool verbose = false});
  
  /// Prints help for this command.
  void printHelp(ArgParser parser) {
    print('Usage: dart run dart-confidential $name [options]');
    print('');
    print(description);
    print('');
    print('Options:');
    print(parser.usage);
  }
  
  /// Logs a message if verbose mode is enabled.
  void log(String message, {bool verbose = false}) {
    if (verbose) {
      print('[${DateTime.now().toIso8601String()}] $message');
    }
  }
  
  /// Logs an error message.
  void logError(String message) {
    stderr.writeln('Error: $message');
  }
  
  /// Logs a warning message.
  void logWarning(String message) {
    stderr.writeln('Warning: $message');
  }
  
  /// Logs a success message.
  void logSuccess(String message) {
    print('✅ $message');
  }
  
  /// Checks if a file exists and is readable.
  bool validateInputFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      logError('Input file does not exist: $path');
      return false;
    }
    
    try {
      file.readAsStringSync();
      return true;
    } catch (e) {
      logError('Cannot read input file: $path ($e)');
      return false;
    }
  }
  
  /// Ensures the output directory exists.
  Future<void> ensureOutputDirectory(String outputPath) async {
    final file = File(outputPath);
    final directory = file.parent;
    
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
  }
}
