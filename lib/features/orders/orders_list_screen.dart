import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/session_manager.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

enum ChefBookingFilter {
  all,
  completed,
  cancelledByChef,
  cancelledByCustomer,
}

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  ChefBookingFilter _selectedFilter = ChefBookingFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (!SessionManager().isAuthenticated) {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<dynamic> rawList = [];

      // 1. Fetch from /orders endpoint
      final res = await _api.get<dynamic>(ApiEndpoints.orders);
      if (res.success && res.data != null) {
        if (res.data is Map) {
          final map = res.data as Map;
          rawList = (map['items'] ?? map['orders'] ?? map['data']) as List<dynamic>? ?? [];
        } else if (res.data is List) {
          rawList = res.data as List<dynamic>;
        }
      }

      // 2. Secondary fallback / integration with /chef-bookings
      if (rawList.isEmpty) {
        try {
          final chefRes = await _api.get<dynamic>(ApiEndpoints.chefBookings);
          if (chefRes.success && chefRes.data != null) {
            if (chefRes.data is Map) {
              final m = chefRes.data as Map;
              final nested = m['data'] ?? m['items'];
              if (nested is Map && nested['items'] is List) {
                rawList = nested['items'] as List<dynamic>;
              } else if (nested is List) {
                rawList = nested;
              } else if (m['items'] is List) {
                rawList = m['items'] as List<dynamic>;
              }
            } else if (chefRes.data is List) {
              rawList = chefRes.data as List<dynamic>;
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        final parsed = rawList
            .map((json) => OrderModel.fromJson(json is Map<String, dynamic> ? json : {}))
            .toList();
        final currentCount = parsed.where(_isCurrent).length;
        final previousCount = parsed.where((o) => !_isCurrent(o)).length;

        setState(() {
          _orders = parsed;
          _isLoading = false;
        });

        // If user has no active bookings but has past visits, seamlessly show Previous Bookings
        if (currentCount == 0 && previousCount > 0 && _tabController.index == 0) {
          _tabController.animateTo(1);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  bool _isCurrent(OrderModel o) {
    return o.status != 'COMPLETED' && !o.isCancelled;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    // 1. Current Bookings (Active, Cooking, Arriving, Upcoming Scheduled)
    final allCurrentOrders = _orders.where(_isCurrent).toList();

    // 2. Previous Bookings (Completed, Cancelled)
    final allPreviousOrders = _orders.where((o) => !_isCurrent(o)).toList();

    // 3. Filter previous bookings based on selected status filter
    final filteredPreviousOrders = allPreviousOrders.where((o) {
      switch (_selectedFilter) {
        case ChefBookingFilter.all:
          return true;
        case ChefBookingFilter.completed:
          return o.isCompleted;
        case ChefBookingFilter.cancelledByChef:
          return o.isCancelledByChef;
        case ChefBookingFilter.cancelledByCustomer:
          return o.isCancelledByCustomer;
      }
    }).toList();

    String previousEmptyTitle;
    String previousEmptySubtitle;
    switch (_selectedFilter) {
      case ChefBookingFilter.all:
        previousEmptyTitle = 'No previous bookings yet';
        previousEmptySubtitle = 'Your past chef visits, receipts, and order summaries will be archived here.';
        break;
      case ChefBookingFilter.completed:
        previousEmptyTitle = 'No completed bookings';
        previousEmptySubtitle = 'Completed culinary visits and fulfilled dining sessions will appear here.';
        break;
      case ChefBookingFilter.cancelledByChef:
        previousEmptyTitle = 'No bookings cancelled by chef';
        previousEmptySubtitle = 'None of your chef bookings were cancelled or rejected by an assigned culinary partner.';
        break;
      case ChefBookingFilter.cancelledByCustomer:
        previousEmptyTitle = 'No bookings cancelled by you';
        previousEmptySubtitle = 'You have not cancelled any chef bookings.';
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chef Bookings',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Culinary visits & dining history',
              style: TextStyle(
                color: textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Bookings',
            onPressed: _fetchOrders,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(3.5),
            child: TabBar(
              controller: _tabController,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const MaterialStatePropertyAll(Colors.transparent),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              onTap: (_) => HapticFeedback.selectionClick(),
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.primaryLight.withOpacity(0.35)
                      : AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              tabs: [
                Tab(
                  child: _buildTabItem(
                    index: 0,
                    label: 'Current Bookings',
                    count: allCurrentOrders.length,
                    icon: Icons.soup_kitchen_rounded,
                    isDark: isDark,
                  ),
                ),
                Tab(
                  child: _buildTabItem(
                    index: 1,
                    label: 'Previous Bookings',
                    count: allPreviousOrders.length,
                    icon: Icons.history_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _orders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.slate400),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
                        const SizedBox(height: 16),
                        EbicButton(label: 'Retry', onPressed: _fetchOrders),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Current Bookings Tab (Live / Active)
                      _buildOrdersList(
                        allCurrentOrders,
                        emptyTitle: 'No current chef bookings',
                        emptySubtitle: 'Book a home chef for personalized dining cooked fresh in your kitchen.',
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                        secondaryEmptyAction: allPreviousOrders.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _tabController.animateTo(1);
                                  },
                                  icon: const Icon(Icons.history_rounded, size: 16),
                                  label: Text('View Past Bookings (${allPreviousOrders.length})'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // Previous Bookings Tab with status filters
                      Column(
                        children: [
                          _buildFilterChipsBar(allPreviousOrders, isDark),
                          Expanded(
                            child: _buildOrdersList(
                              filteredPreviousOrders,
                              emptyTitle: previousEmptyTitle,
                              emptySubtitle: previousEmptySubtitle,
                              isDark: isDark,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              textMuted: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, _) {
        final animValue = _tabController.animation?.value ?? _tabController.index.toDouble();
        final isSelected = animValue.round() == index;
        final textPrimary = isDark ? Colors.white : AppColors.slate900;
        final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                  : textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? textPrimary : textMuted,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primaryLight.withOpacity(0.2) : AppColors.primary)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? AppColors.primaryLight : Colors.white)
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChipsBar(List<OrderModel> previousOrders, bool isDark) {
    final allCount = previousOrders.length;
    final completedCount = previousOrders.where((o) => o.isCompleted).length;
    final cancelledByChefCount = previousOrders.where((o) => o.isCancelledByChef).length;
    final cancelledByCustomerCount = previousOrders.where((o) => o.isCancelledByCustomer).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterChip(
              filter: ChefBookingFilter.all,
              label: 'All Bookings',
              count: allCount,
              icon: Icons.receipt_long_rounded,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              filter: ChefBookingFilter.completed,
              label: 'Completed',
              count: completedCount,
              icon: Icons.check_circle_outline_rounded,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              filter: ChefBookingFilter.cancelledByChef,
              label: 'Cancelled by Chef',
              count: cancelledByChefCount,
              icon: Icons.person_off_outlined,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              filter: ChefBookingFilter.cancelledByCustomer,
              label: 'Cancelled by You',
              count: cancelledByCustomerCount,
              icon: Icons.cancel_outlined,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required ChefBookingFilter filter,
    required String label,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;

    final bgColor = isSelected
        ? (isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primary)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isSelected
        ? (isDark ? AppColors.primaryLight.withOpacity(0.55) : AppColors.primaryDark)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final textColor = isSelected
        ? (isDark ? AppColors.primaryLight : Colors.white)
        : (isDark ? AppColors.slate300 : AppColors.slate700);

    final iconColor = isSelected
        ? (isDark ? AppColors.primaryLight : Colors.white)
        : (isDark ? AppColors.slate400 : AppColors.slate500);

    final pillBg = isSelected
        ? (isDark ? AppColors.primaryLight.withOpacity(0.25) : Colors.white.withOpacity(0.25))
        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));

    final pillTextColor = isSelected
        ? (isDark ? AppColors.primaryLight : Colors.white)
        : (isDark ? AppColors.slate300 : AppColors.slate600);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedFilter = filter;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? (isDark ? 0.25 : 0.08) : (isDark ? 0.08 : 0.02)),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: pillTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    List<OrderModel> items, {
    required String emptyTitle,
    required String emptySubtitle,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    Widget? secondaryEmptyAction,
  }) {
    if (items.isEmpty) {
      final isAuthed = SessionManager().isAuthenticated;
      final displayTitle = isAuthed ? emptyTitle : 'Sign in to view orders';
      final displaySubtitle = isAuthed
          ? emptySubtitle
          : 'Your active and past chef bookings will appear here once you sign in.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isAuthed ? Icons.soup_kitchen_outlined : Icons.lock_outline_rounded,
                    size: 36,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                displaySubtitle,
                style: TextStyle(fontSize: 12, color: textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: isAuthed ? 160 : 190,
                child: EbicButton(
                  label: isAuthed ? 'Book a Chef' : 'Sign In to Account',
                  icon: isAuthed ? Icons.add : Icons.login_rounded,
                  onPressed: () {
                    if (!isAuthed) {
                      Navigator.pushNamed(context, AppRoutes.login);
                      return;
                    }
                    Navigator.pushNamed(context, AppRoutes.bookChef);
                  },
                ),
              ),
              if (secondaryEmptyAction != null) secondaryEmptyAction,
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        return _buildBentoOrderCard(
          context: ctx,
          order: items[idx],
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
          dateFormat: dateFormat,
        );
      },
    );
  }

  Widget _buildBentoOrderCard({
    required BuildContext context,
    required OrderModel order,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required DateFormat dateFormat,
  }) {
    final isCancelled = order.status.toUpperCase().contains('CANCEL');
    final isActive = !isCancelled &&
        order.status.toUpperCase() != 'COMPLETED' &&
        order.status.toUpperCase() != 'CLOSED';
    final hasEndOtp = isActive && order.statusStepIndex >= 4 && order.completionOtp != null;
    final hasStartOtp = isActive && !hasEndOtp && order.startOtp != null;
    final activeOtp = hasEndOtp ? order.completionOtp : (hasStartOtp ? order.startOtp : null);
    final otpLabel = hasEndOtp ? 'END OTP' : 'START OTP';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.pushNamed(
            context,
            AppRoutes.orderDetail,
            arguments: {'orderId': order.id, 'order': order},
          );
          if (mounted) _fetchOrders();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.primary.withOpacity(0.4) : AppColors.primary.withOpacity(0.25))
                  : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
              width: isActive ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.08)
                    : Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: isActive ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── BENTO CELL 1: Header (Ref, Occasion, Status, Date) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                order.bookingReference ?? order.id.substring(0, 10).toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                order.occasionLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 11.5, color: textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dateFormat.format(order.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: order.status),
                ],
              ),

              // Kitchen Address snippet if present
              if (order.address?.line1 != null && order.address!.line1.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.address!.label ?? "Kitchen"}: ${order.address!.line1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── BENTO CELL 2: 2-Column Bento Grid Row (Chef & OTP/Duration) ──
              Row(
                children: [
                  // Left Bento Cell: Executive Chef
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primarySubtle,
                            child: const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.chefName ?? (isActive ? 'Chef Assigned' : 'Executive Chef'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '4.9 ★ Certified',
                                      style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right Bento Cell: Security OTP or Prep Duration
                  Expanded(
                    flex: 5,
                    child: activeOtp != null
                        ? InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Clipboard.setData(ClipboardData(text: activeOtp));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$otpLabel copied to clipboard!'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: hasEndOtp
                                    ? (isDark ? const Color(0xFF2E1065) : const Color(0xFFFAF5FF))
                                    : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasEndOtp ? const Color(0xFFA855F7) : const Color(0xFF10B981),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        otpLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: hasEndOtp
                                              ? (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE))
                                              : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 11,
                                        color: hasEndOtp
                                            ? (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE))
                                            : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeOtp,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: hasEndOtp
                                          ? (isDark ? Colors.white : const Color(0xFF6B21A8))
                                          : (isDark ? Colors.white : const Color(0xFF065F46)),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PREP DURATION',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${order.cookingTimeMinutes} mins',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── BENTO CELL 3: Dishes Bento Strip ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    ...order.items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.dishName}',
                                        style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isFromDietPlan) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Diet Plan',
                                          style: TextStyle(fontSize: 8, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${item.price.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                    if (order.items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${order.items.length - 3} more dishes curated',
                            style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── BENTO CELL 4: Price & Bill Strip ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_rounded, size: 13, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.isInstant ? 'Instant Cook Fee' : 'Total Service Bill',
                        style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── BENTO CELL 5: Action Buttons ──
              if (isActive) ...[
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text(
                      'Track Chef Live on GPS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.chefTracking,
                        arguments: {'orderId': order.id},
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : AppColors.slate800,
                        side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.primary),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Booking Details',
                          maxLines: 1,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await Navigator.pushNamed(
                          context,
                          AppRoutes.orderDetail,
                          arguments: {'orderId': order.id, 'order': order},
                        );
                        if (mounted) _fetchOrders();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.slate800,
                        side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.checklist_rtl_rounded, size: 15, color: AppColors.primary),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ingredient Checklist',
                          maxLines: 1,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(
                          context,
                          AppRoutes.preparationChecklist,
                          arguments: {'orderId': order.id},
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Tap anywhere on card to view complete chef booking details →',
                  style: TextStyle(fontSize: 10, color: AppColors.slate400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

