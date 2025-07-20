#!/usr/bin/env dart

/// Command-line tool for obfuscating Dart literals.
library;

import 'dart:io';
import 'package:confidential/src/cli/cli.dart';

Future<void> main(List<String> arguments) async {
  final exitCode = await ConfidentialCli.run(arguments);
  exit(exitCode);
}
