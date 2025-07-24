/// Example demonstrating popular package integrations.
library;

import 'dart:io';

import 'package:confidential/confidential.dart';

void main() async {
  print('🧩 Dart Confidential - Popular Package Integrations Example\n');

  // Example 1: Dio HTTP Client Integration
  await demonstrateDioIntegration();

  // Example 2: Provider Dependency Injection
  await demonstrateProviderIntegration();

  // Example 3: Riverpod Integration
  await demonstrateRiverpodIntegration();

  // Example 4: GetIt Service Locator
  await demonstrateGetItIntegration();

  // Example 5: BLoC State Management
  await demonstrateBlocIntegration();

  // Example 6: GetX State Management
  await demonstrateGetXIntegration();

  // Example 7: Unified Integration Manager
  await demonstrateIntegrationManager();
}

/// Demonstrates Dio HTTP client integration.
Future<void> demonstrateDioIntegration() async {
  print('🌐 Dio HTTP Client Integration');
  print('=' * 40);

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('dio_example');
  final provider = FileSecretProvider(basePath: tempDir.path);

  // Save API tokens
  await provider.saveSecret(
    'authToken',
    'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'.encrypt(
      algorithm: 'aes-256-gcm',
      nonce: 11111,
    ),
  );
  await provider.saveSecret(
    'apiKey',
    'sk_live_abc123def456ghi789'.encrypt(
      algorithm: 'aes-256-gcm',
      nonce: 22222,
    ),
  );

  try {
    // Create Dio interceptor
    final interceptor = ConfidentialDioInterceptor(
      config: const DioIntegrationConfig(
        authHeaderName: 'Authorization',
        tokenPrefix: '',
        enableLogging: true,
        customHeaders: {
          'X-Client-Version': '1.0.0',
          'X-Platform': 'dart-confidential',
        },
      ),
    );

    // Add static token
    final staticApiKey = 'static-api-key-123'.obfuscate(
      algorithm: 'aes-256-gcm',
    );
    interceptor.addStaticToken('X-API-Key', staticApiKey);

    // Add async tokens
    final authToken = AsyncObfuscatedString(
      secretName: 'authToken',
      provider: provider,
      algorithm: 'aes-256-gcm',
    );
    interceptor.addAsyncToken('auth', authToken);

    final apiKey = AsyncObfuscatedString(
      secretName: 'apiKey',
      provider: provider,
      algorithm: 'aes-256-gcm',
    );
    interceptor.addAsyncToken('stripe-key', apiKey);

    // Add dynamic token (e.g., session token)
    interceptor.addDynamicToken('X-Session-ID', () {
      return 'session_${DateTime.now().millisecondsSinceEpoch}';
    });

    print('✅ Dio interceptor configured with:');
    print('  - Static API key for X-API-Key header');
    print('  - Async auth token for Authorization header');
    print('  - Async Stripe key for stripe-key header');
    print('  - Dynamic session ID for X-Session-ID header');
    print('  - Custom headers: X-Client-Version, X-Platform');

    // In real usage, you would add this interceptor to your Dio instance:
    // dio.interceptors.add(interceptor);

    print('📝 Usage in real app:');
    print('```dart');
    print('final dio = Dio();');
    print('dio.interceptors.add(interceptor);');
    print('');
    print('// All requests will automatically include encrypted tokens');
    print('final response = await dio.get("/api/user/profile");');
    print('```');
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates Provider dependency injection.
Future<void> demonstrateProviderIntegration() async {
  print('📦 Provider Dependency Injection');
  print('=' * 40);

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('provider_example');
  final secretProvider = FileSecretProvider(basePath: tempDir.path);

  await secretProvider.saveSecret(
    'databaseUrl',
    'postgresql://user:pass@localhost:5432/mydb'.encrypt(
      algorithm: 'aes-256-gcm',
      nonce: 33333,
    ),
  );

  try {
    // Create Provider-compatible secret manager
    final manager = ConfidentialProviderFactory.createManager();

    // Add static secrets
    final jwtSecret = 'super-secret-jwt-key'.obfuscate(
      algorithm: 'aes-256-gcm',
    );
    manager.addStatic('jwtSecret', jwtSecret);

    final encryptionKey = 'encryption-key-256-bit'.obfuscate(
      algorithm: 'chacha20-poly1305',
    );
    manager.addStatic('encryptionKey', encryptionKey);

    // Add async secrets
    final databaseUrl = AsyncObfuscatedString(
      secretName: 'databaseUrl',
      provider: secretProvider,
      algorithm: 'aes-256-gcm',
    );
    manager.addAsync('databaseUrl', databaseUrl);

    print('✅ Provider manager configured with:');
    print('  - Static JWT secret');
    print('  - Static encryption key');
    print('  - Async database URL');

    // Wait for async secrets to load
    await Future.delayed(const Duration(milliseconds: 500));

    // Access secrets
    final jwt = manager.getStaticValue<String>('jwtSecret');
    final encryption = manager.getStaticValue<String>('encryptionKey');
    final database = await manager.getAsyncValueAsync<String>('databaseUrl');

    print('📊 Loaded secrets:');
    print('  - JWT Secret: ${jwt?.substring(0, 10)}...');
    print('  - Encryption Key: ${encryption?.substring(0, 10)}...');
    print('  - Database URL: ${database?.substring(0, 20)}...');

    print('📝 Usage in real app:');
    print('```dart');
    print('// In your widget tree:');
    print('ChangeNotifierProvider(');
    print('  create: (_) => manager,');
    print('  child: MyApp(),');
    print(')');
    print('');
    print('// In your widgets:');
    print('Consumer<SecretManagerProvider>(');
    print('  builder: (context, secrets, child) {');
    print('    final jwt = secrets.getStaticValue<String>("jwtSecret");');
    print('    return Text("JWT: \${jwt?.substring(0, 10)}...");');
    print('  },');
    print(')');
    print('```');

    manager.dispose();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates Riverpod integration.
Future<void> demonstrateRiverpodIntegration() async {
  print('🎣 Riverpod Integration');
  print('=' * 40);

  // Create static providers
  final apiKeySecret = 'riverpod-api-key-123'.obfuscate(
    algorithm: 'aes-256-gcm',
  );
  final apiKeyProvider = ConfidentialRiverpodFactory.createStatic(
    apiKeySecret,
    name: 'apiKeyProvider',
  );

  final configSecret = {
    'timeout': 30000,
    'retries': 3,
    'baseUrl': 'https://api.example.com',
  }.obfuscate(algorithm: 'aes-256-gcm');
  final configProvider = ConfidentialRiverpodFactory.createStatic(
    configSecret,
    name: 'configProvider',
  );

  // Create secret manager
  final managerProvider = ConfidentialRiverpodFactory.createManager(
    name: 'secretManager',
  );

  print('✅ Riverpod providers created:');
  print('  - API key provider (static)');
  print('  - Configuration provider (static)');
  print('  - Secret manager provider');

  // Access values
  final apiKey = apiKeySecret.value;
  final config = configSecret.value;

  print('📊 Provider values:');
  print('  - API Key: ${apiKey.substring(0, 10)}...');
  print('  - Config timeout: ${config['timeout']}ms');
  print('  - Config retries: ${config['retries']}');

  print('📝 Usage in real app:');
  print('```dart');
  print('// Define providers');
  print('final apiKeyProvider = ConfidentialRiverpodFactory.createStatic(');
  print('  apiKeySecret, name: "apiKey");');
  print('');
  print('// In your widgets:');
  print('Consumer(builder: (context, ref, child) {');
  print('  final apiKey = ref.watch(apiKeyProvider);');
  print('  return Text("API Key: \${apiKey.substring(0, 10)}...");');
  print('});');
  print('');
  print('// For async providers:');
  print('Consumer(builder: (context, ref, child) {');
  print('  final asyncValue = ref.watch(asyncSecretProvider);');
  print('  return asyncValue.when(');
  print('    data: (secret) => Text("Secret: \$secret"),');
  print('    loading: () => CircularProgressIndicator(),');
  print('    error: (err, stack) => Text("Error: \$err"),');
  print('  );');
  print('});');
  print('```');

  print('\n');
}

/// Demonstrates GetIt service locator integration.
Future<void> demonstrateGetItIntegration() async {
  print('🔧 GetIt Service Locator Integration');
  print('=' * 40);

  // Create mock GetIt instance (in real usage, you'd use GetIt.instance)
  final getIt = _MockGetIt();

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('getit_example');
  final secretProvider = FileSecretProvider(basePath: tempDir.path);

  await secretProvider.saveSecret(
    'serviceKey',
    'service-secret-key-456'.encrypt(algorithm: 'aes-256-gcm', nonce: 44444),
  );

  try {
    // Setup GetIt with confidential secrets
    final service = await ConfidentialGetItFactory.setupWithProvider(
      getIt: getIt,
      secretProvider: secretProvider,
      secretNames: {'serviceKey': 'aes-256-gcm'},
    );

    // Register additional static secrets
    final cacheKey = 'cache-encryption-key'.obfuscate(algorithm: 'aes-256-gcm');
    service.registerStatic('cacheKey', cacheKey);

    print('✅ GetIt configured with:');
    print('  - Service key (async from provider)');
    print('  - Cache key (static)');
    print('  - Total registered secrets: ${service.registeredCount}');

    // Wait for async secrets to load
    await Future.delayed(const Duration(milliseconds: 500));

    // Access secrets
    final serviceKey = await service.getAsyncValue<String>('serviceKey');
    final cache = service.getStatic<String>('cacheKey');

    print('📊 Retrieved secrets:');
    print('  - Service Key: ${serviceKey.substring(0, 10)}...');
    print('  - Cache Key: ${cache.substring(0, 10)}...');

    print('📝 Usage in real app:');
    print('```dart');
    print('// Setup during app initialization');
    print('await ConfidentialGetItFactory.setupWithProvider(');
    print('  getIt: GetIt.instance,');
    print('  secretProvider: yourSecretProvider,');
    print('  secretNames: {"apiKey": "aes-256-gcm"},');
    print(');');
    print('');
    print('// Access anywhere in your app');
    print(
      'final apiKey = await GetIt.instance.getAsyncObfuscated<String>("apiKey");',
    );
    print(
      'final staticSecret = GetIt.instance.getObfuscated<String>("staticSecret");',
    );
    print('```');

    service.dispose();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates BLoC state management integration.
Future<void> demonstrateBlocIntegration() async {
  print('🏗️  BLoC State Management Integration');
  print('=' * 40);

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('bloc_example');
  final secretProvider = FileSecretProvider(basePath: tempDir.path);

  await secretProvider.saveSecret(
    'userToken',
    'user-auth-token-789'.encrypt(algorithm: 'aes-256-gcm', nonce: 55555),
  );

  try {
    // Create BLoC with secrets
    final bloc = await ConfidentialBlocFactory.createBlocWithProvider(
      secretProvider: secretProvider,
      secretNames: {'userToken': 'aes-256-gcm'},
    );

    // Add static secrets
    final sessionKey = 'session-key-abc123'.obfuscate(algorithm: 'aes-256-gcm');
    bloc.addStaticSecret('sessionKey', sessionKey);

    print('✅ BLoC configured with:');
    print('  - User token (async from provider)');
    print('  - Session key (static)');

    // Load async secrets
    bloc.add(LoadSecretEvent('userToken'));

    // Wait for loading
    await Future.delayed(const Duration(milliseconds: 500));

    print('📊 BLoC state:');
    print('  - Loaded secrets: ${bloc.loadedSecretCount}');
    print('  - Secret names: ${bloc.loadedSecretNames.join(', ')}');
    print(
      '  - Session key: ${bloc.getSecret<String>('sessionKey')?.substring(0, 10)}...',
    );
    print(
      '  - User token: ${bloc.getSecret<String>('userToken')?.substring(0, 10)}...',
    );

    // Create individual secret cubit
    final apiTokenSecret = AsyncObfuscatedString(
      secretName: 'userToken',
      provider: secretProvider,
      algorithm: 'aes-256-gcm',
    );
    final cubit = SecretCubit.async('userToken', apiTokenSecret);

    // Wait for cubit to load
    await Future.delayed(const Duration(milliseconds: 500));

    print('📊 Cubit state:');
    print('  - Is loaded: ${cubit.isLoaded}');
    print('  - Value: ${cubit.value?.substring(0, 10)}...');

    print('📝 Usage in real app:');
    print('```dart');
    print('// Create BLoC');
    print('final secretBloc = ConfidentialBlocFactory.createBloc();');
    print('');
    print('// In your widget:');
    print('BlocBuilder<SecretBloc, SecretState>(');
    print('  builder: (context, state) {');
    print('    if (state is SecretLoadedState<String>) {');
    print('      return Text("Secret: \${state.value}");');
    print('    } else if (state is SecretLoadingState) {');
    print('      return CircularProgressIndicator();');
    print('    } else if (state is SecretErrorState) {');
    print('      return Text("Error: \${state.error}");');
    print('    }');
    print('    return Text("No secret loaded");');
    print('  },');
    print(')');
    print('```');

    await bloc.close();
    await cubit.close();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates GetX state management integration.
Future<void> demonstrateGetXIntegration() async {
  print('🎯 GetX State Management Integration');
  print('=' * 40);

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('getx_example');
  final secretProvider = FileSecretProvider(basePath: tempDir.path);

  await secretProvider.saveSecret(
    'authToken',
    'getx-auth-token-123'.encrypt(algorithm: 'aes-256-gcm', nonce: 77777),
  );

  try {
    // Create GetX service with secrets
    final service = await ConfidentialGetXFactory.createServiceWithProvider(
      secretProvider: secretProvider,
      secretNames: {'authToken': 'aes-256-gcm'},
    );

    // Add static secrets
    final sessionKey = 'getx-session-key'.obfuscate(algorithm: 'aes-256-gcm');
    service.addStaticSecret('sessionKey', sessionKey);

    print('✅ GetX service configured with:');
    print('  - Auth token (async from provider)');
    print('  - Session key (static)');

    // Wait for async secrets to load
    await Future.delayed(const Duration(milliseconds: 500));

    print('📊 GetX service state:');
    print('  - Controllers: ${service.controllerCount}');
    print(
      '  - Session key: ${service.getStatic<String>('sessionKey')?.substring(0, 10)}...',
    );
    print(
      '  - Auth token: ${service.getAsync<String>('authToken')?.substring(0, 10)}...',
    );

    // Create individual controller
    final controller = ConfidentialGetXFactory.createController();
    controller.onInit();

    // Add secrets to controller
    final apiSecret = 'controller-api-secret'.obfuscate(
      algorithm: 'aes-256-gcm',
    );
    controller.addStaticSecret('apiSecret', apiSecret);

    print('📊 Controller state:');
    print('  - Secret count: ${controller.secretCount}');
    print(
      '  - API secret: ${controller.getStatic<String>('apiSecret')?.substring(0, 10)}...',
    );

    // Test reactive values
    final rx = controller.getRx<String>('apiSecret');
    if (rx != null) {
      print('  - Reactive value: ${rx.value.substring(0, 10)}...');

      // Listen to changes
      var changeCount = 0;
      final subscription = rx.listen((value) {
        changeCount++;
        print('  - Value changed: $changeCount times');
      });

      // Trigger a change (in real usage, this would happen automatically)
      rx.value = 'new-api-secret-value';

      await Future.delayed(const Duration(milliseconds: 100));
      subscription.cancel();
    }

    // Test computed reactive value
    final computed = controller.computed<String>(() {
      final api = controller.getStatic<String>('apiSecret') ?? '';
      return 'computed-${api.substring(0, 5)}';
    });

    print('  - Computed value: ${computed.value}');

    print('📝 Usage in real app:');
    print('```dart');
    print('// Create GetX service');
    print('final secretService = ConfidentialGetXFactory.createService();');
    print('');
    print('// In your GetX controller:');
    print('class MyController extends GetxController {');
    print('  final secretService = Get.find<SecretService>();');
    print('  ');
    print('  @override');
    print('  void onInit() {');
    print('    super.onInit();');
    print('    // Access secrets reactively');
    print('    final apiKey = secretService.getRx<String>("apiKey");');
    print('    apiKey?.listen((value) => print("API key updated: \$value"));');
    print('  }');
    print('}');
    print('');
    print('// In your widgets:');
    print('Obx(() {');
    print('  final apiKey = secretService.getStatic<String>("apiKey");');
    print('  return Text("API Key: \${apiKey?.substring(0, 10)}...");');
    print('});');
    print('```');

    controller.onClose();
    service.onClose();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n');
}

/// Demonstrates the unified integration manager.
Future<void> demonstrateIntegrationManager() async {
  print('🎛️  Unified Integration Manager');
  print('=' * 40);

  // Create secret provider
  final tempDir = await Directory.systemTemp.createTemp('manager_example');
  final secretProvider = FileSecretProvider(basePath: tempDir.path);

  await secretProvider.saveSecret(
    'masterKey',
    'master-encryption-key-xyz'.encrypt(algorithm: 'aes-256-gcm', nonce: 66666),
  );

  try {
    // Create integration manager with all features enabled
    final manager = ConfidentialIntegrationFactory.createFullIntegration(
      defaultRefreshInterval: const Duration(minutes: 1),
      autoRefresh: true,
    );

    // Initialize with secret provider
    await manager.initialize(
      secretProvider: secretProvider,
      secretNames: {'masterKey': 'aes-256-gcm'},
    );

    // Add additional static secrets
    final appSecret = 'app-secret-key-123'.obfuscate(algorithm: 'aes-256-gcm');
    manager.addStaticSecret('appSecret', appSecret);

    print('✅ Integration manager initialized with:');
    print('  - Provider integration: ${manager.providerManager != null}');
    print('  - Riverpod integration: ${manager.riverpodManager != null}');
    print('  - BLoC integration: ${manager.secretBloc != null}');
    print('  - GetX integration: ${manager.getXService != null}');
    print('  - Total secrets: ${manager.secretCount}');

    // Wait for async secrets to load
    await Future.delayed(const Duration(milliseconds: 500));

    print('📊 Manager status:');
    print('  - Initialized: ${manager.isInitialized}');
    print('  - Secret names: ${manager.secretNames.join(', ')}');

    if (manager.providerManager != null) {
      print('  - Provider secrets: ${manager.providerManager!.providerCount}');
    }

    if (manager.secretBloc != null) {
      print(
        '  - BLoC loaded secrets: ${manager.secretBloc!.loadedSecretCount}',
      );
    }

    if (manager.getXService != null) {
      print(
        '  - GetX service controllers: ${manager.getXService!.controllerCount}',
      );
    }

    // Refresh all secrets
    print('\n🔄 Refreshing all secrets...');
    await manager.refreshAllSecrets();
    print('✅ All secrets refreshed successfully');

    print('📝 Usage in real app:');
    print('```dart');
    print('// Create and initialize manager');
    print(
      'final manager = ConfidentialIntegrationFactory.createFullIntegration();',
    );
    print('await manager.initialize(');
    print('  secretProvider: yourProvider,');
    print('  secretNames: {"apiKey": "aes-256-gcm"},');
    print(');');
    print('');
    print('// Access different integrations');
    print('final providerManager = manager.providerManager;');
    print('final secretBloc = manager.secretBloc;');
    print('final dioInterceptor = manager.dioInterceptor;');
    print('');
    print('// Add secrets to all integrations at once');
    print('manager.addStaticSecret("newSecret", obfuscatedValue);');
    print('```');

    await manager.dispose();
  } finally {
    await tempDir.delete(recursive: true);
  }

  print('\n✅ All integration examples completed successfully!');
}

// Mock GetIt implementation for demonstration
class _MockGetIt implements GetItLike {
  final Map<Type, dynamic> _instances = {};
  final Map<String, dynamic> _namedInstances = {};

  @override
  void registerSingleton<T>(T instance, {String? instanceName}) {
    if (instanceName != null) {
      _namedInstances[instanceName] = instance;
    } else {
      _instances[T] = instance;
    }
  }

  @override
  void registerLazySingleton<T>(
    T Function() factoryFunc, {
    String? instanceName,
    void Function(T)? dispose,
  }) {
    registerSingleton<T>(factoryFunc(), instanceName: instanceName);
  }

  @override
  void registerFactory<T>(T Function() factoryFunc, {String? instanceName}) {
    registerSingleton<T>(factoryFunc(), instanceName: instanceName);
  }

  @override
  T get<T>({String? instanceName}) {
    if (instanceName != null) {
      return _namedInstances[instanceName] as T;
    }
    return _instances[T] as T;
  }

  @override
  bool isRegistered<T>({String? instanceName}) {
    if (instanceName != null) {
      return _namedInstances.containsKey(instanceName);
    }
    return _instances.containsKey(T);
  }

  @override
  Future<void> unregister<T>({String? instanceName}) async {
    if (instanceName != null) {
      _namedInstances.remove(instanceName);
    } else {
      _instances.remove(T);
    }
  }

  @override
  Future<void> reset() async {
    _instances.clear();
    _namedInstances.clear();
  }
}
