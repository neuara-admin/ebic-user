import 'package:flutter/material.dart';
import 'app_routes.dart';

class DeepLinkTarget {
  final String routeName;
  final dynamic arguments;

  const DeepLinkTarget({
    required this.routeName,
    this.arguments,
  });
}

/// Centralized deep link parsing and navigation coordinator.
/// Adheres strictly to Section 17 (Deep Linking Architecture).
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  DeepLinkTarget? _pendingTarget;

  /// Get currently pending deep link target (e.g. after login completion).
  DeepLinkTarget? get pendingTarget => _pendingTarget;

  /// Store target if authentication is required first (Section 17: Deep Link -> Login -> Restore target).
  void savePendingTarget(DeepLinkTarget target) {
    _pendingTarget = target;
  }

  /// Clears pending target after navigating.
  DeepLinkTarget? consumePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  /// Parses a deep link URI into an internal application route and arguments.
  DeepLinkTarget? parseUri(Uri uri) {
    // Scheme must be "ebic" or "https" with ebic domain
    if (uri.scheme != 'ebic' && !uri.host.contains('ebic')) {
      return null;
    }

    final host = uri.host.isNotEmpty ? uri.host : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '');
    final segments = uri.pathSegments;

    // ebic://booking/{bookingId}
    if (host == 'booking') {
      final bookingId = segments.isNotEmpty ? segments.first : null;
      return DeepLinkTarget(
        routeName: AppRoutes.bookingConfirmation,
        arguments: {'bookingId': bookingId},
      );
    }

    // ebic://order/{orderId}
    if (host == 'order') {
      final orderId = segments.isNotEmpty ? segments.first : null;
      return DeepLinkTarget(
        routeName: AppRoutes.orderDetail,
        arguments: {'orderId': orderId},
      );
    }

    // ebic://consultation/{consultationId}
    if (host == 'consultation') {
      final id = segments.isNotEmpty ? segments.first : null;
      return DeepLinkTarget(
        routeName: AppRoutes.videoConsultation,
        arguments: {'consultationId': id},
      );
    }

    // Section 80 — Health Pass Notification Deep Links:
    // ebic://health-pass
    // ebic://health-pass/usage
    // ebic://health-pass/renew
    // ebic://health-pass/history
    // ebic://health-pass/plans
    if (host == 'health-pass') {
      final sub = segments.isNotEmpty ? segments.first.toLowerCase() : '';
      if (sub == 'usage') {
        final passId = segments.length > 1 ? segments[1] : null;
        return DeepLinkTarget(
          routeName: AppRoutes.healthPassUsage,
          arguments: passId != null ? {'healthPassId': passId} : null,
        );
      }
      if (sub == 'renew') {
        final passId = segments.length > 1 ? segments[1] : null;
        return DeepLinkTarget(
          routeName: AppRoutes.healthPassRenew,
          arguments: passId != null ? {'healthPassId': passId} : null,
        );
      }
      if (sub == 'history') {
        return const DeepLinkTarget(routeName: AppRoutes.healthPassHistory);
      }
      if (sub == 'plans') {
        return const DeepLinkTarget(routeName: AppRoutes.healthPassPlans);
      }
      if (sub == 'comparison') {
        return const DeepLinkTarget(routeName: AppRoutes.healthPassComparison);
      }
      if (sub == 'purchase') {
        return const DeepLinkTarget(routeName: AppRoutes.healthPassPurchase);
      }
      return const DeepLinkTarget(routeName: AppRoutes.healthPass);
    }

    // ebic://diet-plan/{memberId}
    if (host == 'diet-plan') {
      final memberId = segments.isNotEmpty ? segments.first : null;
      return DeepLinkTarget(
        routeName: AppRoutes.dietPlan,
        arguments: {'memberId': memberId},
      );
    }

    // ebic://support/ticket/{ticketId}
    if (host == 'support') {
      return const DeepLinkTarget(routeName: AppRoutes.profile);
    }

    return null;
  }

  /// Handle deep link navigation with authentication awareness.
  void handleDeepLink(BuildContext context, Uri uri, {required bool isAuthenticated}) {
    final target = parseUri(uri);
    if (target == null) return;

    if (!isAuthenticated) {
      // Save target and route to Login (Section 17)
      savePendingTarget(target);
      Navigator.pushNamed(context, AppRoutes.login);
    } else {
      Navigator.pushNamed(context, target.routeName, arguments: target.arguments);
    }
  }
}
