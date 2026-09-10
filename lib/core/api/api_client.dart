import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_response.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _httpClient = http.Client();

  String _generateIdempotencyKey() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (100000 + (DateTime.now().microsecond % 900000)).toString();
    return 'idem_${now}_$random';
  }

  String _generateRequestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (100000 + (DateTime.now().microsecond % 900000)).toString();
    return 'req_${now}_$random';
  }

  Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    bool requiresIdempotency = false,
    String? explicitIdempotencyKey,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': _generateRequestId(),
    };

    if (requiresAuth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (requiresIdempotency) {
      headers['Idempotency-Key'] = explicitIdempotencyKey ?? _generateIdempotencyKey();
    }

    return headers;
  }

  Uri _resolveUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final base = AppConfig.apiBaseUrl;
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
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParameters);
      final headers = await _buildHeaders(requiresAuth: requiresAuth);

      final response = await _httpClient.get(uri, headers: headers).timeout(AppConfig.connectTimeout);
      return _parseResponse<T>(response, fromDataJson);
    } on SocketException catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(
          code: 'NETWORK_ERROR',
          message: 'Unable to connect to the EBIC server. Please verify your connection ($e).',
        ),
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(code: 'CLIENT_ERROR', message: e.toString()),
      );
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
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParameters);
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
        requiresIdempotency: requiresIdempotency,
        explicitIdempotencyKey: explicitIdempotencyKey,
      );

      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: headers, body: encodedBody)
          .timeout(AppConfig.connectTimeout);

      return _parseResponse<T>(response, fromDataJson);
    } on SocketException catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(
          code: 'NETWORK_ERROR',
          message: 'Unable to connect to the EBIC server ($e).',
        ),
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(code: 'CLIENT_ERROR', message: e.toString()),
      );
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
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParameters);
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
        requiresIdempotency: requiresIdempotency,
        explicitIdempotencyKey: explicitIdempotencyKey,
      );

      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .patch(uri, headers: headers, body: encodedBody)
          .timeout(AppConfig.connectTimeout);

      return _parseResponse<T>(response, fromDataJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(code: 'CLIENT_ERROR', message: e.toString()),
      );
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    T Function(dynamic)? fromDataJson,
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParameters);
      final headers = await _buildHeaders(requiresAuth: requiresAuth);

      final response = await _httpClient.delete(uri, headers: headers).timeout(AppConfig.connectTimeout);
      return _parseResponse<T>(response, fromDataJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(code: 'CLIENT_ERROR', message: e.toString()),
      );
    }
  }

  ApiResponse<T> _parseResponse<T>(http.Response response, T Function(dynamic)? fromDataJson) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('success')) {
          return ApiResponse.fromJson(decoded, fromDataJson);
        }
        // If NestJS sent a raw body (e.g. exception filter)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final T? parsed = fromDataJson != null ? fromDataJson(decoded) : decoded as T?;
          return ApiResponse<T>(success: true, data: parsed, message: 'Success');
        } else {
          return ApiResponse<T>(
            success: false,
            error: ApiError(
              code: (decoded['code'] as String?) ?? 'HTTP_${response.statusCode}',
              message: (decoded['message'] as String?) ?? 'Request failed (${response.statusCode})',
              details: decoded['details'],
            ),
          );
        }
      }
      return ApiResponse<T>(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: 'Success',
      );
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<T>(success: true, message: 'Success');
      }
      return ApiResponse<T>(
        success: false,
        error: ApiError(
          code: 'PARSE_ERROR',
          message: 'Server returned HTTP ${response.statusCode}: ${response.body}',
        ),
      );
    }
  }
}
