import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'api_response.dart';
import 'idempotency_service.dart';

/// Abstract adapter allowing mock responses during development/testing
/// without polluting production code (Section 35).
abstract class MockApiAdapter {
  Future<http.Response?> handle(String method, Uri uri, {Map<String, String>? headers, dynamic body});
}

/// Centralized HTTP client managing auth tokens, correlation IDs,
/// idempotency, status mapping, timeouts, and coordinated token refresh
/// to prevent refresh storms (Sections 24-27).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _httpClient = http.Client();
  MockApiAdapter? mockAdapter;

  /// Correlation ID maintained across a logical user session or flow (Section 19).
  String currentCorrelationId = IdempotencyService.generateKey();

  /// Single-flight lock future preventing refresh storms (Section 27).
  Future<bool>? _refreshFuture;

  /// Callback fired when session is unrecoverably expired (Section 26 & 30).
  VoidCallback? onSessionExpired;

  /// Coordinated token refresh handler (Section 25–27)
  Future<bool> _coordinatedRefreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _executeTokenRefresh();
    try {
      final success = await _refreshFuture!;
      return success;
    } finally {
      _refreshFuture = null;
    }
  }

  bool _triedFallbackUrl = false;

  Future<bool> _trySwitchToReverseAdbFallback() async {
    if (_triedFallbackUrl) return false;
    _triedFallbackUrl = true;
    final currentUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (currentUri != null && currentUri.host != '127.0.0.1' && currentUri.host != 'localhost') {
      try {
        final probeUri = Uri.parse('http://127.0.0.1:3000/v1/config');
        final testRes = await _httpClient.get(probeUri).timeout(const Duration(seconds: 2));
        if (testRes.statusCode >= 200 && testRes.statusCode < 500) {
          debugPrint('🔄 [Network] Seamlessly switched base URL to USB reverse-ADB bridge: http://127.0.0.1:3000/v1');
          AppConfig.apiBaseUrl = 'http://127.0.0.1:3000/v1';
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _executeTokenRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleSessionFailure();
      return false;
    }

    try {
      final uri = _resolveUri(ApiEndpoints.refreshToken);
      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Correlation-Id': currentCorrelationId,
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(AppConfig.connectTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded is Map<String, dynamic> ? decoded : null;
        final newAccessToken = data?['accessToken'] as String?;
        final newRefreshToken = data?['refreshToken'] as String?;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await TokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
          );
          return true;
        }
      }

      // Only purge if backend explicitly rejected refresh (401 or 403)
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _handleSessionFailure();
      }
      return false;
    } catch (_) {
      // Network/socket timeout during refresh: DO NOT purge tokens (Section 69)
      return false;
    }
  }

  Future<void> _handleSessionFailure() async {
    await TokenStorage.clear();
    onSessionExpired?.call();
  }

  Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    bool requiresIdempotency = false,
    String? explicitIdempotencyKey,
  }) async {
    final requestId = IdempotencyService.generateKey();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': requestId,
      'X-Correlation-Id': currentCorrelationId,
    };

    if (requiresAuth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (requiresIdempotency) {
      headers['Idempotency-Key'] = explicitIdempotencyKey ?? IdempotencyService.generateKey();
    }

    return headers;
  }

  Uri _resolveUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    String base = AppConfig.apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$base$cleanEndpoint';

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final query = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      return Uri.parse(fullUrl).replace(queryParameters: query);
    }

    return Uri.parse(fullUrl);
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    T Function(dynamic)? fromDataJson,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(endpoint, queryParameters);
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);

      if (mockAdapter != null) {
        final mockResponse = await mockAdapter!.handle('GET', uri, headers: headers);
        if (mockResponse != null) return _parseResponse<T>(mockResponse, fromDataJson);
      }

      final response = await _httpClient.get(uri, headers: headers).timeout(AppConfig.connectTimeout);

      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _coordinatedRefreshToken();
        if (refreshed) {
          return get<T>(
            endpoint,
            queryParameters: queryParameters,
            requiresAuth: requiresAuth,
            fromDataJson: fromDataJson,
            isRetry: true,
          );
        }
      }

      return _parseResponse<T>(response, fromDataJson, method: 'GET', uri: uri);
    } catch (e) {
      if (!isRetry && await _trySwitchToReverseAdbFallback()) {
        return get<T>(
          endpoint,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          fromDataJson: fromDataJson,
          isRetry: true,
        );
      }
      return _handleCatchException<T>(e, 'GET', uri);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool requiresIdempotency = false,
    String? explicitIdempotencyKey,
    T Function(dynamic)? fromDataJson,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(endpoint, queryParameters);
    try {
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
        requiresIdempotency: requiresIdempotency,
        explicitIdempotencyKey: explicitIdempotencyKey,
      );

      final encodedBody = body != null ? jsonEncode(body) : null;

      if (mockAdapter != null) {
        final mockResponse = await mockAdapter!.handle('POST', uri, headers: headers, body: encodedBody);
        if (mockResponse != null) return _parseResponse<T>(mockResponse, fromDataJson, method: 'POST', uri: uri, requestBody: encodedBody);
      }

      final response = await _httpClient
          .post(uri, headers: headers, body: encodedBody)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _coordinatedRefreshToken();
        if (refreshed) {
          return post<T>(
            endpoint,
            body: body,
            queryParameters: queryParameters,
            requiresAuth: requiresAuth,
            requiresIdempotency: requiresIdempotency,
            explicitIdempotencyKey: explicitIdempotencyKey,
            fromDataJson: fromDataJson,
            isRetry: true,
          );
        }
      }

      return _parseResponse<T>(response, fromDataJson, method: 'POST', uri: uri, requestBody: encodedBody);
    } catch (e) {
      if (!isRetry && await _trySwitchToReverseAdbFallback()) {
        return post<T>(
          endpoint,
          body: body,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          requiresIdempotency: requiresIdempotency,
          explicitIdempotencyKey: explicitIdempotencyKey,
          fromDataJson: fromDataJson,
          isRetry: true,
        );
      }
      return _handleCatchException<T>(e, 'POST', uri, requestBody: body);
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool requiresIdempotency = false,
    String? explicitIdempotencyKey,
    T Function(dynamic)? fromDataJson,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(endpoint, queryParameters);
    try {
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
        requiresIdempotency: requiresIdempotency,
        explicitIdempotencyKey: explicitIdempotencyKey,
      );

      final encodedBody = body != null ? jsonEncode(body) : null;

      if (mockAdapter != null) {
        final mockResponse = await mockAdapter!.handle('PATCH', uri, headers: headers, body: encodedBody);
        if (mockResponse != null) return _parseResponse<T>(mockResponse, fromDataJson);
      }

      final response = await _httpClient
          .patch(uri, headers: headers, body: encodedBody)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _coordinatedRefreshToken();
        if (refreshed) {
          return patch<T>(
            endpoint,
            body: body,
            queryParameters: queryParameters,
            requiresAuth: requiresAuth,
            requiresIdempotency: requiresIdempotency,
            explicitIdempotencyKey: explicitIdempotencyKey,
            fromDataJson: fromDataJson,
            isRetry: true,
          );
        }
      }

      return _parseResponse<T>(response, fromDataJson, method: 'PATCH', uri: uri, requestBody: encodedBody);
    } catch (e) {
      return _handleCatchException<T>(e, 'PATCH', uri, requestBody: body);
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    T Function(dynamic)? fromDataJson,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(endpoint, queryParameters);
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);

      if (mockAdapter != null) {
        final mockResponse = await mockAdapter!.handle('DELETE', uri, headers: headers);
        if (mockResponse != null) return _parseResponse<T>(mockResponse, fromDataJson, method: 'DELETE', uri: uri);
      }

      final response = await _httpClient.delete(uri, headers: headers).timeout(AppConfig.connectTimeout);

      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _coordinatedRefreshToken();
        if (refreshed) {
          return delete<T>(
            endpoint,
            queryParameters: queryParameters,
            requiresAuth: requiresAuth,
            fromDataJson: fromDataJson,
            isRetry: true,
          );
        }
      }

      return _parseResponse<T>(response, fromDataJson, method: 'DELETE', uri: uri);
    } catch (e) {
      return _handleCatchException<T>(e, 'DELETE', uri);
    }
  }

  Future<ApiResponse<T>> uploadMultipart<T>(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    String fieldName = 'file',
    Map<String, String>? fields,
    MediaType? contentType,
    bool requiresAuth = true,
    T Function(dynamic)? fromDataJson,
    bool isRetry = false,
  }) async {
    final uri = _resolveUri(endpoint);
    try {
      final request = http.MultipartRequest('POST', uri);

      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      MediaType? resolvedContentType = contentType;
      if (resolvedContentType == null) {
        final lower = filename.toLowerCase();
        if (lower.endsWith('.png')) {
          resolvedContentType = MediaType('image', 'png');
        } else if (lower.endsWith('.webp')) {
          resolvedContentType = MediaType('image', 'webp');
        } else if (lower.endsWith('.pdf')) {
          resolvedContentType = MediaType('application', 'pdf');
        } else if (lower.endsWith('.mp4')) {
          resolvedContentType = MediaType('video', 'mp4');
        } else {
          resolvedContentType = MediaType('image', 'jpeg');
        }
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: filename,
          contentType: resolvedContentType,
        ),
      );

      final streamedResponse = await _httpClient.send(request).timeout(AppConfig.connectTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _coordinatedRefreshToken();
        if (refreshed) {
          return uploadMultipart<T>(
            endpoint,
            fileBytes: fileBytes,
            filename: filename,
            fieldName: fieldName,
            fields: fields,
            contentType: contentType,
            requiresAuth: requiresAuth,
            fromDataJson: fromDataJson,
            isRetry: true,
          );
        }
      }

      return _parseResponse<T>(response, fromDataJson, method: 'POST (multipart)', uri: uri);
    } catch (e) {
      return _handleCatchException<T>(e, 'POST (multipart)', uri);
    }
  }

  void _logApiError({
    String? method,
    Uri? uri,
    int? statusCode,
    String? code,
    String? message,
    dynamic requestBody,
    dynamic responseBody,
  }) {
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('❌ [API Error] ${method != null ? '[$method] ' : ''}${uri?.path ?? ''}');
    if (uri != null) debugPrint('   URL: $uri');
    if (statusCode != null) debugPrint('   HTTP Status: $statusCode');
    if (code != null) debugPrint('   Code: $code');
    if (message != null) debugPrint('   Message: $message');
    if (requestBody != null) debugPrint('   Request Body: $requestBody');
    if (responseBody != null) debugPrint('   Response Body: $responseBody');
    debugPrint('════════════════════════════════════════════════════════════');
  }

  ApiResponse<T> _parseResponse<T>(
    http.Response response,
    T Function(dynamic)? fromDataJson, {
    String? method,
    Uri? uri,
    dynamic requestBody,
  }) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('success')) {
          final result = ApiResponse.fromJson(decoded, fromDataJson);
          if (!result.success) {
            _logApiError(
              method: method,
              uri: uri,
              statusCode: response.statusCode,
              code: result.error?.code,
              message: result.error?.message,
              requestBody: requestBody,
              responseBody: decoded,
            );
          }
          return result;
        }

        // Standard 2xx success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final T? parsed = fromDataJson != null ? fromDataJson(decoded) : decoded as T?;
          return ApiResponse<T>(success: true, data: parsed, message: 'Success');
        } else {
          final err = _mapHttpStatusToError<T>(response.statusCode, decoded);
          _logApiError(
            method: method,
            uri: uri,
            statusCode: response.statusCode,
            code: err.error?.code,
            message: err.error?.message,
            requestBody: requestBody,
            responseBody: decoded,
          );
          return err;
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logApiError(
          method: method,
          uri: uri,
          statusCode: response.statusCode,
          code: 'HTTP_${response.statusCode}',
          message: response.body,
          requestBody: requestBody,
        );
      }
      return ApiResponse<T>(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: 'Success',
      );
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<T>(success: true, message: 'Success');
      }
      final err = _mapHttpStatusToError<T>(response.statusCode, null);
      _logApiError(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        code: err.error?.code,
        message: err.error?.message,
        requestBody: requestBody,
        responseBody: response.body,
      );
      return err;
    }
  }

  /// Maps HTTP status codes to standardized user-friendly ApiErrors (Section 7.4 & 10.2).
  ApiResponse<T> _mapHttpStatusToError<T>(int statusCode, Map<String, dynamic>? body) {
    String code = body?['code']?.toString() ??
        (body?['error'] is Map ? (body!['error'] as Map)['code']?.toString() : null) ??
        'HTTP_$statusCode';

    String message = '';
    final rawMessage = body?['message'] ?? (body?['error'] is Map ? (body!['error'] as Map)['message'] : null);
    if (rawMessage is List) {
      message = rawMessage.join(', ');
    } else if (rawMessage != null) {
      message = rawMessage.toString();
    }

    if (message.isEmpty) {
      switch (statusCode) {
        case 400:
          code = 'INVALID_REQUEST';
          message = 'Please check the entered details and try again.';
          break;
        case 401:
          code = 'SESSION_EXPIRED';
          message = 'Your session has expired. Please sign in again.';
          break;
        case 403:
          code = 'FORBIDDEN';
          message = 'You do not have permission to perform this action.';
          break;
        case 404:
          code = 'RESOURCE_NOT_FOUND';
          message = 'The requested resource was not found.';
          break;
        case 409:
          code = 'CONFLICT';
          message = 'The requested action conflicts with the current status.';
          break;
        case 422:
          code = 'VALIDATION_FAILED';
          message = 'Please check the entered details and try again.';
          break;
        case 429:
          code = 'RATE_LIMITED';
          message = 'Too many requests. Please wait a moment before trying again.';
          break;
        default:
          if (statusCode >= 500) {
            code = 'SERVER_ERROR';
            message = "We couldn't complete that request. Please try again.";
          } else {
            message = 'Something went wrong. Please try again.';
          }
      }
    }

    return ApiResponse<T>(
      success: false,
      message: message,
      error: ApiError(
        code: code,
        message: message,
        details: body?['details'] ?? (body?['error'] is Map ? (body!['error'] as Map)['details'] : null),
      ),
    );
  }

  ApiResponse<T> _handleCatchException<T>(dynamic e, String method, Uri uri, {dynamic requestBody}) {
    final code = _resolveErrorCode(e);
    final msg = _cleanErrorMessage(e);
    _logApiError(method: method, uri: uri, code: code, message: msg, requestBody: requestBody);
    return ApiResponse<T>(
      success: false,
      error: ApiError(code: code, message: msg),
    );
  }

  String _resolveErrorCode(dynamic e) {
    if (e is TimeoutException) return 'NETWORK_TIMEOUT';
    if (e is SocketException) return 'NETWORK_ERROR';
    if (e is http.ClientException) return 'SERVER_UNREACHABLE';
    return 'CLIENT_ERROR';
  }

  String _cleanErrorMessage(dynamic e) {
    if (e is TimeoutException) {
      return 'Connection timed out. Please check your internet connection or server availability.';
    }
    if (e is SocketException) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (e is http.ClientException) {
      return 'Server is currently unreachable. Please check your network and try again.';
    }
    if (kDebugMode) return e.toString();
    return "We couldn't complete that request. Please try again.";
  }
}
