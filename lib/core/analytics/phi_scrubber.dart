import 'package:sentry_flutter/sentry_flutter.dart';

/// Sensitive Data & PHI (Protected Health Information) Scrubber.
/// Ensures compliance with Indian Digital Personal Data Protection (DPDP) standards
/// and Section 11 / 32 (Privacy & Logging Policy).
///
/// Strips out:
/// - User, customer, member and chef names
/// - Email addresses and telephone numbers
/// - Passwords, OTPs, secret keys, JWTs, and authorization tokens
/// - Government IDs (Aadhaar, PAN)
/// - Clinical payload bodies (SOAP assessments, medical notes, blood glucose, allergens, lab reports)
/// - Query parameters from URLs and request bodies from HTTP events
class PhiScrubber {
  PhiScrubber._();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _jwtRegex = RegExp(
    r'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}(?:\.[A-Za-z0-9_-]+)?',
  );

  static final RegExp _bearerRegex = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.]+',
    caseSensitive: false,
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:(?:\+|0{0,2})91[\s\-]?)?[6-9]\d{9}\b|\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b',
  );

  static final RegExp _aadhaarRegex = RegExp(
    r'\b\d{4}\s\d{4}\s\d{4}\b',
  );

  static final RegExp _panRegex = RegExp(
    r'\b[A-Z]{5}[0-9]{4}[A-Z]\b',
  );

  static final RegExp _sensitiveKeyValueRegex = RegExp(
    r'''\b(password|secret|apikey|api_key|access_?token|refresh_?token|auth_?token|otp)\s*[:=]\s*["']?[^"',\s]+["']?''',
    caseSensitive: false,
  );

  static final RegExp _sensitiveKeyPattern = RegExp(
    r'.*(password|secret|apikey|token|cookie|body|notes|diagnosis|soap|assessment|allergies|prescription|medication|blood_?sugar|hba1c|weight|phone|mobile|email|name|otp|card_number|cvv|lab_result|lab_report).*',
    caseSensitive: false,
  );

  /// Scrubs free-form text strings of any PII, credentials, OTPs, or PHI markers.
  static String scrubString(String input) {
    if (input.isEmpty) return input;

    var result = input;

    // 1. Bearer tokens
    result = result.replaceAllMapped(_bearerRegex, (_) => 'Bearer [REDACTED_TOKEN]');

    // 2. Raw JWTs
    result = result.replaceAllMapped(_jwtRegex, (_) => '[REDACTED_TOKEN]');

    // 3. Secrets / passwords / OTPs in key-value format
    result = result.replaceAllMapped(_sensitiveKeyValueRegex, (match) {
      final key = match.group(1);
      return '$key: [REDACTED_SECRET]';
    });

    // 4. Emails
    result = result.replaceAllMapped(_emailRegex, (_) => '[REDACTED_EMAIL]');

    // 5. Phone numbers
    result = result.replaceAllMapped(_phoneRegex, (_) => '[REDACTED_PHONE]');

    // 6. Aadhaar & PAN numbers
    result = result.replaceAllMapped(_aadhaarRegex, (_) => '[REDACTED_ID]');
    result = result.replaceAllMapped(_panRegex, (_) => '[REDACTED_ID]');

    return result;
  }

  /// Scrubs URLs by removing query parameter values and token fragments.
  static String scrubUrl(String url) {
    if (url.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      if (uri.hasQuery) {
        return uri.replace(query: 'query_params_redacted=1').toString();
      }
      return scrubString(url);
    } catch (_) {
      return scrubString(url);
    }
  }

  /// Recursively sanitizes a JSON/Map structure, replacing sensitive keys
  /// and scrubbing string values.
  static Map<String, dynamic> scrubMap(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;

      if (_sensitiveKeyPattern.hasMatch(key)) {
        sanitized[key] = '[REDACTED]';
        continue;
      }

      sanitized[key] = _scrubValue(val);
    }

    return sanitized;
  }

  /// Recursively scrubs lists of values.
  static List<dynamic> scrubList(List<dynamic> list) {
    return list.map(_scrubValue).toList();
  }

  static dynamic _scrubValue(dynamic val) {
    if (val is String) {
      return scrubString(val);
    } else if (val is Map<String, dynamic>) {
      return scrubMap(val);
    } else if (val is Map) {
      return scrubMap(Map<String, dynamic>.from(val));
    } else if (val is List) {
      return scrubList(val);
    }
    return val;
  }

  /// Sanitizes a [Breadcrumb] before sending to Sentry or local buffer.
  static Breadcrumb scrubBreadcrumb(Breadcrumb breadcrumb) {
    final scrubbedMessage = breadcrumb.message != null ? scrubString(breadcrumb.message!) : null;

    Map<String, dynamic>? scrubbedData;
    if (breadcrumb.data != null) {
      scrubbedData = scrubMap(Map<String, dynamic>.from(breadcrumb.data!));
    }

    return breadcrumb.copyWith(
      message: scrubbedMessage,
      data: scrubbedData,
    );
  }

  /// Sentry `beforeSend` hook callback: scrubs exceptions, messages, extras, tags,
  /// request details, and strips user identity down to opaque ID only.
  static SentryEvent? scrubSentryEvent(SentryEvent event) {
    // 1. Scrub SentryMessage if present
    SentryMessage? scrubbedMessage;
    if (event.message != null) {
      scrubbedMessage = SentryMessage(
        scrubString(event.message!.formatted),
        template: event.message!.template != null ? scrubString(event.message!.template!) : null,
        params: event.message!.params?.map((p) => scrubString(p.toString())).toList(),
      );
    }

    // 2. Scrub exceptions
    final scrubbedExceptions = event.exceptions?.map((ex) {
      final scrubbedVal = ex.value != null ? scrubString(ex.value!) : null;
      return SentryException(
        type: ex.type,
        value: scrubbedVal,
        module: ex.module,
        threadId: ex.threadId,
        stackTrace: ex.stackTrace,
        mechanism: ex.mechanism,
      );
    }).toList();

    // 3. Scrub breadcrumbs
    final scrubbedBreadcrumbs = event.breadcrumbs?.map(scrubBreadcrumb).toList();

    // 4. Scrub tags
    Map<String, String>? scrubbedTags;
    if (event.tags != null) {
      scrubbedTags = {};
      for (final tag in event.tags!.entries) {
        if (_sensitiveKeyPattern.hasMatch(tag.key)) {
          scrubbedTags[tag.key] = '[REDACTED]';
        } else {
          scrubbedTags[tag.key] = scrubString(tag.value);
        }
      }
    }

    // 5. Scrub contexts
    final scrubbedContexts = Contexts();
    for (final entry in event.contexts.entries) {
      if (entry.value is Map<String, dynamic>) {
        scrubbedContexts[entry.key] = scrubMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is String) {
        scrubbedContexts[entry.key] = scrubString(entry.value as String);
      } else {
        scrubbedContexts[entry.key] = entry.value;
      }
    }

    // 6. Scrub user: NEVER send email, username, phone or IP address.
    // Retain only opaque user ID and role for error triage.
    SentryUser? scrubbedUser;
    if (event.user != null) {
      scrubbedUser = SentryUser(
        id: event.user!.id,
        data: const {'role': 'CUSTOMER'},
      );
    }

    // 7. Scrub request: strip request body, query params, and auth headers
    SentryRequest? scrubbedRequest;
    if (event.request != null) {
      final sanitizedHeaders = <String, String>{};
      for (final header in event.request!.headers.entries) {
        final k = header.key.toLowerCase();
        if (k == 'authorization' || k == 'cookie' || k == 'set-cookie' || k.contains('token')) {
          continue; // Dropped completely
        }
        sanitizedHeaders[header.key] = scrubString(header.value);
      }

      scrubbedRequest = SentryRequest(
        url: event.request!.url != null ? scrubUrl(event.request!.url!) : null,
        method: event.request!.method,
        queryString: null, // Always dropped
        cookies: null, // Always dropped
        data: null, // Request body is always dropped to guarantee no PHI leak
        headers: sanitizedHeaders,
        env: null,
      );
    }

    return event.copyWith(
      message: scrubbedMessage,
      exceptions: scrubbedExceptions,
      breadcrumbs: scrubbedBreadcrumbs,
      tags: scrubbedTags,
      contexts: scrubbedContexts,
      user: scrubbedUser,
      request: scrubbedRequest,
    );
  }
}

