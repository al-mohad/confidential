/// Command for injecting secrets into applications at compile time.
library;

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import '../../configuration/configuration.dart';
import 'base_command.dart';

/// Command for injecting secrets into applications at compile time.
class InjectSecretsCommand extends CliCommand {
  @override
  String get name => 'inject-secrets';

  @override
  String get description => 'Inject secrets into applications at compile time';

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
        'target',
        abbr: 't',
        help: 'Target application type (flutter, dart, web)',
        allowed: ['flutter', 'dart', 'web'],
        defaultsTo: 'flutter',
      )
      ..addOption(
        'build-dir',
        abbr: 'b',
        help: 'Build directory path',
        defaultsTo: 'build',
      )
      ..addOption(
        'assets-dir',
        help: 'Assets directory for injection',
        defaultsTo: 'assets',
      )
      ..addOption(
        'injection-method',
        help: 'Method for injecting secrets (compile-time, runtime, hybrid)',
        allowed: ['compile-time', 'runtime', 'hybrid'],
        defaultsTo: 'compile-time',
      )
      ..addFlag(
        'minify',
        help: 'Minify injected code',
        negatable: false,
      )
      ..addFlag(
        'obfuscate-names',
        help: 'Obfuscate variable and function names',
        negatable: false,
      )
      ..addOption(
        'platform',
        help: 'Target platform (android, ios, web, desktop)',
        allowed: ['android', 'ios', 'web', 'desktop', 'all'],
        defaultsTo: 'all',
      )
      ..addFlag(
        'debug',
        help: 'Include debug information',
        negatable: false,
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
    final target = results['target'] as String;
    final buildDir = results['build-dir'] as String;
    final assetsDir = results['assets-dir'] as String;
    final injectionMethod = results['injection-method'] as String;
    final minify = results['minify'] as bool;
    final obfuscateNames = results['obfuscate-names'] as bool;
    final platform = results['platform'] as String;
    final debug = results['debug'] as bool;

    // Validate input file
    if (!validateInputFile(configPath)) {
      return 1;
    }

    try {
      log('Loading configuration from: $configPath', verbose: verbose);
      
      // Load configuration
      final config = ConfidentialConfiguration.fromFile(configPath);
      log('Loaded ${config.secrets.length} secrets', verbose: verbose);

      // Validate build directory
      final buildDirectory = Directory(buildDir);
      if (!buildDirectory.existsSync()) {
        logError('Build directory does not exist: $buildDir');
        return 1;
      }

      // Perform injection based on target and method
      await _performInjection(
        config,
        target,
        buildDir,
        assetsDir,
        injectionMethod,
        platform,
        minify,
        obfuscateNames,
        debug,
        verbose,
      );

      logSuccess('Successfully injected secrets into $target application');
      return 0;
    } catch (e) {
      logError('Failed to inject secrets: $e');
      return 1;
    }
  }

  Future<void> _performInjection(
    ConfidentialConfiguration config,
    String target,
    String buildDir,
    String assetsDir,
    String injectionMethod,
    String platform,
    bool minify,
    bool obfuscateNames,
    bool debug,
    bool verbose,
  ) async {
    log('Performing $injectionMethod injection for $target...', verbose: verbose);

    switch (injectionMethod) {
      case 'compile-time':
        await _performCompileTimeInjection(
          config,
          target,
          buildDir,
          platform,
          minify,
          obfuscateNames,
          debug,
          verbose,
        );
        break;
      case 'runtime':
        await _performRuntimeInjection(
          config,
          target,
          buildDir,
          assetsDir,
          platform,
          debug,
          verbose,
        );
        break;
      case 'hybrid':
        await _performHybridInjection(
          config,
          target,
          buildDir,
          assetsDir,
          platform,
          minify,
          obfuscateNames,
          debug,
          verbose,
        );
        break;
    }
  }

  Future<void> _performCompileTimeInjection(
    ConfidentialConfiguration config,
    String target,
    String buildDir,
    String platform,
    bool minify,
    bool obfuscateNames,
    bool debug,
    bool verbose,
  ) async {
    log('Performing compile-time injection...', verbose: verbose);

    // Generate obfuscated code
    final obfuscation = config.createObfuscation();
    final injectedCode = _generateInjectedCode(
      config,
      obfuscation,
      obfuscateNames,
      debug,
      verbose,
    );

    // Find and modify target files based on platform
    final targetFiles = await _findTargetFiles(buildDir, target, platform);
    
    for (final file in targetFiles) {
      await _injectCodeIntoFile(file, injectedCode, minify, verbose);
    }

    log('Injected code into ${targetFiles.length} files', verbose: verbose);
  }

  Future<void> _performRuntimeInjection(
    ConfidentialConfiguration config,
    String target,
    String buildDir,
    String assetsDir,
    String platform,
    bool debug,
    bool verbose,
  ) async {
    log('Performing runtime injection...', verbose: verbose);

    // Create encrypted asset files
    final obfuscation = config.createObfuscation();
    final assetData = <String, dynamic>{};

    for (final secret in config.secrets) {
      final nonce = DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
      final secretData = utf8.encode(jsonEncode(secret.value));
      final obfuscatedData = obfuscation.obfuscate(secretData, nonce);

      assetData[secret.name] = {
        'data': base64Encode(obfuscatedData),
        'nonce': nonce,
        'type': secret.dartType,
      };
    }

    // Write asset file
    final assetFile = File(path.join(buildDir, assetsDir, 'secrets.json'));
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsString(jsonEncode(assetData));

    // Generate runtime loader code
    final loaderCode = _generateRuntimeLoader(debug);
    final loaderFile = File(path.join(buildDir, 'lib', 'generated', 'secret_loader.dart'));
    await loaderFile.parent.create(recursive: true);
    await loaderFile.writeAsString(loaderCode);

    log('Created runtime assets and loader', verbose: verbose);
  }

  Future<void> _performHybridInjection(
    ConfidentialConfiguration config,
    String target,
    String buildDir,
    String assetsDir,
    String platform,
    bool minify,
    bool obfuscateNames,
    bool debug,
    bool verbose,
  ) async {
    log('Performing hybrid injection...', verbose: verbose);

    // Split secrets into compile-time and runtime based on sensitivity
    final compileTimeSecrets = <SecretDefinition>[];
    final runtimeSecrets = <SecretDefinition>[];

    for (final secret in config.secrets) {
      if (_isHighSensitivity(secret)) {
        runtimeSecrets.add(secret);
      } else {
        compileTimeSecrets.add(secret);
      }
    }

    log('Compile-time secrets: ${compileTimeSecrets.length}, Runtime secrets: ${runtimeSecrets.length}', verbose: verbose);

    // Perform compile-time injection for less sensitive secrets
    if (compileTimeSecrets.isNotEmpty) {
      final compileTimeConfig = ConfidentialConfiguration(
        algorithm: config.algorithm,
        secrets: compileTimeSecrets,
        defaultAccessModifier: config.defaultAccessModifier,
        defaultNamespace: config.defaultNamespace,
      );

      await _performCompileTimeInjection(
        compileTimeConfig,
        target,
        buildDir,
        platform,
        minify,
        obfuscateNames,
        debug,
        verbose,
      );
    }

    // Perform runtime injection for highly sensitive secrets
    if (runtimeSecrets.isNotEmpty) {
      final runtimeConfig = ConfidentialConfiguration(
        algorithm: config.algorithm,
        secrets: runtimeSecrets,
        defaultAccessModifier: config.defaultAccessModifier,
        defaultNamespace: config.defaultNamespace,
      );

      await _performRuntimeInjection(
        runtimeConfig,
        target,
        buildDir,
        assetsDir,
        platform,
        debug,
        verbose,
      );
    }
  }

  String _generateInjectedCode(
    ConfidentialConfiguration config,
    dynamic obfuscation,
    bool obfuscateNames,
    bool debug,
    bool verbose,
  ) {
    final buffer = StringBuffer();

    if (debug) {
      buffer.writeln('// Generated by dart-confidential inject-secrets');
      buffer.writeln('// Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('// Secrets: ${config.secrets.length}');
      buffer.writeln('');
    }

    // Generate obfuscated secret data
    for (final secret in config.secrets) {
      final varName = obfuscateNames ? _obfuscateName(secret.name) : secret.name;
      final nonce = DateTime.now().millisecondsSinceEpoch + secret.name.hashCode;
      
      buffer.writeln('const _${varName}_data = [${_generateDataArray(secret, obfuscation, nonce)}];');
      buffer.writeln('const _${varName}_nonce = $nonce;');
    }

    buffer.writeln('');
    buffer.writeln('// Deobfuscation function');
    buffer.writeln(_generateDeobfuscationFunction(debug));

    return buffer.toString();
  }

  String _generateRuntimeLoader(bool debug) {
    return '''
// Generated runtime secret loader
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class SecretLoader {
  static Map<String, dynamic>? _secrets;
  
  static Future<void> initialize() async {
    if (_secrets != null) return;
    
    try {
      final data = await rootBundle.loadString('assets/secrets.json');
      _secrets = jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      ${debug ? 'print("Failed to load secrets: \$e");' : ''}
      _secrets = {};
    }
  }
  
  static T? getSecret<T>(String name) {
    if (_secrets == null) return null;
    
    final secretData = _secrets![name] as Map<String, dynamic>?;
    if (secretData == null) return null;
    
    try {
      final data = base64Decode(secretData['data'] as String);
      final nonce = secretData['nonce'] as int;
      
      // Deobfuscate data here
      final deobfuscated = _deobfuscate(data, nonce);
      final json = utf8.decode(deobfuscated);
      return jsonDecode(json) as T;
    } catch (e) {
      ${debug ? 'print("Failed to deobfuscate secret \$name: \$e");' : ''}
      return null;
    }
  }
  
  static Uint8List _deobfuscate(Uint8List data, int nonce) {
    // Implement deobfuscation logic here
    return data;
  }
}
''';
  }

  Future<List<File>> _findTargetFiles(String buildDir, String target, String platform) async {
    final files = <File>[];
    
    switch (target) {
      case 'flutter':
        await _findFlutterTargetFiles(buildDir, platform, files);
        break;
      case 'dart':
        await _findDartTargetFiles(buildDir, files);
        break;
      case 'web':
        await _findWebTargetFiles(buildDir, files);
        break;
    }
    
    return files;
  }

  Future<void> _findFlutterTargetFiles(String buildDir, String platform, List<File> files) async {
    // Find Flutter-specific files based on platform
    if (platform == 'android' || platform == 'all') {
      final androidDir = Directory(path.join(buildDir, 'app', 'intermediates'));
      if (androidDir.existsSync()) {
        await for (final entity in androidDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dex')) {
            files.add(entity);
          }
        }
      }
    }
    
    if (platform == 'ios' || platform == 'all') {
      final iosDir = Directory(path.join(buildDir, 'ios'));
      if (iosDir.existsSync()) {
        await for (final entity in iosDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.app')) {
            files.add(entity);
          }
        }
      }
    }
    
    if (platform == 'web' || platform == 'all') {
      final webDir = Directory(path.join(buildDir, 'web'));
      if (webDir.existsSync()) {
        await for (final entity in webDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.js')) {
            files.add(entity);
          }
        }
      }
    }
  }

  Future<void> _findDartTargetFiles(String buildDir, List<File> files) async {
    final dartDir = Directory(buildDir);
    await for (final entity in dartDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  Future<void> _findWebTargetFiles(String buildDir, List<File> files) async {
    final webDir = Directory(buildDir);
    await for (final entity in webDir.list(recursive: true)) {
      if (entity is File && (entity.path.endsWith('.js') || entity.path.endsWith('.html'))) {
        files.add(entity);
      }
    }
  }

  Future<void> _injectCodeIntoFile(File file, String code, bool minify, bool verbose) async {
    // This is a simplified injection - in practice, you'd need more sophisticated
    // code injection based on the file type and target platform
    final content = await file.readAsString();
    final injectedContent = '$content\n\n// Injected secrets\n$code';
    
    if (minify) {
      // Simple minification
      final minified = injectedContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('//'))
          .join('\n');
      await file.writeAsString(minified);
    } else {
      await file.writeAsString(injectedContent);
    }
  }

  bool _isHighSensitivity(SecretDefinition secret) {
    // Determine if a secret is highly sensitive based on name or tags
    final sensitivePatterns = ['password', 'key', 'token', 'secret', 'private'];
    final name = secret.name.toLowerCase();
    
    return sensitivePatterns.any((pattern) => name.contains(pattern));
  }

  String _obfuscateName(String name) {
    // Simple name obfuscation
    return 's${name.hashCode.abs().toRadixString(16)}';
  }

  String _generateDataArray(SecretDefinition secret, dynamic obfuscation, int nonce) {
    // Generate obfuscated data array
    final secretData = utf8.encode(jsonEncode(secret.value));
    final obfuscatedData = obfuscation.obfuscate(secretData, nonce);
    return obfuscatedData.join(', ');
  }

  String _generateDeobfuscationFunction(bool debug) {
    return '''
Uint8List _deobfuscate(List<int> data, int nonce) {
  // Implement deobfuscation logic here
  ${debug ? '// Debug: deobfuscating \${data.length} bytes with nonce \$nonce' : ''}
  return Uint8List.fromList(data);
}
''';
  }
}
