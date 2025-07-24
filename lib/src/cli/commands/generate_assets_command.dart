/// Command for generating encrypted asset files.
library;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import '../../configuration/configuration.dart';
import '../../obfuscation/obfuscation.dart';
import 'base_command.dart';

/// Command for generating encrypted asset files from secrets.
class GenerateAssetsCommand extends CliCommand {
  @override
  String get name => 'generate-assets';

  @override
  String get description => 'Generate encrypted asset files from configuration';

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
        'output-dir',
        abbr: 'o',
        help: 'Output directory for asset files',
        defaultsTo: 'assets/encrypted',
      )
      ..addOption(
        'format',
        help: 'Asset format (binary, json, base64)',
        allowed: ['binary', 'json', 'base64'],
        defaultsTo: 'binary',
      )
      ..addOption(
        'prefix',
        help: 'Prefix for generated asset files',
        defaultsTo: 'secret_',
      )
      ..addFlag(
        'split',
        help: 'Generate separate files for each secret',
        defaultsTo: true,
      )
      ..addFlag(
        'compress',
        help: 'Compress asset files',
        negatable: false,
      )
      ..addOption(
        'manifest',
        help: 'Generate asset manifest file',
        defaultsTo: 'assets_manifest.json',
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
    final outputDir = results['output-dir'] as String;
    final format = results['format'] as String;
    final prefix = results['prefix'] as String;
    final split = results['split'] as bool;
    final compress = results['compress'] as bool;
    final manifestPath = results['manifest'] as String?;

    // Validate input file
    if (!validateInputFile(configPath)) {
      return 1;
    }

    try {
      log('Loading configuration from: $configPath', verbose: verbose);
      
      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);
      log('Loaded ${config.secrets.length} secrets', verbose: verbose);

      // Create output directory
      final outputDirectory = Directory(outputDir);
      if (!outputDirectory.existsSync()) {
        await outputDirectory.create(recursive: true);
        log('Created output directory: $outputDir', verbose: verbose);
      }

      // Create obfuscation instance
      final obfuscation = config.createObfuscation();

      if (split) {
        await _generateSeparateAssets(
          config,
          obfuscation,
          outputDir,
          format,
          prefix,
          compress,
          verbose,
        );
      } else {
        await _generateCombinedAsset(
          config,
          obfuscation,
          outputDir,
          format,
          prefix,
          compress,
          verbose,
        );
      }

      // Generate manifest if requested
      if (manifestPath != null) {
        await _generateManifest(
          config,
          outputDir,
          format,
          prefix,
          split,
          manifestPath,
          verbose,
        );
      }

      logSuccess('Successfully generated encrypted assets in: $outputDir');
      return 0;
    } catch (e) {
      logError('Failed to generate assets: $e');
      return 1;
    }
  }

  Future<void> _generateSeparateAssets(
    ConfidentialConfiguration config,
    Obfuscation obfuscation,
    String outputDir,
    String format,
    String prefix,
    bool compress,
    bool verbose,
  ) async {
    log('Generating separate asset files...', verbose: verbose);

    for (final secret in config.secrets) {
      final nonce = DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
      final secretData = _serializeSecret(secret.value);
      final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

      final fileName = '$prefix${secret.name}.${_getFileExtension(format)}';
      final filePath = path.join(outputDir, fileName);

      await _writeAssetFile(
        filePath,
        obfuscatedData,
        format,
        compress,
        {
          'name': secret.name,
          'type': secret.dartType,
          'namespace': secret.namespace,
          'nonce': nonce,
        },
        verbose,
      );

      log('Generated asset: $fileName', verbose: verbose);
    }
  }

  Future<void> _generateCombinedAsset(
    ConfidentialConfiguration config,
    Obfuscation obfuscation,
    String outputDir,
    String format,
    String prefix,
    bool compress,
    bool verbose,
  ) async {
    log('Generating combined asset file...', verbose: verbose);

    final combinedData = <String, dynamic>{};
    
    for (final secret in config.secrets) {
      final nonce = DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
      final secretData = _serializeSecret(secret.value);
      final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

      combinedData[secret.name] = {
        'data': obfuscatedData.toList(),
        'type': secret.dartType,
        'namespace': secret.namespace,
        'nonce': nonce,
      };
    }

    final fileName = '${prefix}combined.${_getFileExtension(format)}';
    final filePath = path.join(outputDir, fileName);

    final serializedData = Uint8List.fromList(
      utf8.encode(jsonEncode(combinedData)),
    );

    await _writeAssetFile(
      filePath,
      serializedData,
      format,
      compress,
      {
        'type': 'combined',
        'secrets': config.secrets.length,
      },
      verbose,
    );

    log('Generated combined asset: $fileName', verbose: verbose);
  }

  Future<void> _writeAssetFile(
    String filePath,
    Uint8List data,
    String format,
    bool compress,
    Map<String, dynamic> metadata,
    bool verbose,
  ) async {
    var finalData = data;

    // Apply compression if requested
    if (compress) {
      finalData = await _compressData(finalData);
      log('Compressed ${data.length} bytes to ${finalData.length} bytes', verbose: verbose);
    }

    final file = File(filePath);

    switch (format) {
      case 'binary':
        await file.writeAsBytes(finalData);
        break;
      case 'json':
        final jsonData = {
          'data': finalData.toList(),
          'metadata': metadata,
        };
        await file.writeAsString(jsonEncode(jsonData));
        break;
      case 'base64':
        final base64Data = base64Encode(finalData);
        final output = {
          'data': base64Data,
          'metadata': metadata,
        };
        await file.writeAsString(jsonEncode(output));
        break;
    }
  }

  Future<void> _generateManifest(
    ConfidentialConfiguration config,
    String outputDir,
    String format,
    String prefix,
    bool split,
    String manifestPath,
    bool verbose,
  ) async {
    log('Generating asset manifest...', verbose: verbose);

    final manifest = <String, dynamic>{
      'version': '1.0',
      'generated': DateTime.now().toIso8601String(),
      'format': format,
      'split': split,
      'assets': <Map<String, dynamic>>[],
    };

    if (split) {
      for (final secret in config.secrets) {
        final fileName = '$prefix${secret.name}.${_getFileExtension(format)}';
        manifest['assets'].add({
          'name': secret.name,
          'file': fileName,
          'type': secret.dartType,
          'namespace': secret.namespace,
        });
      }
    } else {
      final fileName = '${prefix}combined.${_getFileExtension(format)}';
      manifest['assets'].add({
        'name': 'combined',
        'file': fileName,
        'type': 'combined',
        'secrets': config.secrets.map((s) => s.name).toList(),
      });
    }

    final manifestFile = File(path.join(outputDir, manifestPath));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    log('Generated manifest: $manifestPath', verbose: verbose);
  }

  Uint8List _serializeSecret(dynamic value) {
    final json = jsonEncode(value);
    return Uint8List.fromList(utf8.encode(json));
  }

  String _getFileExtension(String format) {
    switch (format) {
      case 'binary':
        return 'bin';
      case 'json':
        return 'json';
      case 'base64':
        return 'b64';
      default:
        return 'dat';
    }
  }

  Future<Uint8List> _compressData(Uint8List data) async {
    // Simple compression using gzip
    // In a real implementation, you might want to use different compression algorithms
    try {
      final compressed = gzip.encode(data);
      return Uint8List.fromList(compressed);
    } catch (e) {
      // If compression fails, return original data
      return data;
    }
  }
}
