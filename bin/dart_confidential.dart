#!/usr/bin/env dart

/// Command-line interface for dart-confidential.
///
/// This executable provides build-time secret management capabilities
/// including code generation, asset creation, and build integration.
library;

import 'dart:io';

import 'package:confidential/src/cli/cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    final exitCode = await ConfidentialCli.run(arguments);
    exit(exitCode);
  } catch (e) {
    stderr.writeln('Fatal error: $e');
    exit(1);
  }
}
