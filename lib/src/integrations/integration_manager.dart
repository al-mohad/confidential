/// Integration manager for coordinating multiple package integrations.
///
/// This module provides a unified interface for managing integrations
/// with popular packages like Dio, Provider, Riverpod, GetIt, and BLoC.
library;

import 'dart:async';

import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';
import '../obfuscation/secret.dart';
import 'bloc_integration.dart';
import 'dio_integration.dart';
import 'get_it_integration.dart';
import 'getx_integration.dart';
import 'provider_integration.dart';
import 'riverpod_integration.dart';

/// Configuration for integration manager.
class IntegrationConfig {
  /// Whether to enable Dio integration.
  final bool enableDio;

  /// Whether to enable Provider integration.
  final bool enableProvider;

  /// Whether to enable Riverpod integration.
  final bool enableRiverpod;

  /// Whether to enable GetIt integration.
  final bool enableGetIt;

  /// Whether to enable BLoC integration.
  final bool enableBloc;

  /// Whether to enable GetX integration.
  final bool enableGetX;

  /// Dio integration configuration.
  final DioIntegrationConfig? dioConfig;

  /// GetIt integration configuration.
  final GetItIntegrationConfig? getItConfig;

  /// Default refresh interval for async secrets.
  final Duration defaultRefreshInterval;

  /// Whether to auto-refresh async secrets.
  final bool autoRefresh;

  const IntegrationConfig({
    this.enableDio = false,
    this.enableProvider = false,
    this.enableRiverpod = false,
    this.enableGetIt = false,
    this.enableBloc = false,
    this.enableGetX = false,
    this.dioConfig,
    this.getItConfig,
    this.defaultRefreshInterval = const Duration(minutes: 5),
    this.autoRefresh = true,
  });

  /// Creates a configuration with all integrations enabled.
  factory IntegrationConfig.all({
    DioIntegrationConfig? dioConfig,
    GetItIntegrationConfig? getItConfig,
    Duration defaultRefreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    return IntegrationConfig(
      enableDio: true,
      enableProvider: true,
      enableRiverpod: true,
      enableGetIt: true,
      enableBloc: true,
      enableGetX: true,
      dioConfig: dioConfig,
      getItConfig: getItConfig,
      defaultRefreshInterval: defaultRefreshInterval,
      autoRefresh: autoRefresh,
    );
  }
}

/// Unified integration manager for all supported packages.
class ConfidentialIntegrationManager {
  final IntegrationConfig config;
  final Map<String, ObfuscatedValue> _staticSecrets = {};
  final Map<String, AsyncObfuscatedValue> _asyncSecrets = {};

  // Integration instances
  ConfidentialDioInterceptor? _dioInterceptor;
  SecretManagerProvider? _providerManager;
  RiverpodSecretManager? _riverpodManager;
  ConfidentialGetItService? _getItService;
  SecretBloc? _secretBloc;
  SecretService? _getXService;

  bool _initialized = false;

  ConfidentialIntegrationManager({this.config = const IntegrationConfig()});

  /// Initializes all enabled integrations.
  Future<void> initialize({
    DioLike? dioInstance,
    GetItLike? getItInstance,
    SecretProvider? secretProvider,
    Map<String, String>? secretNames, // name -> algorithm
  }) async {
    if (_initialized) return;

    // Initialize Dio integration
    if (config.enableDio && dioInstance != null) {
      _dioInterceptor = dioInstance.addConfidentialTokens(
        config: config.dioConfig ?? const DioIntegrationConfig(),
      );
    }

    // Initialize Provider integration
    if (config.enableProvider) {
      _providerManager = ConfidentialProviderFactory.createManager();
    }

    // Initialize Riverpod integration
    if (config.enableRiverpod) {
      _riverpodManager = RiverpodSecretManager();
    }

    // Initialize GetIt integration
    if (config.enableGetIt && getItInstance != null) {
      _getItService = ConfidentialGetItService(
        getItInstance,
        config: config.getItConfig ?? const GetItIntegrationConfig(),
      );
    }

    // Initialize BLoC integration
    if (config.enableBloc) {
      _secretBloc = SecretBloc();
    }

    // Initialize GetX integration
    if (config.enableGetX) {
      _getXService = SecretService();
      _getXService!.onInit();
      _getXService!.onReady();
    }

    // Load secrets from provider if provided
    if (secretProvider != null && secretNames != null) {
      await _loadSecretsFromProvider(secretProvider, secretNames);
    }

    _initialized = true;
  }

  /// Adds a static obfuscated secret to all enabled integrations.
  void addStaticSecret<T>(String name, ObfuscatedValue<T> secret) {
    _staticSecrets[name] = secret;

    // Add to Dio
    if (_dioInterceptor != null) {
      if (T == String) {
        _dioInterceptor!.addStaticToken(
          name,
          secret as ObfuscatedValue<String>,
        );
      }
    }

    // Add to Provider
    if (_providerManager != null) {
      _providerManager!.addStatic(name, secret);
    }

    // Add to Riverpod
    if (_riverpodManager != null) {
      _riverpodManager!.addStatic(name, secret);
    }

    // Add to GetIt
    if (_getItService != null) {
      _getItService!.registerStatic(name, secret);
    }

    // Add to BLoC
    if (_secretBloc != null) {
      _secretBloc!.addStaticSecret(name, secret);
    }

    // Add to GetX
    if (_getXService != null) {
      _getXService!.addStaticSecret(name, secret);
    }
  }

  /// Adds an async obfuscated secret to all enabled integrations.
  void addAsyncSecret<T>(String name, AsyncObfuscatedValue<T> secret) {
    _asyncSecrets[name] = secret;

    // Add to Dio
    if (_dioInterceptor != null) {
      if (T == String) {
        _dioInterceptor!.addAsyncToken(
          name,
          secret as AsyncObfuscatedValue<String>,
        );
      }
    }

    // Add to Provider
    if (_providerManager != null) {
      _providerManager!.addAsync(
        name,
        secret,
        refreshInterval: config.defaultRefreshInterval,
        autoRefresh: config.autoRefresh,
      );
    }

    // Add to Riverpod
    if (_riverpodManager != null) {
      _riverpodManager!.addAsync(
        name,
        secret,
        refreshInterval: config.defaultRefreshInterval,
      );
    }

    // Add to GetIt
    if (_getItService != null) {
      _getItService!.registerAsync(
        name,
        secret,
        refreshInterval: config.defaultRefreshInterval,
        autoRefresh: config.autoRefresh,
      );
    }

    // Add to BLoC
    if (_secretBloc != null) {
      _secretBloc!.addAsyncSecret(name, secret);
    }

    // Add to GetX
    if (_getXService != null) {
      _getXService!.addAsyncSecret(
        name,
        secret,
        refreshInterval: config.defaultRefreshInterval,
        autoRefresh: config.autoRefresh,
      );
    }
  }

  /// Removes a secret from all integrations.
  void removeSecret(String name) {
    _staticSecrets.remove(name);
    _asyncSecrets.remove(name);

    // Remove from Dio
    if (_dioInterceptor != null) {
      _dioInterceptor!.removeToken(name);
    }

    // Remove from Provider
    if (_providerManager != null) {
      _providerManager!.remove(name);
    }

    // Remove from Riverpod
    if (_riverpodManager != null) {
      _riverpodManager!.remove(name);
    }

    // Remove from GetIt
    if (_getItService != null) {
      _getItService!.unregister(name);
    }

    // BLoC doesn't support removal, but we can clear the loaded value
  }

  /// Refreshes all async secrets across all integrations.
  Future<void> refreshAllSecrets() async {
    final futures = <Future>[];

    // Refresh Provider secrets
    if (_providerManager != null) {
      futures.add(_providerManager!.refreshAll());
    }

    // Refresh GetIt secrets
    if (_getItService != null) {
      futures.add(_getItService!.refreshAll());
    }

    // Refresh BLoC secrets
    if (_secretBloc != null) {
      _secretBloc!.add(RefreshAllSecretsEvent());
    }

    // Refresh GetX secrets
    if (_getXService != null) {
      futures.add(_getXService!.refreshAll());
    }

    await Future.wait(futures);
  }

  /// Gets the Dio interceptor (if enabled).
  ConfidentialDioInterceptor? get dioInterceptor => _dioInterceptor;

  /// Gets the Provider manager (if enabled).
  SecretManagerProvider? get providerManager => _providerManager;

  /// Gets the Riverpod manager (if enabled).
  RiverpodSecretManager? get riverpodManager => _riverpodManager;

  /// Gets the GetIt service (if enabled).
  ConfidentialGetItService? get getItService => _getItService;

  /// Gets the BLoC instance (if enabled).
  SecretBloc? get secretBloc => _secretBloc;

  /// Gets the GetX service (if enabled).
  SecretService? get getXService => _getXService;

  /// Gets all registered secret names.
  List<String> get secretNames => [
    ..._staticSecrets.keys,
    ..._asyncSecrets.keys,
  ];

  /// Gets the count of registered secrets.
  int get secretCount => _staticSecrets.length + _asyncSecrets.length;

  /// Whether the manager is initialized.
  bool get isInitialized => _initialized;

  Future<void> _loadSecretsFromProvider(
    SecretProvider secretProvider,
    Map<String, String> secretNames,
  ) async {
    for (final entry in secretNames.entries) {
      final asyncSecret = AsyncObfuscatedString(
        secretName: entry.key,
        provider: secretProvider,
        algorithm: entry.value,
      );

      addAsyncSecret(entry.key, asyncSecret);
    }
  }

  /// Disposes of all integrations.
  Future<void> dispose() async {
    // Dispose Provider manager
    if (_providerManager != null) {
      _providerManager!.dispose();
    }

    // Dispose Riverpod manager
    if (_riverpodManager != null) {
      _riverpodManager!.dispose();
    }

    // Dispose GetIt service
    if (_getItService != null) {
      _getItService!.dispose();
    }

    // Dispose BLoC
    if (_secretBloc != null) {
      await _secretBloc!.close();
    }

    // Dispose GetX service
    if (_getXService != null) {
      _getXService!.onClose();
    }

    _initialized = false;
  }
}

/// Factory for creating integration managers with common configurations.
class ConfidentialIntegrationFactory {
  /// Creates a manager with all integrations enabled.
  static ConfidentialIntegrationManager createFullIntegration({
    DioIntegrationConfig? dioConfig,
    GetItIntegrationConfig? getItConfig,
    Duration defaultRefreshInterval = const Duration(minutes: 5),
    bool autoRefresh = true,
  }) {
    return ConfidentialIntegrationManager(
      config: IntegrationConfig.all(
        dioConfig: dioConfig,
        getItConfig: getItConfig,
        defaultRefreshInterval: defaultRefreshInterval,
        autoRefresh: autoRefresh,
      ),
    );
  }

  /// Creates a manager for HTTP client integration only.
  static ConfidentialIntegrationManager createHttpIntegration({
    DioIntegrationConfig? dioConfig,
  }) {
    return ConfidentialIntegrationManager(
      config: IntegrationConfig(enableDio: true, dioConfig: dioConfig),
    );
  }

  /// Creates a manager for dependency injection only.
  static ConfidentialIntegrationManager createDIIntegration({
    bool enableProvider = true,
    bool enableRiverpod = true,
    bool enableGetIt = true,
    GetItIntegrationConfig? getItConfig,
  }) {
    return ConfidentialIntegrationManager(
      config: IntegrationConfig(
        enableProvider: enableProvider,
        enableRiverpod: enableRiverpod,
        enableGetIt: enableGetIt,
        getItConfig: getItConfig,
      ),
    );
  }

  /// Creates a manager for state management integration only.
  static ConfidentialIntegrationManager createStateManagementIntegration() {
    return ConfidentialIntegrationManager(
      config: const IntegrationConfig(
        enableBloc: true,
        enableProvider: true,
        enableRiverpod: true,
        enableGetX: true,
      ),
    );
  }

  /// Creates a manager with custom configuration.
  static ConfidentialIntegrationManager createCustom(IntegrationConfig config) {
    return ConfidentialIntegrationManager(config: config);
  }
}
