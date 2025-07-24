/// Example demonstrating platform-specific support and web handling.
library;

import 'package:confidential/confidential.dart';

void main() async {
  print('📱 Dart Confidential - Platform-Specific Support Example\n');

  // Example 1: Platform Detection and Security Assessment
  await demonstratePlatformDetection();

  // Example 2: Web-Aware Obfuscated Values
  await demonstrateWebAwareValues();

  // Example 3: Platform-Specific Configuration
  await demonstratePlatformConfiguration();

  // Example 4: Fallback Strategies for Web
  await demonstrateWebFallbacks();

  // Example 5: Global Platform Management
  await demonstrateGlobalPlatformManagement();

  // Example 6: Security Recommendations
  await demonstrateSecurityRecommendations();
}

/// Demonstrates platform detection and security assessment.
Future<void> demonstratePlatformDetection() async {
  print('🔍 Platform Detection and Security Assessment');
  print('=' * 50);

  // Detect current platform
  final platform = PlatformDetector.detectPlatform();
  final securityInfo = PlatformDetector.getSecurityInfo();

  print('Current Platform: ${platform.name}');
  print('Security Level: ${securityInfo.securityLevel.name}');
  print('Description: ${securityInfo.description}');
  print('');

  // Platform characteristics
  print('Platform Characteristics:');
  print('  - Is Web: ${PlatformDetector.isWeb}');
  print('  - Is Mobile: ${PlatformDetector.isMobile}');
  print('  - Is Desktop: ${PlatformDetector.isDesktop}');
  print('  - Is Server: ${PlatformDetector.isServer}');
  print('  - Secrets Secure: ${PlatformDetector.areSecretsSecure}');
  print('  - Should Show Warnings: ${PlatformDetector.shouldShowWarnings}');
  print('');

  // Security warnings
  if (securityInfo.warnings.isNotEmpty) {
    print('⚠️  Security Warnings:');
    for (final warning in securityInfo.warnings) {
      print('  - $warning');
    }
    print('');
  }

  // Security recommendations
  if (securityInfo.recommendations.isNotEmpty) {
    print('💡 Security Recommendations:');
    for (final rec in securityInfo.recommendations.take(3)) {
      print('  - $rec');
    }
    print('');
  }

  print('\n');
}

/// Demonstrates web-aware obfuscated values.
Future<void> demonstrateWebAwareValues() async {
  print('🌐 Web-Aware Obfuscated Values');
  print('=' * 40);

  // Create regular obfuscated values
  final apiKey = 'sk_live_1234567890abcdef'.obfuscate(algorithm: 'aes-256-gcm');
  final databaseUrl = 'postgresql://user:pass@localhost:5432/db'.obfuscate(algorithm: 'aes-256-gcm');
  final encryptionKey = 'master_encryption_key_xyz789'.obfuscate(algorithm: 'chacha20-poly1305');

  print('✅ Created obfuscated values:');
  print('  - API Key: ${apiKey.value.substring(0, 10)}...');
  print('  - Database URL: ${databaseUrl.value.substring(0, 15)}...');
  print('  - Encryption Key: ${encryptionKey.value.substring(0, 10)}...');
  print('');

  // Create web-aware versions with different configurations
  print('🔧 Creating web-aware versions...');

  // 1. With warnings (default)
  final webAwareApiKey = apiKey.withWebWarnings('apiKey');
  print('  ✅ API Key with web warnings');

  // 2. With fallback for web
  final webAwareDatabaseUrl = databaseUrl.webAware(
    'databaseUrl',
    fallbackValue: 'sqlite:///fallback.db',
    config: WebAwareConfig.webWithWarnings(),
  );
  print('  ✅ Database URL with fallback');

  // 3. Disabled on web
  final webAwareEncryptionKey = encryptionKey.webDisabled(
    'encryptionKey',
    fallbackValue: 'fallback_key_for_web',
  );
  print('  ✅ Encryption Key disabled on web');
  print('');

  // Access values (this will show platform-specific behavior)
  print('🔄 Accessing web-aware values...');
  
  try {
    final keyValue = webAwareApiKey.value;
    print('  - API Key accessed: ${keyValue.substring(0, 10)}...');
  } catch (e) {
    print('  - API Key access failed: $e');
  }

  try {
    final dbValue = webAwareDatabaseUrl.value;
    print('  - Database URL accessed: ${dbValue.substring(0, 15)}...');
  } catch (e) {
    print('  - Database URL access failed: $e');
  }

  try {
    final encValue = webAwareEncryptionKey.value;
    print('  - Encryption Key accessed: ${encValue.substring(0, 10)}...');
  } catch (e) {
    print('  - Encryption Key access failed: $e');
  }

  print('');

  // Show platform-specific information
  print('📊 Platform-specific information:');
  print('  - Current Platform: ${webAwareApiKey.currentPlatform.name}');
  print('  - Is Secure: ${webAwareApiKey.isSecureOnCurrentPlatform}');
  print('  - Security Level: ${webAwareApiKey.platformSecurityInfo.securityLevel.name}');

  print('\n');
}

/// Demonstrates platform-specific configuration.
Future<void> demonstratePlatformConfiguration() async {
  print('⚙️  Platform-Specific Configuration');
  print('=' * 40);

  // Create different configurations for different environments
  print('🏭 Production Configuration:');
  final prodConfig = PlatformAwareConfig.production();
  print('  - Auto-detect platform: ${prodConfig.autoDetectPlatform}');
  print('  - Show platform info: ${prodConfig.showPlatformInfo}');
  print('  - Enforce security: ${prodConfig.enforcePlatformSecurity}');
  print('  - Web warnings: ${prodConfig.webConfig.showWebWarnings}');
  print('');

  print('🔧 Development Configuration:');
  final devConfig = PlatformAwareConfig.development();
  print('  - Auto-detect platform: ${devConfig.autoDetectPlatform}');
  print('  - Show platform info: ${devConfig.showPlatformInfo}');
  print('  - Enforce security: ${devConfig.enforcePlatformSecurity}');
  print('  - Web warnings: ${devConfig.webConfig.showWebWarnings}');
  print('');

  print('🔒 Web-Secure Configuration:');
  final webSecureConfig = PlatformAwareConfig.webSecure();
  print('  - Disable secrets on web: ${webSecureConfig.webConfig.disableSecretsOnWeb}');
  print('  - Use fallback on web: ${webSecureConfig.webConfig.useFallbackOnWeb}');
  print('  - Show web warnings: ${webSecureConfig.webConfig.showWebWarnings}');
  print('');

  // Demonstrate platform-specific config selection
  print('🎯 Platform-specific config selection:');
  for (final platform in [
    ConfidentialPlatform.web,
    ConfidentialPlatform.ios,
    ConfidentialPlatform.android,
    ConfidentialPlatform.server,
  ]) {
    final config = prodConfig.getConfigForPlatform(platform);
    print('  - ${platform.name}: warnings=${config.showWebWarnings}, disabled=${config.disableSecretsOnWeb}');
  }

  print('\n');
}

/// Demonstrates fallback strategies for web platform.
Future<void> demonstrateWebFallbacks() async {
  print('🌐 Web Fallback Strategies');
  print('=' * 30);

  // Strategy 1: Public API keys (safe for web)
  print('📡 Strategy 1: Public API Keys');
  final publicApiKey = 'pk_live_public_key_12345'.obfuscate(algorithm: 'aes-256-gcm');
  final webSafePublicKey = publicApiKey.webAware(
    'publicApiKey',
    config: const WebAwareConfig(
      showWebWarnings: false, // Public keys are safe
      logPlatformWarnings: false,
    ),
  );
  print('  ✅ Public API Key: ${webSafePublicKey.value.substring(0, 15)}...');
  print('  💡 Public keys are safe to use on web');
  print('');

  // Strategy 2: Environment-specific fallbacks
  print('🔄 Strategy 2: Environment-Specific Fallbacks');
  final serverApiKey = 'sk_live_server_key_secret'.obfuscate(algorithm: 'aes-256-gcm');
  final environmentAwareKey = serverApiKey.webAware(
    'serverApiKey',
    fallbackValue: 'pk_live_public_fallback_key',
    config: const WebAwareConfig(
      useFallbackOnWeb: true,
      showWebWarnings: true,
    ),
  );
  
  final currentPlatform = PlatformDetector.detectPlatform();
  if (currentPlatform == ConfidentialPlatform.web) {
    print('  🌐 Web detected - using fallback key');
  } else {
    print('  🖥️  Non-web platform - using real key');
  }
  
  try {
    final keyValue = environmentAwareKey.value;
    print('  ✅ Key accessed: ${keyValue.substring(0, 15)}...');
  } catch (e) {
    print('  ❌ Key access failed: $e');
  }
  print('');

  // Strategy 3: Server-side proxy
  print('🔗 Strategy 3: Server-Side Proxy Pattern');
  print('  💡 For web applications:');
  print('    - Store secrets on server only');
  print('    - Create API endpoints for secret-dependent operations');
  print('    - Use authentication tokens on client side');
  print('    - Implement proper CORS and rate limiting');
  print('');
  
  // Example of what NOT to do on web
  print('❌ What NOT to do on web:');
  print('  - Store database passwords in client code');
  print('  - Include private API keys in JavaScript bundles');
  print('  - Use encryption keys for sensitive data on client');
  print('  - Rely on obfuscation for true security');

  print('\n');
}

/// Demonstrates global platform management.
Future<void> demonstrateGlobalPlatformManagement() async {
  print('🌍 Global Platform Management');
  print('=' * 35);

  // Initialize global configuration
  print('🚀 Initializing global platform configuration...');
  GlobalPlatformConfig.initializeForEnvironment(
    isProduction: false, // Development mode
    showPlatformInfo: true,
  );
  print('  ✅ Global configuration initialized');
  print('');

  // Get global manager
  final globalManager = GlobalPlatformConfig.getGlobalManager();
  print('📦 Global Secret Manager:');
  print('  - Platform: ${globalManager.currentPlatform.name}');
  print('  - Secrets secure: ${globalManager.areSecretsSecure}');
  print('');

  // Register secrets globally
  print('📝 Registering global secrets...');
  globalManager.registerSecret('globalApiKey', 'global_api_key_123');
  globalManager.registerSecret('globalConfig', 'production_config_xyz');
  globalManager.registerSecret('globalToken', 'auth_token_abc', fallbackValue: 'demo_token');

  print('  ✅ Registered ${globalManager.secretCount} secrets');
  print('  📋 Secret names: ${globalManager.secretNames.join(', ')}');
  print('');

  // Access global secrets
  print('🔄 Accessing global secrets...');
  for (final secretName in globalManager.secretNames) {
    try {
      final value = globalManager.getSecret<String>(secretName);
      if (value != null) {
        print('  ✅ $secretName: ${value.substring(0, 10)}...');
      } else {
        print('  ❌ $secretName: null');
      }
    } catch (e) {
      print('  ❌ $secretName: Error - $e');
    }
  }

  print('\n');
}

/// Demonstrates security recommendations for different platforms.
Future<void> demonstrateSecurityRecommendations() async {
  print('🛡️  Security Recommendations by Platform');
  print('=' * 45);

  // Show recommendations for each platform
  final platforms = [
    ConfidentialPlatform.web,
    ConfidentialPlatform.ios,
    ConfidentialPlatform.android,
    ConfidentialPlatform.server,
    ConfidentialPlatform.macos,
    ConfidentialPlatform.windows,
  ];

  for (final platform in platforms) {
    final securityInfo = PlatformDetector.getSecurityInfo(platform);
    
    print('📱 ${platform.name.toUpperCase()}');
    print('   Security Level: ${securityInfo.securityLevel.name}');
    print('   ${securityInfo.description}');
    
    if (securityInfo.warnings.isNotEmpty) {
      print('   ⚠️  Key Warnings:');
      for (final warning in securityInfo.warnings.take(2)) {
        print('      - $warning');
      }
    }
    
    if (securityInfo.recommendations.isNotEmpty) {
      print('   💡 Recommendations:');
      for (final rec in securityInfo.recommendations.take(3)) {
        print('      - $rec');
      }
    }
    
    print('');
  }

  // General best practices
  print('🎯 General Best Practices:');
  print('   1. Use server-side APIs for sensitive operations');
  print('   2. Implement proper authentication and authorization');
  print('   3. Use environment variables for configuration');
  print('   4. Enable platform-specific security features');
  print('   5. Regular security audits and updates');
  print('   6. Monitor for suspicious access patterns');
  print('   7. Use HTTPS/TLS for all network communication');
  print('   8. Implement proper error handling and logging');

  print('\n✅ All platform examples completed successfully!');
}
