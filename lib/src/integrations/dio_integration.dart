/// Dio HTTP client integration for dart-confidential.
/// 
/// This module provides seamless integration with the Dio HTTP client,
/// allowing automatic injection of encrypted tokens and headers.
library;

import 'dart:async';
import 'dart:convert';

import '../obfuscation/secret.dart';
import '../async/async_obfuscated.dart';
import '../async/secret_providers.dart';

/// Dio integration interface to avoid hard dependency.
/// 
/// This allows the integration to work without requiring dio as a dependency.
abstract class DioLike {
  /// The request interceptors.
  List<InterceptorLike> get interceptors;
  
  /// Options for the Dio instance.
  BaseOptionsLike get options;
}

/// Base options interface for Dio compatibility.
abstract class BaseOptionsLike {
  /// Base headers for all requests.
  Map<String, dynamic>? get headers;
  set headers(Map<String, dynamic>? headers);
}

/// Interceptor interface for Dio compatibility.
abstract class InterceptorLike {
  /// Called before the request is sent.
  FutureOr<void> onRequest(RequestOptionsLike options, RequestInterceptorHandlerLike handler);
  
  /// Called when the response is received.
  FutureOr<void> onResponse(ResponseLike response, ResponseInterceptorHandlerLike handler);
  
  /// Called when an error occurs.
  FutureOr<void> onError(DioErrorLike error, ErrorInterceptorHandlerLike handler);
}

/// Request options interface for Dio compatibility.
abstract class RequestOptionsLike {
  /// Headers for this specific request.
  Map<String, dynamic> get headers;
  set headers(Map<String, dynamic> headers);
  
  /// The request path.
  String get path;
  
  /// The request method.
  String get method;
}

/// Response interface for Dio compatibility.
abstract class ResponseLike {
  /// Response data.
  dynamic get data;
  
  /// Response headers.
  Map<String, List<String>> get headers;
  
  /// HTTP status code.
  int? get statusCode;
}

/// Error interface for Dio compatibility.
abstract class DioErrorLike {
  /// The error message.
  String get message;
  
  /// The response if available.
  ResponseLike? get response;
  
  /// The request options.
  RequestOptionsLike get requestOptions;
}

/// Handler interfaces for interceptors.
abstract class RequestInterceptorHandlerLike {
  void next(RequestOptionsLike options);
  void resolve(ResponseLike response);
  void reject(DioErrorLike error);
}

abstract class ResponseInterceptorHandlerLike {
  void next(ResponseLike response);
  void resolve(ResponseLike response);
  void reject(DioErrorLike error);
}

abstract class ErrorInterceptorHandlerLike {
  void next(DioErrorLike error);
  void resolve(ResponseLike response);
  void reject(DioErrorLike error);
}

/// Configuration for Dio integration.
class DioIntegrationConfig {
  /// Whether to inject tokens automatically.
  final bool autoInjectTokens;
  
  /// Header name for the authorization token.
  final String authHeaderName;
  
  /// Token prefix (e.g., 'Bearer ').
  final String tokenPrefix;
  
  /// Whether to log token injection (for debugging).
  final bool enableLogging;
  
  /// Custom header mappings.
  final Map<String, String> customHeaders;
  
  /// Whether to refresh tokens automatically on 401 errors.
  final bool autoRefreshTokens;

  const DioIntegrationConfig({
    this.autoInjectTokens = true,
    this.authHeaderName = 'Authorization',
    this.tokenPrefix = 'Bearer ',
    this.enableLogging = false,
    this.customHeaders = const {},
    this.autoRefreshTokens = false,
  });
}

/// Dio interceptor for automatic token injection.
class ConfidentialDioInterceptor implements InterceptorLike {
  final DioIntegrationConfig config;
  final Map<String, ObfuscatedValue<String>> _staticTokens = {};
  final Map<String, AsyncObfuscatedValue<String>> _asyncTokens = {};
  final Map<String, String Function()> _dynamicTokens = {};

  ConfidentialDioInterceptor({
    this.config = const DioIntegrationConfig(),
  });

  /// Adds a static obfuscated token.
  void addStaticToken(String name, ObfuscatedValue<String> token) {
    _staticTokens[name] = token;
  }

  /// Adds an async obfuscated token.
  void addAsyncToken(String name, AsyncObfuscatedValue<String> token) {
    _asyncTokens[name] = token;
  }

  /// Adds a dynamic token provider.
  void addDynamicToken(String name, String Function() provider) {
    _dynamicTokens[name] = provider;
  }

  /// Removes a token by name.
  void removeToken(String name) {
    _staticTokens.remove(name);
    _asyncTokens.remove(name);
    _dynamicTokens.remove(name);
  }

  /// Clears all tokens.
  void clearTokens() {
    _staticTokens.clear();
    _asyncTokens.clear();
    _dynamicTokens.clear();
  }

  @override
  FutureOr<void> onRequest(
    RequestOptionsLike options,
    RequestInterceptorHandlerLike handler,
  ) async {
    if (!config.autoInjectTokens) {
      handler.next(options);
      return;
    }

    try {
      // Inject static tokens
      for (final entry in _staticTokens.entries) {
        final token = entry.value.value;
        _injectToken(options, entry.key, token);
      }

      // Inject async tokens
      for (final entry in _asyncTokens.entries) {
        final token = await entry.value.value;
        _injectToken(options, entry.key, token);
      }

      // Inject dynamic tokens
      for (final entry in _dynamicTokens.entries) {
        final token = entry.value();
        _injectToken(options, entry.key, token);
      }

      // Inject custom headers
      for (final entry in config.customHeaders.entries) {
        options.headers[entry.key] = entry.value;
      }

      if (config.enableLogging) {
        print('ConfidentialDio: Injected tokens for ${options.method} ${options.path}');
      }

      handler.next(options);
    } catch (e) {
      if (config.enableLogging) {
        print('ConfidentialDio: Error injecting tokens: $e');
      }
      handler.next(options); // Continue without tokens
    }
  }

  @override
  FutureOr<void> onResponse(
    ResponseLike response,
    ResponseInterceptorHandlerLike handler,
  ) {
    handler.next(response);
  }

  @override
  FutureOr<void> onError(
    DioErrorLike error,
    ErrorInterceptorHandlerLike handler,
  ) async {
    if (config.autoRefreshTokens && 
        error.response?.statusCode == 401 &&
        _asyncTokens.isNotEmpty) {
      
      try {
        // Clear caches for async tokens to force refresh
        for (final token in _asyncTokens.values) {
          token.clearCache();
        }

        if (config.enableLogging) {
          print('ConfidentialDio: Cleared token caches due to 401 error');
        }
      } catch (e) {
        if (config.enableLogging) {
          print('ConfidentialDio: Error refreshing tokens: $e');
        }
      }
    }

    handler.next(error);
  }

  void _injectToken(RequestOptionsLike options, String name, String token) {
    if (name == 'auth' || name == 'authorization') {
      options.headers[config.authHeaderName] = '${config.tokenPrefix}$token';
    } else {
      options.headers[name] = token;
    }
  }
}

/// Extension methods for easy Dio integration.
extension DioConfidentialExtension on DioLike {
  /// Adds confidential token injection to this Dio instance.
  ConfidentialDioInterceptor addConfidentialTokens({
    DioIntegrationConfig config = const DioIntegrationConfig(),
  }) {
    final interceptor = ConfidentialDioInterceptor(config: config);
    interceptors.add(interceptor);
    return interceptor;
  }

  /// Adds a static obfuscated token to the default interceptor.
  void addStaticToken(String name, ObfuscatedValue<String> token) {
    final interceptor = _findConfidentialInterceptor();
    if (interceptor != null) {
      interceptor.addStaticToken(name, token);
    } else {
      throw StateError('No ConfidentialDioInterceptor found. Call addConfidentialTokens() first.');
    }
  }

  /// Adds an async obfuscated token to the default interceptor.
  void addAsyncToken(String name, AsyncObfuscatedValue<String> token) {
    final interceptor = _findConfidentialInterceptor();
    if (interceptor != null) {
      interceptor.addAsyncToken(name, token);
    } else {
      throw StateError('No ConfidentialDioInterceptor found. Call addConfidentialTokens() first.');
    }
  }

  /// Adds a dynamic token provider to the default interceptor.
  void addDynamicToken(String name, String Function() provider) {
    final interceptor = _findConfidentialInterceptor();
    if (interceptor != null) {
      interceptor.addDynamicToken(name, provider);
    } else {
      throw StateError('No ConfidentialDioInterceptor found. Call addConfidentialTokens() first.');
    }
  }

  ConfidentialDioInterceptor? _findConfidentialInterceptor() {
    for (final interceptor in interceptors) {
      if (interceptor is ConfidentialDioInterceptor) {
        return interceptor;
      }
    }
    return null;
  }
}

/// Factory for creating Dio instances with confidential integration.
class ConfidentialDioFactory {
  /// Creates a new Dio instance with confidential token injection.
  static DioLike createDio({
    String? baseUrl,
    Map<String, dynamic>? headers,
    DioIntegrationConfig config = const DioIntegrationConfig(),
  }) {
    // This would create an actual Dio instance in real usage
    // For now, we return a mock implementation
    throw UnimplementedError(
      'This factory requires the dio package to be added as a dependency. '
      'Add "dio: ^5.0.0" to your pubspec.yaml and implement this factory.'
    );
  }

  /// Creates a Dio instance with pre-configured tokens from a provider.
  static Future<DioLike> createDioWithProvider({
    String? baseUrl,
    Map<String, dynamic>? headers,
    required SecretProvider provider,
    required List<String> tokenNames,
    DioIntegrationConfig config = const DioIntegrationConfig(),
  }) async {
    final dio = createDio(baseUrl: baseUrl, headers: headers, config: config);
    final interceptor = dio.addConfidentialTokens(config: config);

    // Load tokens from provider
    for (final tokenName in tokenNames) {
      final asyncToken = AsyncObfuscatedString(
        secretName: tokenName,
        provider: provider,
        algorithm: 'aes-256-gcm',
      );
      interceptor.addAsyncToken(tokenName, asyncToken);
    }

    return dio;
  }
}
