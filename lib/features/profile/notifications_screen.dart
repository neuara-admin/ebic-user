import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // 'ALL', 'UNREAD', 'BOOKINGS', 'HEALTH', 'PAYMENTS'
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
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
            _notifications = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoading = false;
          });
          return;
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.message ?? res.error?.message ?? 'Unable to load notifications.';
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to connect to server. Please check your connection.';
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
    final unreadItems = _notifications.where((n) => !_isNotificationRead(n)).toList();
    if (unreadItems.isEmpty) return;

    setState(() {
      for (var n in _notifications) {
        n['status'] = 'READ';
        n['readAt'] = DateTime.now().toIso8601String();
      }
    });

    try {
      await _api.post(ApiEndpoints.notificationReadAll);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    if (id == null || _isNotificationRead(n)) return;

    setState(() {
      n['status'] = 'READ';
      n['readAt'] = DateTime.now().toIso8601String();
    });

    try {
      await _api.patch(ApiEndpoints.notificationRead(id));
    } catch (_) {}
  }

  Future<void> _deleteNotification(Map<String, dynamic> n, int index) async {
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
    _markAsRead(n);
    final link = (n['deepLink'] ?? '').toString().toLowerCase();
    final entityType = (n['entityType'] ?? n['category'] ?? '').toString().toUpperCase();

    if (link.contains('/orders') || entityType == 'CHEF_BOOKING' || entityType == 'ORDER') {
      Navigator.pushNamed(context, AppRoutes.orders);
    } else if (link.contains('/health-pass') || entityType == 'HEALTH_PASS') {
      Navigator.pushNamed(context, AppRoutes.healthPass);
    } else if (link.contains('/diet-plans') || entityType == 'DIET_PLAN') {
      Navigator.pushNamed(context, AppRoutes.dietPlan);
    } else if (link.contains('/consultations') || entityType == 'CONSULTATION' || entityType == 'DIETITIAN') {
      Navigator.pushNamed(context, AppRoutes.consultationsList);
    } else if (link.contains('/support') || entityType == 'SUPPORT' || entityType == 'SUPPORT_TICKET') {
      Navigator.pushNamed(context, AppRoutes.support);
    } else if (link.contains('/profile') || entityType == 'PROFILE') {
      Navigator.pushNamed(context, AppRoutes.profile);
    }
  }

  IconData _iconForCategory(String? category) {
    switch (category?.toUpperCase()) {
      case 'CHEF_BOOKING':
      case 'CHEF_TRACKING':
      case 'ORDER':
        return Icons.soup_kitchen_outlined;
      case 'HEALTH_PASS':
        return Icons.health_and_safety_outlined;
      case 'DIETITIAN':
      case 'CONSULTATION':
        return Icons.video_camera_front_outlined;
      case 'DIET_PLAN':
        return Icons.restaurant_menu_rounded;
      case 'PAYMENT':
      case 'REFUND':
        return Icons.receipt_long_outlined;
      case 'SUPPORT':
      case 'SUPPORT_TICKET':
        return Icons.support_agent_rounded;
      case 'SECURITY':
      case 'ACCOUNT':
        return Icons.security_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _categoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'CHEF_BOOKING':
      case 'CHEF_TRACKING':
      case 'ORDER':
        return const Color(0xFFEA580C); // Warm Orange
      case 'HEALTH_PASS':
        return AppColors.primaryDark; // Brand Green
      case 'DIETITIAN':
      case 'CONSULTATION':
        return const Color(0xFF0284C7); // Sky Blue
      case 'DIET_PLAN':
        return const Color(0xFF059669); // Emerald
      case 'PAYMENT':
      case 'REFUND':
        return const Color(0xFF4F46E5); // Indigo
      case 'SUPPORT':
        return const Color(0xFF9333EA); // Purple
      default:
        return AppColors.slate700;
    }
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

  int get _unreadCount => _notifications.where((n) => !_isNotificationRead(n)).length;

  List<Map<String, dynamic>> _getFilteredList() {
    return _notifications.where((n) {
      final isRead = _isNotificationRead(n);
      final cat = (n['category'] ?? n['entityType'] ?? '').toString().toUpperCase();

      switch (_selectedFilter) {
        case 'UNREAD':
          return !isRead;
        case 'BOOKINGS':
          return cat == 'CHEF_BOOKING' || cat == 'ORDER' || cat == 'CHEF_TRACKING';
        case 'HEALTH':
          return cat == 'HEALTH_PASS' || cat == 'DIET_PLAN' || cat == 'CONSULTATION' || cat == 'DIETITIAN';
        case 'PAYMENTS':
          return cat == 'PAYMENT' || cat == 'REFUND';
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
        foregroundColor: textPrimary,
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              icon: Icon(Icons.done_all_rounded, size: 16, color: isDark ? AppColors.primaryLight : AppColors.primary),
              label: Text('Mark all read', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppColors.primaryLight : AppColors.primary)),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              color: isDark ? AppColors.slate900 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('UNREAD', _unreadCount > 0 ? 'Unread ($_unreadCount)' : 'Unread', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('BOOKINGS', 'Bookings', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('HEALTH', 'Health & Diet', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('PAYMENTS', 'Payments', isDark),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: isDark ? AppColors.slate800 : AppColors.slate200),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 32),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Connection Problem',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                                ),
                                const SizedBox(height: 20),
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
                                    height: MediaQuery.of(context).size.height * 0.55,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.notifications_none_rounded, size: 36, color: textMuted),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _selectedFilter == 'UNREAD' ? 'No unread notifications' : "You're all caught up!",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _selectedFilter == 'UNREAD'
                                                  ? 'All your alerts have been marked as read.'
                                                  : 'When you book a chef, receive diet plans, or have updates, they will appear here.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                                            ),
                                            if (_selectedFilter != 'ALL') ...[
                                              const SizedBox(height: 16),
                                              TextButton(
                                                onPressed: () => setState(() => _selectedFilter = 'ALL'),
                                                child: Text('View All Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryLight : AppColors.primary)),
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
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final n = filteredList[idx];
                                  final isRead = _isNotificationRead(n);
                                  final category = (n['category'] ?? 'GENERAL').toString().replaceAll('_', ' ');
                                  final catColor = _categoryColor(n['category']?.toString());

                                  return Dismissible(
                                    key: ValueKey(n['id'] ?? 'notif_$idx'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                                    ),
                                    onDismissed: (_) {
                                      final originalIndex = _notifications.indexOf(n);
                                      _deleteNotification(n, originalIndex >= 0 ? originalIndex : idx);
                                    },
                                    child: EbicCard(
                                      border: !isRead ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.2) : null,
                                      onTap: () => _handleDeepLink(n),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: catColor.withOpacity(isDark ? 0.22 : 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _iconForCategory(n['category']?.toString()),
                                              color: isDark ? catColor.withOpacity(0.95) : catColor,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        category,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? catColor.withOpacity(0.95) : catColor,
                                                          letterSpacing: 0.3,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatTime(n['createdAt']),
                                                      style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  (n['title'] ?? '').toString(),
                                                  style: TextStyle(
                                                    fontWeight: !isRead ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 14,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  (n['body'] ?? '').toString(),
                                                  style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isRead)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8, top: 4),
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
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

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
              : (isDark ? AppColors.slate300 : AppColors.slate700),
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
      selectedColor: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.primarySubtle,
      backgroundColor: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? (isDark ? AppColors.primaryLight : AppColors.primary)
              : (isDark ? AppColors.slate700 : Colors.transparent),
          width: 1,
        ),
      ),
    );
  }
}
