import 'dart:convert';
import 'dart:io';

import 'package:confidential/src/cli/cli.dart';
import 'package:confidential/src/cli/commands/generate_assets_command.dart';
import 'package:confidential/src/cli/commands/generate_env_command.dart';
import 'package:confidential/src/cli/commands/init_command.dart';
import 'package:confidential/src/cli/commands/inject_secrets_command.dart';
import 'package:confidential/src/cli/commands/obfuscate_command.dart';
import 'package:confidential/src/cli/commands/validate_command.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('CLI and Build-Time Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('confidential_cli_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('ConfidentialCli', () {
      test('shows version information', () async {
        final result = await ConfidentialCli.run(['--version']);
        expect(result, equals(0));
      });

      test('shows help information', () async {
        final result = await ConfidentialCli.run(['--help']);
        expect(result, equals(0));
      });

      test('returns error for unknown command', () async {
        final result = await ConfidentialCli.run(['unknown-command']);
        expect(result, equals(1));
      });

      test('returns error when no command specified', () async {
        final result = await ConfidentialCli.run([]);
        expect(result, equals(1));
      });
    });

    group('InitCommand', () {
      test('initializes flutter project', () async {
        final configPath = path.join(tempDir.path, 'confidential.yaml');

        final command = InitCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--project-type',
          'flutter',
          '--config-file',
          configPath,
          '--force',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check if configuration file was created
        final configFile = File(configPath);
        expect(configFile.existsSync(), isTrue);

        final content = await configFile.readAsString();
        expect(content, contains('algorithm:'));
        expect(content, contains('secrets:'));
      });

      test('creates directory structure', () async {
        final configPath = path.join(tempDir.path, 'confidential.yaml');

        // Change to temp directory
        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final command = InitCommand();
          final parser = command.createArgParser();
          final results = parser.parse([
            '--project-type',
            'flutter',
            '--config-file',
            'confidential.yaml',
            '--with-build-runner',
            '--force',
          ]);

          final exitCode = await command.run(results, verbose: true);
          expect(exitCode, equals(0));

          // Check directories
          expect(Directory('lib/generated').existsSync(), isTrue);
          expect(Directory('assets/encrypted').existsSync(), isTrue);
          expect(Directory('scripts').existsSync(), isTrue);

          // Check files
          expect(File('build.yaml').existsSync(), isTrue);
          expect(File('.gitignore').existsSync(), isTrue);
        } finally {
          Directory.current = originalDir;
        }
      });
    });

    group('ObfuscateCommand', () {
      test('obfuscates secrets from configuration', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: testSecret
    value: test_value_123
    nonce: 12345
''';
        await File(configPath).writeAsString(configContent);

        final outputPath = path.join(tempDir.path, 'output.dart');

        final command = ObfuscateCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output',
          outputPath,
          '--force',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check output file
        final outputFile = File(outputPath);
        expect(outputFile.existsSync(), isTrue);

        final content = await outputFile.readAsString();
        expect(content, contains('class'));
        expect(content, contains('testSecret'));
      });

      test('generates different output formats', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: testSecret
    value: test_value_123
    nonce: 12345
''';
        await File(configPath).writeAsString(configContent);

        // Test JSON format
        final jsonOutputPath = path.join(tempDir.path, 'output.json');
        final command = ObfuscateCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output',
          jsonOutputPath,
          '--format',
          'json',
          '--force',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        final jsonFile = File(jsonOutputPath);
        expect(jsonFile.existsSync(), isTrue);

        final jsonContent = await jsonFile.readAsString();
        final parsed = jsonDecode(jsonContent);
        expect(parsed, isA<Map<String, dynamic>>());
        expect(parsed['testSecret'], isNotNull);
      });
    });

    group('GenerateAssetsCommand', () {
      test('generates encrypted asset files', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: secret1
    value: value1
    nonce: 12345
  - name: secret2
    value: value2
    nonce: 67890
''';
        await File(configPath).writeAsString(configContent);

        final outputDir = path.join(tempDir.path, 'assets');

        final command = GenerateAssetsCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output-dir',
          outputDir,
          '--format',
          'binary',
          '--split',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check asset files
        expect(
          File(path.join(outputDir, 'secret_secret1.bin')).existsSync(),
          isTrue,
        );
        expect(
          File(path.join(outputDir, 'secret_secret2.bin')).existsSync(),
          isTrue,
        );
      });

      test('generates combined asset file', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: secret1
    value: value1
    nonce: 12345
''';
        await File(configPath).writeAsString(configContent);

        final outputDir = path.join(tempDir.path, 'assets');

        final command = GenerateAssetsCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output-dir',
          outputDir,
          '--format',
          'json',
          '--no-split',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check combined asset file
        expect(
          File(path.join(outputDir, 'secret_combined.json')).existsSync(),
          isTrue,
        );
      });
    });

    group('GenerateEnvCommand', () {
      test('generates dotenv file', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: apiKey
    value: sk_test_123
  - name: dbPassword
    value: secret_password
''';
        await File(configPath).writeAsString(configContent);

        final outputPath = path.join(tempDir.path, '.env.test');

        final command = GenerateEnvCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output',
          outputPath,
          '--format',
          'dotenv',
          '--environment',
          'development',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check environment file
        final envFile = File(outputPath);
        expect(envFile.existsSync(), isTrue);

        final content = await envFile.readAsString();
        expect(content, contains('CONFIDENTIAL_APIKEY='));
        expect(content, contains('CONFIDENTIAL_DBPASSWORD='));
      });

      test('generates JSON environment file', () async {
        // Create test configuration
        final configPath = path.join(tempDir.path, 'test_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: apiKey
    value: sk_test_123
''';
        await File(configPath).writeAsString(configContent);

        final outputPath = path.join(tempDir.path, 'env.json');

        final command = GenerateEnvCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--output',
          outputPath,
          '--format',
          'json',
          '--include-metadata',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));

        // Check JSON environment file
        final envFile = File(outputPath);
        expect(envFile.existsSync(), isTrue);

        final content = await envFile.readAsString();
        final parsed = jsonDecode(content);
        expect(parsed, isA<Map<String, dynamic>>());
        expect(parsed['apiKey'], isNotNull);
        expect(parsed['_metadata'], isNotNull);
      });
    });

    group('ValidateCommand', () {
      test('validates correct configuration', () async {
        // Create valid configuration
        final configPath = path.join(tempDir.path, 'valid_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: validSecret
    value: valid_secret_value_123
    nonce: 12345
''';
        await File(configPath).writeAsString(configContent);

        final command = ValidateCommand();
        final parser = command.createArgParser();
        final results = parser.parse(['--config', configPath]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(0));
      });

      test('detects duplicate secret names', () async {
        // Create configuration with duplicates
        final configPath = path.join(tempDir.path, 'duplicate_config.yaml');
        final configContent = '''
algorithm:
  - encrypt using aes-256-gcm
  - shuffle

secrets:
  - name: duplicateSecret
    value: value1
    nonce: 12345
  - name: duplicateSecret
    value: value2
    nonce: 67890
''';
        await File(configPath).writeAsString(configContent);

        final command = ValidateCommand();
        final parser = command.createArgParser();
        final results = parser.parse(['--config', configPath]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(1)); // Should fail validation
      });

      test('validates algorithms', () async {
        // Create configuration with invalid algorithm
        final configPath = path.join(
          tempDir.path,
          'invalid_algorithm_config.yaml',
        );
        final configContent = '''
algorithm:
  - invalid-algorithm

secrets:
  - name: testSecret
    value: test_value
    algorithm: invalid-algorithm
    nonce: 12345
''';
        await File(configPath).writeAsString(configContent);

        final command = ValidateCommand();
        final parser = command.createArgParser();
        final results = parser.parse([
          '--config',
          configPath,
          '--check-algorithms',
        ]);

        final exitCode = await command.run(results, verbose: true);
        expect(exitCode, equals(1)); // Should fail validation
      });
    });

    group('Command Help', () {
      test('all commands provide help', () async {
        final commands = [
          InitCommand(),
          ObfuscateCommand(),
          GenerateAssetsCommand(),
          GenerateEnvCommand(),
          InjectSecretsCommand(),
          ValidateCommand(),
        ];

        for (final command in commands) {
          final parser = command.createArgParser();
          final results = parser.parse(['--help']);

          final exitCode = await command.run(results, verbose: false);
          expect(exitCode, equals(0));
        }
      });
    });
  });
}
