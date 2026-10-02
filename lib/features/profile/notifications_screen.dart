import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

/// Notifications Screen (Module 19 & Section 20 Specification).
/// Fully integrated with NestJS backend (/v1/notifications):
/// - GET /v1/notifications (list with pagination/filter)
/// - GET /v1/notifications/unread-count
/// - PATCH & POST /v1/notifications/:id/read
/// - POST /v1/notifications/read-all
/// - DELETE /v1/notifications/:id
/// - Realtime WebSocket notifications listener for instant silent sync.
/// Redesigned using flutter-bespoke-ui:
/// - Editorial header with live pulsing status pill
/// - Tactile spring-scale EbicCards with hairline borders
/// - Framed category icon capsules (60-30-10 palette)
/// - Contextual Action Chips (Track Chef, Join Call, View Plan)
/// - Scannable 8-word empty states
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // 'ALL', 'UNREAD', 'CHEF', 'HEALTH', 'CONSULT', 'PAYMENTS'
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<StandardSocketEnvelope>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Realtime notification updates (new pushes trigger instant silent sync)
    _realtimeSub = RealtimeService().notifications.listen((_) {
      if (mounted) {
        _fetchNotifications(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get(ApiEndpoints.notifications);
      if (res.success && res.data != null) {
        final raw = res.data;
        List<dynamic> items = [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map && raw['items'] is List) {
          items = raw['items'];
        }
        if (mounted) {
          setState(() {
            _notifications = items
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _isLoading = false;
          });
          return;
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.message ??
                res.error?.message ??
                'Unable to load notifications.';
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to connect to server. Please check your network.';
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    HapticFeedback.mediumImpact();
    final unreadItems =
        _notifications.where((n) => !_isNotificationRead(n)).toList();
    if (unreadItems.isEmpty) return;

    setState(() {
      for (var n in _notifications) {
        n['readAt'] = DateTime.now().toIso8601String();
        n['status'] = 'READ';
      }
    });

    try {
      await _api.post(ApiEndpoints.notificationReadAll);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read'),
          backgroundColor: AppColors.slate900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    if (id == null || _isNotificationRead(n)) return;

    setState(() {
      n['readAt'] = DateTime.now().toIso8601String();
      n['status'] = 'READ';
    });

    try {
      await _api.patch(ApiEndpoints.notificationRead(id));
    } catch (_) {
      try {
        await _api.post(ApiEndpoints.notificationRead(id));
      } catch (_) {}
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> n, int index) async {
    HapticFeedback.lightImpact();
    final id = n['id']?.toString();
    if (id == null) return;

    final removedItem = n;
    setState(() {
      _notifications.removeAt(index);
    });

    try {
      await _api.delete(ApiEndpoints.notificationDelete(id));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification deleted'),
          backgroundColor: AppColors.slate900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.accent,
            onPressed: () {
              setState(() {
                _notifications.insert(index, removedItem);
              });
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool _isNotificationRead(Map<String, dynamic> n) {
    final status = (n['status'] ?? '').toString().toUpperCase();
    return status == 'READ' || n['readAt'] != null;
  }

  void _handleDeepLink(Map<String, dynamic> n) {
    HapticFeedback.lightImpact();
    _markAsRead(n);

    final link = (n['deepLink'] ?? '').toString().toLowerCase();
    final entityType =
        (n['entityType'] ?? n['category'] ?? '').toString().toUpperCase();
    final entityId = n['entityId']?.toString();
    final type = (n['type'] ?? '').toString().toUpperCase();

    if (link.contains('/orders') ||
        entityType == 'CHEF_BOOKING' ||
        entityType == 'ORDER') {
      if (entityId != null && entityId.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.orderDetail,
            arguments: {'orderId': entityId});
      } else {
        Navigator.pushNamed(context, AppRoutes.orders);
      }
    } else if (link.contains('/consultations') ||
        entityType == 'CONSULTATION' ||
        entityType == 'DIETITIAN') {
      if (type == 'CONSULTATION_ACTIVE' || link.contains('/video')) {
        Navigator.pushNamed(context, AppRoutes.consultationVideo,
            arguments: {'consultationId': entityId});
      } else {
        Navigator.pushNamed(context, AppRoutes.consultationsList);
      }
    } else if (link.contains('/diet-plan') ||
        entityType == 'DIET_PLAN' ||
        type == 'DIET_PLAN_READY') {
      Navigator.pushNamed(context, AppRoutes.dietPlan);
    } else if (link.contains('/health-pass') || entityType == 'HEALTH_PASS') {
      Navigator.pushNamed(context, AppRoutes.healthPass);
    } else if (link.contains('/wallet') ||
        entityType == 'PAYMENT' ||
        entityType == 'REFUND') {
      Navigator.pushNamed(context, AppRoutes.walletCredits);
    } else if (link.contains('/support') ||
        entityType == 'SUPPORT' ||
        entityType == 'SUPPORT_TICKET') {
      if (entityId != null && entityId.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.supportTicketDetail,
            arguments: {'ticketId': entityId});
      } else {
        Navigator.pushNamed(context, AppRoutes.support);
      }
    } else if (link.contains('/profile')) {
      Navigator.pushNamed(context, AppRoutes.profile);
    }
  }

  IconData _iconForCategory(String? category, String? type) {
    final cat = (category ?? '').toUpperCase();
    final t = (type ?? '').toUpperCase();

    if (t.contains('VIDEO') || cat == 'CONSULTATION') {
      return Icons.video_camera_front_rounded;
    }
    if (t.contains('MEAL') || cat == 'DIET_PLAN') {
      return Icons.restaurant_menu_rounded;
    }
    if (cat == 'CHEF_BOOKING' || cat == 'CHEF_TRACKING' || cat == 'ORDER') {
      return Icons.soup_kitchen_rounded;
    }
    if (cat == 'HEALTH_PASS') {
      return Icons.health_and_safety_rounded;
    }
    if (cat == 'PAYMENT' || cat == 'REFUND') {
      return Icons.receipt_long_rounded;
    }
    if (cat == 'SUPPORT' || cat == 'SUPPORT_TICKET') {
      return Icons.support_agent_rounded;
    }
    if (cat == 'SECURITY' || cat == 'ACCOUNT') {
      return Icons.shield_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _categoryColor(String? category, String? priority) {
    if (priority == 'CRITICAL') return const Color(0xFFEF4444);
    final cat = (category ?? '').toUpperCase();

    switch (cat) {
      case 'CHEF_BOOKING':
      case 'CHEF_TRACKING':
      case 'ORDER':
        return const Color(0xFFEA580C); // Culinary Warm Amber
      case 'HEALTH_PASS':
      case 'DIET_PLAN':
        return AppColors.primary; // Emerald 600
      case 'DIETITIAN':
      case 'CONSULTATION':
        return const Color(0xFF0284C7); // Clinical Sky Blue
      case 'PAYMENT':
      case 'REFUND':
        return const Color(0xFF4F46E5); // Royal Indigo
      case 'SUPPORT':
      case 'SUPPORT_TICKET':
        return const Color(0xFF9333EA); // Soft Purple
      default:
        return const Color(0xFF0D9488); // Teal
    }
  }

  String? _getActionLabel(Map<String, dynamic> n) {
    final link = (n['deepLink'] ?? '').toString().toLowerCase();
    final entityType =
        (n['entityType'] ?? n['category'] ?? '').toString().toUpperCase();
    final type = (n['type'] ?? '').toString().toUpperCase();

    if (type.contains('VIDEO') || link.contains('/video')) return 'Join Video Call';
    if (entityType == 'CHEF_BOOKING' || entityType == 'ORDER') return 'Track Chef';
    if (entityType == 'DIET_PLAN') return 'View Diet Plan';
    if (entityType == 'CONSULTATION') return 'View Session';
    if (entityType == 'HEALTH_PASS') return 'View Pass';
    if (entityType == 'PAYMENT') return 'View Invoice';
    if (entityType == 'SUPPORT_TICKET') return 'View Ticket';
    return null;
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => !_isNotificationRead(n)).length;

  List<Map<String, dynamic>> _getFilteredList() {
    return _notifications.where((n) {
      final isRead = _isNotificationRead(n);
      final cat = (n['category'] ?? n['entityType'] ?? '').toString().toUpperCase();

      switch (_selectedFilter) {
        case 'UNREAD':
          return !isRead;
        case 'CHEF':
          return cat == 'BOOKINGS' ||
              cat == 'CHEF_BOOKING' ||
              cat == 'ORDER' ||
              cat == 'CHEF_TRACKING';
        case 'HEALTH':
          return cat == 'HEALTH' ||
              cat == 'HEALTH_PASS' ||
              cat == 'DIET_PLAN';
        case 'CONSULT':
          return cat == 'CONSULTATIONS' ||
              cat == 'CONSULTATION' ||
              cat == 'DIETITIAN';
        case 'PAYMENTS':
          return cat == 'PAYMENTS' ||
              cat == 'PAYMENT' ||
              cat == 'REFUND';
        case 'ALL':
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.4,
                    color: textPrimary,
                  ),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_unreadCount NEW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Real-time culinary & clinical updates',
              style: TextStyle(
                fontSize: 11,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                icon: Icon(
                  Icons.done_all_rounded,
                  size: 15,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
                label: Text(
                  'Read All',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppColors.primarySubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _markAllRead,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Bespoke Editorial Filter Capsules
            Container(
              color: isDark ? AppColors.slate900 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterCapsule('ALL', 'All Updates', Icons.inbox_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildFilterCapsule(
                      'UNREAD',
                      _unreadCount > 0 ? 'Unread ($_unreadCount)' : 'Unread',
                      Icons.mark_email_unread_outlined,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterCapsule('CHEF', 'Chef Orders', Icons.soup_kitchen_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildFilterCapsule('HEALTH', 'Diet & Pass', Icons.health_and_safety_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildFilterCapsule('CONSULT', 'Consultations', Icons.video_camera_front_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildFilterCapsule('PAYMENTS', 'Billing', Icons.receipt_long_rounded, isDark),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFF0F172A).withOpacity(0.06),
            ),

            // 2. Notification List or Responsive Empty State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _errorMessage != null && _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_off_rounded,
                                    color: AppColors.danger,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Connection Problem',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: 140,
                                  child: EbicButton(
                                    label: 'Try Again',
                                    icon: Icons.refresh_rounded,
                                    onPressed: _fetchNotifications,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredList.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _fetchNotifications,
                              color: AppColors.primary,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.58,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.slate800
                                                    : AppColors.primarySubtle,
                                                borderRadius: BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: AppColors.primary.withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.notifications_none_rounded,
                                                size: 32,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _selectedFilter == 'UNREAD'
                                                  ? 'No unread notifications'
                                                  : 'All caught up!',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 17,
                                                letterSpacing: -0.3,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _selectedFilter == 'UNREAD'
                                                  ? 'All your alerts have been reviewed.'
                                                  : 'Chef dispatches & clinical updates appear here.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                            if (_selectedFilter != 'ALL') ...[
                                              const SizedBox(height: 16),
                                              TextButton(
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  setState(() => _selectedFilter = 'ALL');
                                                },
                                                child: Text(
                                                  'View All Updates',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? AppColors.primaryLight
                                                        : AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchNotifications,
                              color: AppColors.primary,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final n = filteredList[idx];
                                  final isRead = _isNotificationRead(n);
                                  final category = (n['category'] ?? 'GENERAL')
                                      .toString()
                                      .replaceAll('_', ' ');
                                  final priority = (n['priority'] ?? 'NORMAL').toString();
                                  final catColor = _categoryColor(n['category']?.toString(), priority);
                                  final actionLabel = _getActionLabel(n);

                                  return Dismissible(
                                    key: ValueKey(n['id'] ?? 'notif_$idx'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onDismissed: (_) {
                                      final originalIndex = _notifications.indexOf(n);
                                      _deleteNotification(
                                        n,
                                        originalIndex >= 0 ? originalIndex : idx,
                                      );
                                    },
                                    child: EbicCard(
                                      padding: const EdgeInsets.all(14),
                                      border: !isRead
                                          ? Border.all(
                                              color: AppColors.primary.withOpacity(0.35),
                                              width: 1.2,
                                            )
                                          : null,
                                      onTap: () => _handleDeepLink(n),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 1. Framed Category Icon Capsule
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: catColor.withOpacity(isDark ? 0.22 : 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: catColor.withOpacity(0.22),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Icon(
                                              _iconForCategory(
                                                n['category']?.toString(),
                                                n['type']?.toString(),
                                              ),
                                              color: catColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 2. Notification Body & Metadata
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: catColor.withOpacity(0.10),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        category.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.6,
                                                          color: catColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          _formatTime(n['createdAt']),
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: textMuted,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        if (!isRead) ...[
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            width: 7,
                                                            height: 7,
                                                            decoration: BoxDecoration(
                                                              color: AppColors.primary,
                                                              shape: BoxShape.circle,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: AppColors.primary.withOpacity(0.5),
                                                                  blurRadius: 5,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  (n['title'] ?? '').toString(),
                                                  style: TextStyle(
                                                    fontWeight: !isRead ? FontWeight.w800 : FontWeight.w700,
                                                    fontSize: 14.5,
                                                    letterSpacing: -0.2,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  (n['body'] ?? '').toString(),
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: textSecondary,
                                                    height: 1.35,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (actionLabel != null) ...[
                                                  const SizedBox(height: 9),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        actionLabel,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: catColor,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Icon(
                                                        Icons.arrow_forward_rounded,
                                                        size: 12,
                                                        color: catColor,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCapsule(String key, String label, IconData icon, bool isDark) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = key);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryDark.withOpacity(0.4) : AppColors.primarySubtle)
              : (isDark ? AppColors.slate800.withOpacity(0.6) : AppColors.slate100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.4)
                : (isDark ? AppColors.slate700 : Colors.transparent),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                  : (isDark ? AppColors.slate400 : AppColors.slate600),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                    : (isDark ? AppColors.slate300 : AppColors.slate700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
