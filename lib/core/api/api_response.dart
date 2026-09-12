class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final ApiError? error;
  final Map<String, dynamic>? meta;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromDataJson,
  ) {
    final bool isSuccess = json['success'] == true;
    T? parsedData;
    if (isSuccess && json.containsKey('data') && json['data'] != null) {
      if (fromDataJson != null) {
        parsedData = fromDataJson(json['data']);
      } else {
        parsedData = json['data'] as T;
      }
    }

    ApiError? parsedError;
    if (json.containsKey('error') && json['error'] != null) {
      if (json['error'] is Map<String, dynamic>) {
        parsedError = ApiError.fromJson(json['error'] as Map<String, dynamic>);
      } else if (json['error'] is String) {
        parsedError = ApiError(code: 'ERROR', message: json['error'] as String);
      }
    }

    final String? resolvedMessage = (json['message'] as String?) ?? parsedError?.message;

    return ApiResponse<T>(
      success: isSuccess,
      data: parsedData,
      message: resolvedMessage,
      error: parsedError,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

class ApiError {
  final String code;
  final String message;
  final dynamic details;
  final String? requestId;

  ApiError({
    required this.code,
    required this.message,
    this.details,
    this.requestId,
  });

  /// User-friendly message that prioritizes specific field-level validation messages.
  String get displayMessage {
    if (details is Map && details['fields'] is List) {
      final fields = details['fields'] as List;
      final specificMessages = fields
          .map((f) => f is Map ? f['message'] as String? : null)
          .where((m) => m != null && m.isNotEmpty)
          .cast<String>()
          .toList();
      if (specificMessages.isNotEmpty) {
        return specificMessages.join('\n');
      }
    }
    return message;
  }

  factory ApiError.fromJson(Map<String, dynamic> json) {
    String msg = 'An unexpected error occurred.';
    final rawMessage = json['message'];
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      msg = rawMessage.trim();
    } else if (rawMessage is List) {
      msg = rawMessage.map((m) => m.toString()).join('\n');
    }

    return ApiError(
      code: (json['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: msg,
      details: json['details'],
      requestId: json['requestId'] as String?,
    );
  }
}
