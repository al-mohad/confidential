/// Example demonstrating CLI and build-time integration functionality.
library;

import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('🧰 Dart Confidential - CLI & Build-Time Integration Example\n');

  // Example 1: Project Initialization
  await demonstrateProjectInitialization();

  // Example 2: Code Generation
  await demonstrateCodeGeneration();

  // Example 3: Asset Generation
  await demonstrateAssetGeneration();

  // Example 4: Environment File Generation
  await demonstrateEnvironmentGeneration();

  // Example 5: Build-Time Injection
  await demonstrateBuildTimeInjection();

  // Example 6: Validation and Quality Checks
  await demonstrateValidation();

  // Example 7: Build Runner Integration
  await demonstrateBuildRunnerIntegration();
}

/// Demonstrates project initialization with CLI.
Future<void> demonstrateProjectInitialization() async {
  print('🚀 Project Initialization');
  print('=' * 30);

  print('The CLI provides an init command to set up dart-confidential in your project:');
  print('');
  
  print('📝 Initialize a Flutter project:');
  print('  dart run dart-confidential init --project-type flutter');
  print('');
  
  print('📝 Initialize with examples and build_runner:');
  print('  dart run dart-confidential init \\');
  print('    --project-type flutter \\');
  print('    --with-examples \\');
  print('    --with-build-runner \\');
  print('    --with-analytics');
  print('');
  
  print('📝 Initialize for different project types:');
  print('  dart run dart-confidential init --project-type dart');
  print('  dart run dart-confidential init --project-type package');
  print('');
  
  print('✅ What gets created:');
  print('  - confidential.yaml (configuration file)');
  print('  - lib/generated/ (output directory)');
  print('  - assets/encrypted/ (encrypted assets directory)');
  print('  - scripts/build_secrets.sh (build script)');
  print('  - build.yaml (build_runner configuration)');
  print('  - Updated .gitignore');
  print('  - Example usage files');
  print('');
  
  print('🔒 Platform-specific initialization:');
  print('  - Web projects get web-safe example secrets');
  print('  - Native projects get full security examples');
  print('  - Platform-specific warnings and recommendations');
  
  print('\n');
}

/// Demonstrates code generation from configuration.
Future<void> demonstrateCodeGeneration() async {
  print('⚙️  Code Generation');
  print('=' * 20);

  print('Generate obfuscated Dart code from configuration:');
  print('');
  
  print('📝 Basic code generation:');
  print('  dart run dart-confidential obfuscate \\');
  print('    --config confidential.yaml \\');
  print('    --output lib/generated/confidential.dart');
  print('');
  
  print('📝 Watch mode for development:');
  print('  dart run dart-confidential obfuscate \\');
  print('    --config confidential.yaml \\');
  print('    --output lib/generated/confidential.dart \\');
  print('    --watch');
  print('');
  
  print('📝 Different output formats:');
  print('  # Dart code (default)');
  print('  dart run dart-confidential obfuscate --format dart');
  print('');
  print('  # JSON data');
  print('  dart run dart-confidential obfuscate --format json');
  print('');
  print('  # YAML configuration');
  print('  dart run dart-confidential obfuscate --format yaml');
  print('');
  
  print('📝 Minified output:');
  print('  dart run dart-confidential obfuscate --minify');
  print('');
  
  print('✅ Generated code features:');
  print('  - Platform-aware secret access');
  print('  - Web security warnings');
  print('  - Obfuscated data arrays');
  print('  - Type-safe getters');
  print('  - Platform detection utilities');
  
  print('\n');
}

/// Demonstrates encrypted asset generation.
Future<void> demonstrateAssetGeneration() async {
  print('📦 Asset Generation');
  print('=' * 20);

  print('Generate encrypted asset files for runtime loading:');
  print('');
  
  print('📝 Generate separate asset files:');
  print('  dart run dart-confidential generate-assets \\');
  print('    --config confidential.yaml \\');
  print('    --output-dir assets/encrypted \\');
  print('    --format binary \\');
  print('    --split');
  print('');
  
  print('📝 Generate combined asset file:');
  print('  dart run dart-confidential generate-assets \\');
  print('    --config confidential.yaml \\');
  print('    --output-dir assets/encrypted \\');
  print('    --format json \\');
  print('    --no-split');
  print('');
  
  print('📝 Different asset formats:');
  print('  # Binary files (most compact)');
  print('  dart run dart-confidential generate-assets --format binary');
  print('');
  print('  # JSON files (human readable)');
  print('  dart run dart-confidential generate-assets --format json');
  print('');
  print('  # Base64 encoded files');
  print('  dart run dart-confidential generate-assets --format base64');
  print('');
  
  print('📝 Compressed assets:');
  print('  dart run dart-confidential generate-assets --compress');
  print('');
  
  print('📝 Asset manifest generation:');
  print('  dart run dart-confidential generate-assets \\');
  print('    --manifest assets_manifest.json');
  print('');
  
  print('✅ Generated assets:');
  print('  - Encrypted binary/JSON files');
  print('  - Asset manifest for loading');
  print('  - Compressed data (optional)');
  print('  - Runtime loader code');
  
  print('\n');
}

/// Demonstrates environment file generation.
Future<void> demonstrateEnvironmentGeneration() async {
  print('🌍 Environment File Generation');
  print('=' * 35);

  print('Generate environment files with encrypted secrets:');
  print('');
  
  print('📝 Generate .env file:');
  print('  dart run dart-confidential generate-env \\');
  print('    --config confidential.yaml \\');
  print('    --output .env.encrypted \\');
  print('    --format dotenv \\');
  print('    --environment production');
  print('');
  
  print('📝 Different environment formats:');
  print('  # .env format');
  print('  dart run dart-confidential generate-env --format dotenv');
  print('');
  print('  # JSON format');
  print('  dart run dart-confidential generate-env --format json');
  print('');
  print('  # YAML format');
  print('  dart run dart-confidential generate-env --format yaml');
  print('');
  print('  # Shell script');
  print('  dart run dart-confidential generate-env --format shell');
  print('');
  
  print('📝 Environment-specific generation:');
  print('  dart run dart-confidential generate-env --environment development');
  print('  dart run dart-confidential generate-env --environment staging');
  print('  dart run dart-confidential generate-env --environment production');
  print('');
  
  print('📝 Encrypted vs plain values:');
  print('  # Encrypted values (default)');
  print('  dart run dart-confidential generate-env --encrypt-values');
  print('');
  print('  # Plain values');
  print('  dart run dart-confidential generate-env --no-encrypt-values');
  print('');
  
  print('📝 Custom variable naming:');
  print('  dart run dart-confidential generate-env \\');
  print('    --prefix "MYAPP_" \\');
  print('    --uppercase');
  print('');
  
  print('✅ Generated environment files:');
  print('  - Platform-specific formats');
  print('  - Environment filtering');
  print('  - Encrypted or plain values');
  print('  - Custom variable naming');
  print('  - Metadata inclusion');
  
  print('\n');
}

/// Demonstrates build-time secret injection.
Future<void> demonstrateBuildTimeInjection() async {
  print('💉 Build-Time Secret Injection');
  print('=' * 35);

  print('Inject secrets directly into application builds:');
  print('');
  
  print('📝 Flutter app injection:');
  print('  dart run dart-confidential inject-secrets \\');
  print('    --config confidential.yaml \\');
  print('    --target flutter \\');
  print('    --build-dir build \\');
  print('    --injection-method compile-time');
  print('');
  
  print('📝 Different injection methods:');
  print('  # Compile-time injection (most secure)');
  print('  dart run dart-confidential inject-secrets --injection-method compile-time');
  print('');
  print('  # Runtime injection (flexible)');
  print('  dart run dart-confidential inject-secrets --injection-method runtime');
  print('');
  print('  # Hybrid approach (balanced)');
  print('  dart run dart-confidential inject-secrets --injection-method hybrid');
  print('');
  
  print('📝 Platform-specific injection:');
  print('  dart run dart-confidential inject-secrets --platform android');
  print('  dart run dart-confidential inject-secrets --platform ios');
  print('  dart run dart-confidential inject-secrets --platform web');
  print('  dart run dart-confidential inject-secrets --platform desktop');
  print('');
  
  print('📝 Advanced options:');
  print('  dart run dart-confidential inject-secrets \\');
  print('    --minify \\');
  print('    --obfuscate-names \\');
  print('    --debug');
  print('');
  
  print('✅ Injection strategies:');
  print('  - Compile-time: Secrets embedded in binary');
  print('  - Runtime: Secrets loaded from encrypted assets');
  print('  - Hybrid: Mix based on sensitivity levels');
  print('  - Platform-aware: Different approaches per platform');
  
  print('\n');
}

/// Demonstrates validation and quality checks.
Future<void> demonstrateValidation() async {
  print('✅ Validation & Quality Checks');
  print('=' * 35);

  print('Validate configuration and detect issues:');
  print('');
  
  print('📝 Basic validation:');
  print('  dart run dart-confidential validate --config confidential.yaml');
  print('');
  
  print('📝 Strict validation mode:');
  print('  dart run dart-confidential validate \\');
  print('    --config confidential.yaml \\');
  print('    --strict');
  print('');
  
  print('📝 Specific validation checks:');
  print('  dart run dart-confidential validate \\');
  print('    --check-platform \\');
  print('    --check-duplicates \\');
  print('    --check-algorithms');
  print('');
  
  print('📝 Auto-fix issues:');
  print('  dart run dart-confidential validate \\');
  print('    --config confidential.yaml \\');
  print('    --fix');
  print('');
  
  print('✅ Validation checks:');
  print('  - Duplicate secret names');
  print('  - Invalid algorithms');
  print('  - Platform security warnings');
  print('  - Weak secret values (strict mode)');
  print('  - Configuration consistency');
  print('');
  
  print('🔧 Auto-fixes:');
  print('  - Replace invalid algorithms');
  print('  - Fix configuration format issues');
  print('  - Create backup before changes');
  
  print('\n');
}

/// Demonstrates build_runner integration.
Future<void> demonstrateBuildRunnerIntegration() async {
  print('🔄 Build Runner Integration');
  print('=' * 30);

  print('Integrate with Dart build_runner for automatic generation:');
  print('');
  
  print('📝 Setup build.yaml:');
  print('''
targets:
  \$default:
    builders:
      confidential|confidential_builder:
        enabled: true
        options:
          config_file: confidential.yaml
          output_file: lib/generated/confidential.dart
          generate_assets: true
          assets_dir: assets/encrypted
          generate_env: true
          env_format: dotenv
''');
  print('');
  
  print('📝 Run build_runner:');
  print('  # One-time build');
  print('  dart run build_runner build');
  print('');
  print('  # Watch mode');
  print('  dart run build_runner watch');
  print('');
  print('  # Clean and rebuild');
  print('  dart run build_runner clean');
  print('  dart run build_runner build --delete-conflicting-outputs');
  print('');
  
  print('📝 Advanced build_runner options:');
  print('  dart run build_runner build \\');
  print('    --verbose \\');
  print('    --delete-conflicting-outputs \\');
  print('    --config build.yaml');
  print('');
  
  print('✅ Build_runner features:');
  print('  - Automatic code generation on file changes');
  print('  - Platform-aware generation');
  print('  - Asset and environment file generation');
  print('  - Integration with existing build process');
  print('  - Configurable output paths and formats');
  print('');
  
  print('🔧 Build configuration options:');
  print('  - output_file: Custom output path');
  print('  - generate_assets: Enable asset generation');
  print('  - assets_dir: Asset output directory');
  print('  - generate_env: Enable environment file generation');
  print('  - env_format: Environment file format');
  
  print('\n');
}

/// Shows a complete workflow example.
void showCompleteWorkflow() {
  print('🎯 Complete Workflow Example');
  print('=' * 30);

  print('''
# 1. Initialize project
dart run dart-confidential init --project-type flutter --with-build-runner

# 2. Edit confidential.yaml with your secrets
# (Add your API keys, database passwords, etc.)

# 3. Generate code
dart run dart-confidential obfuscate

# 4. Generate assets for runtime loading
dart run dart-confidential generate-assets --format binary --split

# 5. Generate environment files
dart run dart-confidential generate-env --format dotenv --environment production

# 6. Validate configuration
dart run dart-confidential validate --strict

# 7. Build with build_runner (automatic)
dart run build_runner build

# 8. Inject secrets for production build
dart run dart-confidential inject-secrets --target flutter --injection-method hybrid

# 9. Build your app
flutter build apk --release
''');

  print('✅ Result:');
  print('  - Secrets are obfuscated and embedded in your app');
  print('  - Platform-specific security warnings provided');
  print('  - Runtime assets available for dynamic loading');
  print('  - Environment files ready for deployment');
  print('  - Build process integrated and automated');
  
  print('\n✅ All CLI and build-time integration examples completed!');
}
