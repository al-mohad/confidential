/// Dart literals obfuscator to defend against static reverse engineering.
///
/// A highly configurable and performant tool for obfuscating Dart literals
/// embedded in the application code that you should protect from static code
/// analysis, making the app more resistant to reverse engineering.
library;

export 'src/analytics/analytics_obfuscated.dart';
// Analytics and audit logging
export 'src/analytics/audit_logger.dart';
export 'src/async/async_obfuscated.dart';
// Asynchronous secret loading
export 'src/async/secret_providers.dart';
// Secret expiry and rotation
export 'src/expiry/async_expirable.dart';
export 'src/expiry/expirable_obfuscated.dart';
export 'src/expiry/expirable_secret.dart';
export 'src/expiry/expiry_aware_providers.dart';
export 'src/expiry/expiry_extensions.dart';
export 'src/expiry/secret_rotation_manager.dart';
// Extension methods for improved ergonomics
export 'src/extensions/encryption_extensions.dart';
// Remote secret providers
export 'src/remote/aws_secrets_manager.dart';
export 'src/remote/cached_remote_provider.dart';
export 'src/remote/google_secret_manager.dart';
export 'src/remote/hashicorp_vault.dart';
export 'src/remote/local_cache_manager.dart';
export 'src/remote/remote_secret_provider.dart';
// Enhanced grouping and namespacing
export 'src/grouping/secret_groups.dart';
export 'src/integrations/bloc_integration.dart';
// Popular package integrations
export 'src/integrations/dio_integration.dart';
export 'src/integrations/get_it_integration.dart'
    hide AsyncObfuscatedValueProvider;
export 'src/integrations/getx_integration.dart';
export 'src/integrations/integration_manager.dart';
export 'src/integrations/provider_integration.dart';
export 'src/integrations/riverpod_integration.dart' hide ProviderLike;
// Compression implementations
export 'src/obfuscation/compression/compression.dart';
// Encryption implementations
export 'src/obfuscation/encryption/encryption.dart';
export 'src/obfuscation/encryption/key_management.dart';
export 'src/obfuscation/encryption/rsa_encryption.dart';
export 'src/obfuscation/obfuscated.dart';
// Core obfuscation functionality
export 'src/obfuscation/obfuscation.dart';
// Randomization implementations
export 'src/obfuscation/randomization/randomization.dart';
export 'src/obfuscation/secret.dart';
export 'src/platform/hardware_key_storage.dart';
// export 'src/platform/native_hardware_key_storage.dart';
export 'src/platform/platform_config.dart';
// Platform-specific support and web handling
export 'src/platform/platform_support.dart';
export 'src/platform/web_aware_obfuscated.dart';

// CLI and build-time integration (not available on web)
// Use direct imports for CLI tools in non-web environments:
// import 'package:confidential/src/cli/cli.dart';
// import 'package:confidential/src/builder/confidential_builder.dart';
