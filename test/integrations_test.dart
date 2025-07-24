import 'dart:async';
import 'dart:io';

import 'package:confidential/confidential.dart';
import 'package:confidential/src/integrations/provider_integration.dart'
    as provider_integration;
import 'package:test/test.dart';

void main() {
  group('Package Integrations Tests', () {
    late Directory tempDir;
    late FileSecretProvider secretProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'confidential_integrations_test',
      );
      secretProvider = FileSecretProvider(basePath: tempDir.path);

      // Save test secrets
      await secretProvider.saveSecret(
        'apiKey',
        'test-api-key-123'.encrypt(algorithm: 'aes-256-gcm', nonce: 11111),
      );
      await secretProvider.saveSecret(
        'dbPassword',
        'super-secret-password'.encrypt(algorithm: 'aes-256-gcm', nonce: 22222),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('Dio Integration', () {
      test('ConfidentialDioInterceptor basic functionality', () async {
        final interceptor = ConfidentialDioInterceptor();

        // Add static token
        final staticToken = 'static-token-123'.obfuscate(
          algorithm: 'aes-256-gcm',
        );
        interceptor.addStaticToken('auth', staticToken);

        // Add async token
        final asyncToken = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        interceptor.addAsyncToken('api-key', asyncToken);

        // Add dynamic token
        interceptor.addDynamicToken(
          'session',
          () => 'dynamic-session-${DateTime.now().millisecondsSinceEpoch}',
        );

        // Mock request options
        final mockOptions = _MockRequestOptions();
        final mockHandler = _MockRequestHandler();

        // Test token injection
        await interceptor.onRequest(mockOptions, mockHandler);

        expect(
          mockOptions.headers['Authorization'],
          startsWith('Bearer static-token-123'),
        );
        expect(mockOptions.headers['api-key'], equals('test-api-key-123'));
        expect(mockOptions.headers['session'], startsWith('dynamic-session-'));
        expect(mockHandler.nextCalled, isTrue);
      });

      test('DioIntegrationConfig customization', () {
        final config = DioIntegrationConfig(
          authHeaderName: 'X-Auth-Token',
          tokenPrefix: 'Token ',
          enableLogging: true,
          customHeaders: {'X-Client-Version': '1.0.0'},
        );

        final interceptor = ConfidentialDioInterceptor(config: config);
        final staticToken = 'custom-token'.obfuscate(algorithm: 'aes-256-gcm');
        interceptor.addStaticToken('auth', staticToken);

        final mockOptions = _MockRequestOptions();
        final mockHandler = _MockRequestHandler();

        interceptor.onRequest(mockOptions, mockHandler);

        expect(
          mockOptions.headers['X-Auth-Token'],
          equals('Token custom-token'),
        );
        expect(mockOptions.headers['X-Client-Version'], equals('1.0.0'));
      });
    });

    group('Provider Integration', () {
      test('ObfuscatedValueProvider functionality', () {
        final obfuscated = 'test-value'.obfuscate(algorithm: 'aes-256-gcm');
        final provider = ObfuscatedValueProvider(obfuscated);

        expect(provider.value, equals('test-value'));
        expect(provider.hasListeners, isFalse);

        var notified = false;
        provider.addListener(() => notified = true);
        expect(provider.hasListeners, isTrue);

        provider.notifyListeners();
        expect(notified, isTrue);

        provider.dispose();
        expect(provider.isDisposed, isTrue);
      });

      test('AsyncObfuscatedValueProvider functionality', () async {
        final asyncObfuscated = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );

        final provider = provider_integration.AsyncObfuscatedValueProvider(
          asyncObfuscated,
          refreshInterval: const Duration(seconds: 1),
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 500));

        expect(provider.hasValue, isTrue);
        expect(provider.value, equals('test-api-key-123'));
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);

        final valueAsync = await provider.getValueAsync();
        expect(valueAsync, equals('test-api-key-123'));

        final valueOrDefault = provider.getValueOrDefault('default');
        expect(valueOrDefault, equals('test-api-key-123'));

        provider.dispose();
        expect(provider.isDisposed, isTrue);
      });

      test('SecretManagerProvider functionality', () async {
        final manager = SecretManagerProvider();

        // Add static secret
        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        manager.addStatic('static', staticSecret);

        // Add async secret
        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        manager.addAsync('async', asyncSecret);

        expect(manager.providerCount, equals(2));
        expect(manager.providerNames, containsAll(['static', 'async']));

        expect(
          manager.getStaticValue<String>('static'),
          equals('static-value'),
        );

        // Wait for async value to load
        await Future.delayed(const Duration(milliseconds: 500));
        final asyncValue = await manager.getAsyncValueAsync<String>('async');
        expect(asyncValue, equals('test-api-key-123'));

        manager.dispose();
        expect(manager.isDisposed, isTrue);
      });
    });

    group('Riverpod Integration', () {
      test('ObfuscatedValueProvider creation', () {
        final obfuscated = 'riverpod-value'.obfuscate(algorithm: 'aes-256-gcm');
        final provider = ConfidentialRiverpodFactory.createStatic(
          obfuscated,
          name: 'testProvider',
        );

        expect(provider.name, equals('testProvider'));
        expect(provider.obfuscatedValue.value, equals('riverpod-value'));
      });

      test('AsyncObfuscatedValueProvider creation', () {
        final asyncObfuscated = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );

        final provider = ConfidentialRiverpodFactory.createAsync(
          asyncObfuscated,
          name: 'asyncProvider',
        );

        expect(provider.name, equals('asyncProvider'));
        expect(provider.asyncObfuscatedValue, equals(asyncObfuscated));
      });

      test('RiverpodSecretManager functionality', () {
        final manager = RiverpodSecretManager();

        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        manager.addStatic('static', staticSecret);

        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        manager.addAsync('async', asyncSecret);

        expect(manager.providerCount, equals(2));
        expect(manager.providerNames, containsAll(['static', 'async']));

        final staticProvider = manager.getStatic<String>('static');
        expect(staticProvider, isNotNull);

        final asyncProvider = manager.getAsync<String>('async');
        expect(asyncProvider, isNotNull);

        manager.dispose();
        expect(manager.isDisposed, isTrue);
      });
    });

    group('GetIt Integration', () {
      test('ConfidentialGetItService functionality', () async {
        final mockGetIt = _MockGetIt();
        final service = ConfidentialGetItService(mockGetIt);

        // Register static secret
        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        service.registerStatic('static', staticSecret);

        expect(service.isRegistered('static'), isTrue);
        expect(service.registeredCount, equals(1));

        // Register async secret
        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        service.registerAsync('async', asyncSecret);

        expect(service.registeredCount, equals(2));
        expect(service.registeredNames, containsAll(['static', 'async']));

        // Test getting values
        expect(service.getStatic<String>('static'), equals('static-value'));

        // Wait for async value to load
        await Future.delayed(const Duration(milliseconds: 500));
        final asyncValue = await service.getAsyncValue<String>('async');
        expect(asyncValue, equals('test-api-key-123'));

        service.dispose();
      });

      test('GetIt extension methods', () {
        final mockGetIt = _MockGetIt();
        final service = mockGetIt.addConfidentialSecrets();

        expect(service, isA<ConfidentialGetItService>());
        expect(mockGetIt.registeredTypes, contains(ConfidentialGetItService));
      });
    });

    group('BLoC Integration', () {
      test('SecretBloc functionality', () async {
        final bloc = SecretBloc();

        // Add static secret
        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        bloc.addStaticSecret('static', staticSecret);

        expect(bloc.getSecret<String>('static'), equals('static-value'));
        expect(bloc.isSecretLoaded('static'), isTrue);

        // Add async secret
        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        bloc.addAsyncSecret('async', asyncSecret);

        // Load async secret
        bloc.add(LoadSecretEvent('async'));

        // Wait for loading
        await Future.delayed(const Duration(milliseconds: 500));

        expect(bloc.isSecretLoaded('async'), isTrue);
        expect(bloc.getSecret<String>('async'), equals('test-api-key-123'));

        expect(bloc.loadedSecretCount, equals(2));
        expect(bloc.loadedSecretNames, containsAll(['static', 'async']));

        await bloc.close();
        expect(bloc.isClosed, isTrue);
      });

      test('SecretCubit functionality', () async {
        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );

        final cubit = SecretCubit.async('apiKey', asyncSecret);

        // Wait for loading
        await Future.delayed(const Duration(milliseconds: 500));

        expect(cubit.isLoaded, isTrue);
        expect(cubit.value, equals('test-api-key-123'));
        expect(cubit.getValueOrDefault('default'), equals('test-api-key-123'));

        await cubit.close();
        expect(cubit.isClosed, isTrue);
      });
    });

    group('GetX Integration', () {
      test('SecretController functionality', () async {
        final controller = SecretController();
        controller.onInit();

        // Add static secret
        final staticSecret = 'static-value'.obfuscate(algorithm: 'aes-256-gcm');
        controller.addStaticSecret('static', staticSecret);

        expect(controller.getStatic<String>('static'), equals('static-value'));
        expect(controller.secretCount, equals(1));

        // Add async secret
        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        controller.addAsyncSecret('async', asyncSecret);

        expect(controller.secretCount, equals(2));
        expect(controller.secretNames, containsAll(['static', 'async']));

        // Wait for async value to load
        await Future.delayed(const Duration(milliseconds: 500));
        expect(
          controller.getAsync<String>('async'),
          equals('test-api-key-123'),
        );

        // Test reactive values
        final rx = controller.getRx<String>('static');
        expect(rx, isNotNull);
        expect(rx!.value, equals('static-value'));

        // Test refresh
        await controller.refreshSecret('async');

        controller.onClose();
        expect(controller.isClosed, isTrue);
      });

      test('SecretService functionality', () async {
        final service = SecretService();
        service.onInit();
        service.onReady();

        // Add secrets to default controller
        final staticSecret = 'service-static'.obfuscate(
          algorithm: 'aes-256-gcm',
        );
        service.addStaticSecret('static', staticSecret);

        final asyncSecret = AsyncObfuscatedString(
          secretName: 'apiKey',
          provider: secretProvider,
          algorithm: 'aes-256-gcm',
        );
        service.addAsyncSecret('async', asyncSecret);

        expect(service.getStatic<String>('static'), equals('service-static'));

        // Wait for async value to load
        await Future.delayed(const Duration(milliseconds: 500));
        expect(service.getAsync<String>('async'), equals('test-api-key-123'));

        // Test multiple controllers
        final customController = service.controller('custom');
        expect(service.controllerCount, equals(2)); // default + custom

        service.onClose();
        expect(service.isClosed, isTrue);
      });

      test('GetX extension methods', () async {
        final controller = SecretController();
        controller.onInit();

        final staticSecret = 'extension-test'.obfuscate(
          algorithm: 'aes-256-gcm',
        );
        controller.addStaticSecret('test', staticSecret);

        // Test bind secret
        final rx = controller.bindSecret<String>('test');
        expect(rx.value, equals('extension-test'));

        // Test worker
        var workerCalled = false;
        final subscription = controller.worker<String>('test', (value) {
          workerCalled = true;
        });

        // Trigger change
        rx.value = 'new-value';

        // Wait for the worker to be called
        await Future.delayed(const Duration(milliseconds: 100));
        expect(workerCalled, isTrue);

        subscription.cancel();
        controller.onClose();
      });

      test('GetX factory methods', () async {
        final controller = ConfidentialGetXFactory.createController();
        expect(controller, isA<SecretController>());

        final service = ConfidentialGetXFactory.createService();
        expect(service, isA<SecretService>());

        final controllerWithProvider =
            await ConfidentialGetXFactory.createControllerWithProvider(
              secretProvider: secretProvider,
              secretNames: {'apiKey': 'aes-256-gcm'},
            );

        expect(controllerWithProvider.isInitialized, isTrue);
        expect(controllerWithProvider.secretCount, equals(1));

        controllerWithProvider.onClose();
      });
    });

    group('Integration Manager', () {
      test('ConfidentialIntegrationManager functionality', () async {
        final manager = ConfidentialIntegrationManager(
          config: const IntegrationConfig(
            enableProvider: true,
            enableBloc: true,
            enableGetX: true,
          ),
        );

        await manager.initialize(
          secretProvider: secretProvider,
          secretNames: {'apiKey': 'aes-256-gcm', 'dbPassword': 'aes-256-gcm'},
        );

        expect(manager.isInitialized, isTrue);
        expect(manager.secretCount, equals(2));
        expect(manager.secretNames, containsAll(['apiKey', 'dbPassword']));

        // Add static secret
        final staticSecret = 'new-static'.obfuscate(algorithm: 'aes-256-gcm');
        manager.addStaticSecret('newStatic', staticSecret);

        expect(manager.secretCount, equals(3));

        // Test provider manager
        expect(manager.providerManager, isNotNull);
        expect(manager.providerManager!.providerCount, equals(3));

        // Test BLoC
        expect(manager.secretBloc, isNotNull);
        expect(manager.secretBloc!.loadedSecretCount, greaterThan(0));

        // Test GetX
        expect(manager.getXService, isNotNull);
        expect(manager.getXService!.secrets.secretCount, greaterThan(0));

        await manager.dispose();
      });

      test('Integration factory methods', () {
        final fullManager =
            ConfidentialIntegrationFactory.createFullIntegration();
        expect(fullManager.config.enableDio, isTrue);
        expect(fullManager.config.enableProvider, isTrue);
        expect(fullManager.config.enableRiverpod, isTrue);
        expect(fullManager.config.enableGetIt, isTrue);
        expect(fullManager.config.enableBloc, isTrue);
        expect(fullManager.config.enableGetX, isTrue);

        final httpManager =
            ConfidentialIntegrationFactory.createHttpIntegration();
        expect(httpManager.config.enableDio, isTrue);
        expect(httpManager.config.enableProvider, isFalse);

        final diManager = ConfidentialIntegrationFactory.createDIIntegration();
        expect(diManager.config.enableProvider, isTrue);
        expect(diManager.config.enableRiverpod, isTrue);
        expect(diManager.config.enableGetIt, isTrue);
        expect(diManager.config.enableDio, isFalse);

        final stateManager =
            ConfidentialIntegrationFactory.createStateManagementIntegration();
        expect(stateManager.config.enableBloc, isTrue);
        expect(stateManager.config.enableProvider, isTrue);
        expect(stateManager.config.enableRiverpod, isTrue);
        expect(stateManager.config.enableGetX, isTrue);
      });
    });
  });
}

// Mock implementations for testing

class _MockRequestOptions implements RequestOptionsLike {
  @override
  Map<String, dynamic> headers = {};

  @override
  String get path => '/test';

  @override
  String get method => 'GET';
}

class _MockRequestHandler implements RequestInterceptorHandlerLike {
  bool nextCalled = false;
  bool resolveCalled = false;
  bool rejectCalled = false;

  @override
  void next(RequestOptionsLike options) {
    nextCalled = true;
  }

  @override
  void resolve(ResponseLike response) {
    resolveCalled = true;
  }

  @override
  void reject(DioErrorLike error) {
    rejectCalled = true;
  }
}

class _MockGetIt implements GetItLike {
  final Map<Type, dynamic> _instances = {};
  final Map<String, Type> _namedInstances = {};
  final Set<Type> registeredTypes = {};

  @override
  void registerSingleton<T>(T instance, {String? instanceName}) {
    if (instanceName != null) {
      _namedInstances[instanceName] = T;
    }
    _instances[T] = instance;
    registeredTypes.add(T);
  }

  @override
  void registerLazySingleton<T>(
    T Function() factoryFunc, {
    String? instanceName,
    void Function(T)? dispose,
  }) {
    // For testing, we'll just call the factory immediately
    final instance = factoryFunc();
    registerSingleton<T>(instance, instanceName: instanceName);
  }

  @override
  void registerFactory<T>(T Function() factoryFunc, {String? instanceName}) {
    // For testing, we'll just call the factory immediately
    final instance = factoryFunc();
    registerSingleton<T>(instance, instanceName: instanceName);
  }

  @override
  T get<T>({String? instanceName}) {
    if (instanceName != null) {
      final type = _namedInstances[instanceName];
      if (type != null) {
        return _instances[type] as T;
      }
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
    }
    _instances.remove(T);
    registeredTypes.remove(T);
  }

  @override
  Future<void> reset() async {
    _instances.clear();
    _namedInstances.clear();
    registeredTypes.clear();
  }
}
