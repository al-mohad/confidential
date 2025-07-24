/// Dart literals obfuscator to defend against static reverse engineering.
///
/// A highly configurable and performant tool for obfuscating Dart literals
/// embedded in the application code that you should protect from static code
/// analysis, making the app more resistant to reverse engineering.
library;

// Core obfuscation functionality
export 'src/obfuscation/obfuscation.dart';
export 'src/obfuscation/obfuscated.dart';
export 'src/obfuscation/secret.dart';

// Compression implementations
export 'src/obfuscation/compression/compression.dart';

// Encryption implementations
export 'src/obfuscation/encryption/encryption.dart';
export 'src/obfuscation/encryption/rsa_encryption.dart';
export 'src/obfuscation/encryption/key_management.dart';

// Randomization implementations
export 'src/obfuscation/randomization/randomization.dart';

// Extension methods for improved ergonomics
export 'src/extensions/encryption_extensions.dart';

// Asynchronous secret loading
export 'src/async/secret_providers.dart';
export 'src/async/async_obfuscated.dart';

// Enhanced grouping and namespacing
export 'src/grouping/secret_groups.dart';

// Analytics and audit logging
export 'src/analytics/audit_logger.dart';
export 'src/analytics/analytics_obfuscated.dart';

// Platform-specific support and web handling
export 'src/platform/platform_support.dart';
export 'src/platform/web_aware_obfuscated.dart';
export 'src/platform/platform_config.dart';

// Popular package integrations
export 'src/integrations/dio_integration.dart';
export 'src/integrations/provider_integration.dart';
export 'src/integrations/riverpod_integration.dart' hide ProviderLike;
export 'src/integrations/get_it_integration.dart' hide AsyncObfuscatedValueProvider;
export 'src/integrations/bloc_integration.dart';
export 'src/integrations/getx_integration.dart';
export 'src/integrations/integration_manager.dart';

// CLI and build-time integration (not available on web)
// Use direct imports for CLI tools in non-web environments:
// import 'package:confidential/src/cli/cli.dart';
// import 'package:confidential/src/builder/confidential_builder.dart';
