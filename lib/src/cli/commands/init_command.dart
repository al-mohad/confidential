/// Command for initializing dart-confidential in a project.
library;

import 'dart:io';

import 'package:args/args.dart';

import '../../platform/platform_support.dart';
import 'base_command.dart';

/// Command for initializing dart-confidential in a project.
class InitCommand extends CliCommand {
  @override
  String get name => 'init';

  @override
  String get description => 'Initialize dart-confidential in a project';

  @override
  ArgParser createArgParser() {
    return ArgParser()
      ..addOption(
        'project-type',
        abbr: 't',
        help: 'Type of project (flutter, dart, package)',
        allowed: ['flutter', 'dart', 'package'],
        defaultsTo: 'flutter',
      )
      ..addOption(
        'config-file',
        abbr: 'c',
        help: 'Configuration file name',
        defaultsTo: 'confidential.yaml',
      )
      ..addFlag(
        'with-examples',
        help: 'Include example secrets',
        defaultsTo: true,
      )
      ..addFlag(
        'with-build-runner',
        help: 'Setup build_runner integration',
        defaultsTo: true,
      )
      ..addFlag(
        'with-analytics',
        help: 'Enable analytics configuration',
        negatable: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing files',
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

    final projectType = results['project-type'] as String;
    final configFile = results['config-file'] as String;
    final withExamples = results['with-examples'] as bool;
    final withBuildRunner = results['with-build-runner'] as bool;
    final withAnalytics = results['with-analytics'] as bool;
    final force = results['force'] as bool;

    try {
      log('Initializing dart-confidential for $projectType project...', verbose: verbose);

      // Check if already initialized
      final configPath = File(configFile);
      if (configPath.existsSync() && !force) {
        logError('Configuration file already exists: $configFile (use --force to overwrite)');
        return 1;
      }

      // Detect platform and provide recommendations
      final platform = PlatformDetector.detectPlatform();
      final securityInfo = PlatformDetector.getSecurityInfo(platform);
      
      log('Detected platform: ${platform.name}', verbose: verbose);
      log('Security level: ${securityInfo.securityLevel.name}', verbose: verbose);

      // Create configuration file
      await _createConfigurationFile(
        configFile,
        projectType,
        withExamples,
        withAnalytics,
        platform,
        verbose,
      );

      // Setup build_runner integration if requested
      if (withBuildRunner) {
        await _setupBuildRunner(projectType, verbose);
      }

      // Create directory structure
      await _createDirectoryStructure(projectType, verbose);

      // Create example files
      if (withExamples) {
        await _createExampleFiles(projectType, verbose);
      }

      // Show platform-specific recommendations
      _showPlatformRecommendations(platform, securityInfo);

      logSuccess('Successfully initialized dart-confidential!');
      
      print('');
      print('Next steps:');
      print('  1. Edit $configFile to add your secrets');
      print('  2. Run: dart run dart-confidential obfuscate');
      print('  3. Import generated code in your application');
      
      if (withBuildRunner) {
        print('  4. Run: dart run build_runner build');
      }

      return 0;
    } catch (e) {
      logError('Failed to initialize project: $e');
      return 1;
    }
  }

  Future<void> _createConfigurationFile(
    String configFile,
    String projectType,
    bool withExamples,
    bool withAnalytics,
    ConfidentialPlatform platform,
    bool verbose,
  ) async {
    log('Creating configuration file: $configFile', verbose: verbose);

    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('# Dart Confidential Configuration');
    buffer.writeln('# Generated for $projectType project');
    buffer.writeln('# Platform: ${platform.name}');
    buffer.writeln('');

    // Core configuration
    buffer.writeln('# Obfuscation algorithm');
    buffer.writeln('algorithm:');
    buffer.writeln('  - randomization');
    buffer.writeln('  - compression');
    buffer.writeln('  - encryption');
    buffer.writeln('');

    // Default settings
    buffer.writeln('# Default settings');
    buffer.writeln('defaultAccessModifier: internal');
    buffer.writeln('defaultNamespace: ${_getDefaultNamespace(projectType)}');
    buffer.writeln('experimentalMode: false');
    buffer.writeln('');

    // Analytics configuration
    if (withAnalytics) {
      buffer.writeln('# Analytics and audit logging');
      buffer.writeln('analytics:');
      buffer.writeln('  enabled: true');
      buffer.writeln('  enableAccessCounters: true');
      buffer.writeln('  enableSuspiciousDetection: true');
      buffer.writeln('  anonymizeData: true');
      buffer.writeln('  maxLogEntries: 1000');
      buffer.writeln('  suspiciousTimeWindowMinutes: 5');
      buffer.writeln('  maxAccessAttemptsPerWindow: 20');
      buffer.writeln('');
    }

    // Platform-specific warnings
    if (platform == ConfidentialPlatform.web) {
      buffer.writeln('# ⚠️  WEB PLATFORM WARNING:');
      buffer.writeln('# Secrets on web are not secure and can be extracted from JavaScript.');
      buffer.writeln('# Consider using server-side APIs for sensitive operations.');
      buffer.writeln('');
    }

    // Example secrets
    if (withExamples) {
      buffer.writeln('# Example secrets');
      buffer.writeln('secrets:');
      
      if (platform == ConfidentialPlatform.web) {
        // Web-safe examples
        buffer.writeln('  - name: publicApiKey');
        buffer.writeln('    value: pk_live_example_public_key_12345');
        buffer.writeln('    algorithm: aes-256-gcm');
        buffer.writeln('    nonce: 12345');
        buffer.writeln('    accessModifier: internal');
        buffer.writeln('    namespace: ${_getDefaultNamespace(projectType)}.Public');
        buffer.writeln('    tags:');
        buffer.writeln('      - api');
        buffer.writeln('      - public');
        buffer.writeln('      - web-safe');
        buffer.writeln('    environment: development');
        buffer.writeln('    priority: low');
        buffer.writeln('');
        
        buffer.writeln('  - name: configurationFlag');
        buffer.writeln('    value: true');
        buffer.writeln('    algorithm: aes-256-gcm');
        buffer.writeln('    nonce: 67890');
        buffer.writeln('    accessModifier: internal');
        buffer.writeln('    namespace: ${_getDefaultNamespace(projectType)}.Config');
        buffer.writeln('    tags:');
        buffer.writeln('      - config');
        buffer.writeln('      - feature-flag');
        buffer.writeln('    environment: development');
        buffer.writeln('    priority: low');
      } else {
        // Secure platform examples
        buffer.writeln('  - name: apiKey');
        buffer.writeln('    value: sk_live_example_secret_key_12345');
        buffer.writeln('    algorithm: aes-256-gcm');
        buffer.writeln('    nonce: 12345');
        buffer.writeln('    accessModifier: internal');
        buffer.writeln('    namespace: ${_getDefaultNamespace(projectType)}.Api');
        buffer.writeln('    tags:');
        buffer.writeln('      - api');
        buffer.writeln('      - external');
        buffer.writeln('      - production');
        buffer.writeln('    environment: development');
        buffer.writeln('    priority: high');
        buffer.writeln('');
        
        buffer.writeln('  - name: databasePassword');
        buffer.writeln('    value: super_secret_db_password_123');
        buffer.writeln('    algorithm: chacha20-poly1305');
        buffer.writeln('    nonce: 67890');
        buffer.writeln('    accessModifier: internal');
        buffer.writeln('    namespace: ${_getDefaultNamespace(projectType)}.Database');
        buffer.writeln('    tags:');
        buffer.writeln('      - database');
        buffer.writeln('      - internal');
        buffer.writeln('      - critical');
        buffer.writeln('    environment: development');
        buffer.writeln('    priority: critical');
        buffer.writeln('');
        
        buffer.writeln('  - name: encryptionKey');
        buffer.writeln('    value: master_encryption_key_xyz789');
        buffer.writeln('    algorithm: aes-256-gcm');
        buffer.writeln('    nonce: 11111');
        buffer.writeln('    accessModifier: internal');
        buffer.writeln('    namespace: ${_getDefaultNamespace(projectType)}.Security');
        buffer.writeln('    tags:');
        buffer.writeln('      - encryption');
        buffer.writeln('      - security');
        buffer.writeln('      - master');
        buffer.writeln('    environment: development');
        buffer.writeln('    priority: critical');
      }
    } else {
      buffer.writeln('# Add your secrets here');
      buffer.writeln('secrets: []');
    }

    await File(configFile).writeAsString(buffer.toString());
  }

  Future<void> _setupBuildRunner(String projectType, bool verbose) async {
    log('Setting up build_runner integration...', verbose: verbose);

    // Create build.yaml
    const buildYamlContent = '''
targets:
  \$default:
    builders:
      confidential|confidential_builder:
        enabled: true
        options:
          config_file: confidential.yaml
          output_file: lib/generated/confidential.dart
''';

    await File('build.yaml').writeAsString(buildYamlContent);
    log('Created build.yaml', verbose: verbose);

    // Update pubspec.yaml dev_dependencies
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      var content = await pubspecFile.readAsString();
      
      if (!content.contains('build_runner:')) {
        // Add build_runner dependency
        if (content.contains('dev_dependencies:')) {
          content = content.replaceFirst(
            'dev_dependencies:',
            'dev_dependencies:\n  build_runner: ^2.4.7',
          );
        } else {
          content += '\ndev_dependencies:\n  build_runner: ^2.4.7\n';
        }
        
        await pubspecFile.writeAsString(content);
        log('Updated pubspec.yaml with build_runner dependency', verbose: verbose);
      }
    }
  }

  Future<void> _createDirectoryStructure(String projectType, bool verbose) async {
    log('Creating directory structure...', verbose: verbose);

    final directories = [
      'lib/generated',
      'assets/encrypted',
      'scripts',
    ];

    for (final dir in directories) {
      await Directory(dir).create(recursive: true);
      log('Created directory: $dir', verbose: verbose);
    }

    // Create .gitignore entries
    final gitignoreFile = File('.gitignore');
    const gitignoreEntries = '''

# Dart Confidential
lib/generated/confidential.dart
assets/encrypted/
.env.encrypted
confidential.yaml.backup
''';

    if (gitignoreFile.existsSync()) {
      final content = await gitignoreFile.readAsString();
      if (!content.contains('# Dart Confidential')) {
        await gitignoreFile.writeAsString(content + gitignoreEntries);
        log('Updated .gitignore', verbose: verbose);
      }
    } else {
      await gitignoreFile.writeAsString(gitignoreEntries);
      log('Created .gitignore', verbose: verbose);
    }
  }

  Future<void> _createExampleFiles(String projectType, bool verbose) async {
    log('Creating example files...', verbose: verbose);

    // Create example usage file
    final exampleContent = '''
// Example usage of dart-confidential
// Generated for $projectType project

import 'generated/confidential.dart';

void main() {
  // Access obfuscated secrets
  print('API Key: \${Secrets.apiKey.substring(0, 10)}...');
  print('Database Password: \${Secrets.databasePassword.substring(0, 5)}...');
  
  // Use with platform-aware handling
  final platformAware = Secrets.apiKey.withWebWarnings('apiKey');
  print('Platform-aware access: \${platformAware.value.substring(0, 10)}...');
}
''';

    await File('lib/example_usage.dart').writeAsString(exampleContent);
    log('Created example usage file', verbose: verbose);

    // Create build script
    final buildScriptContent = '''
#!/bin/bash
# Build script for dart-confidential

echo "Building dart-confidential secrets..."

# Generate obfuscated code
dart run dart-confidential obfuscate --config confidential.yaml --output lib/generated/confidential.dart

# Generate encrypted assets
dart run dart-confidential generate-assets --config confidential.yaml --output-dir assets/encrypted

# Generate environment file
dart run dart-confidential generate-env --config confidential.yaml --output .env.encrypted

echo "Build completed successfully!"
''';

    final buildScript = File('scripts/build_secrets.sh');
    await buildScript.writeAsString(buildScriptContent);
    
    // Make script executable on Unix systems
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['+x', buildScript.path]);
    }
    
    log('Created build script', verbose: verbose);
  }

  void _showPlatformRecommendations(
    ConfidentialPlatform platform,
    PlatformSecurityInfo securityInfo,
  ) {
    print('');
    print('🔒 Platform Security Information:');
    print('   Platform: ${platform.name}');
    print('   Security Level: ${securityInfo.securityLevel.name}');
    print('   ${securityInfo.description}');
    
    if (securityInfo.warnings.isNotEmpty) {
      print('');
      print('⚠️  Security Warnings:');
      for (final warning in securityInfo.warnings.take(2)) {
        print('   - $warning');
      }
    }
    
    if (securityInfo.recommendations.isNotEmpty) {
      print('');
      print('💡 Security Recommendations:');
      for (final rec in securityInfo.recommendations.take(3)) {
        print('   - $rec');
      }
    }
  }

  String _getDefaultNamespace(String projectType) {
    switch (projectType) {
      case 'flutter':
        return 'MyApp.Secrets';
      case 'dart':
        return 'MyPackage.Secrets';
      case 'package':
        return 'Package.Secrets';
      default:
        return 'App.Secrets';
    }
  }
}
