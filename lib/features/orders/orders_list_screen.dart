import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

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

  String _currentFilter = 'ALL';
  String _previousFilter = 'ALL';

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
        setState(() {
          _orders = rawList
              .map((json) => OrderModel.fromJson(json is Map<String, dynamic> ? json : {}))
              .toList();
          _isLoading = false;
        });
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

    // Apply Filters
    final filteredCurrent = allCurrentOrders.where((o) {
      if (_currentFilter == 'EN_ROUTE') {
        return o.status == 'CHEF_EN_ROUTE' || o.status == 'EN_ROUTE' || o.status == 'CHEF_ARRIVED' || o.status == 'ARRIVED';
      } else if (_currentFilter == 'COOKING') {
        return o.status == 'IN_PROGRESS' || o.status == 'COOKING' || o.status == 'PLATING';
      } else if (_currentFilter == 'SCHEDULED') {
        return o.status == 'DRAFT' || o.status == 'CREATED' || o.status == 'SEARCHING' || o.status == 'CONFIRMED' || o.status == 'PENDING';
      }
      return true;
    }).toList();

    final filteredPrevious = allPreviousOrders.where((o) {
      if (_previousFilter == 'COMPLETED') {
        return o.status == 'COMPLETED';
      } else if (_previousFilter == 'CANCELLED') {
        return o.isCancelled;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text('Chef Bookings & Orders', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
          indicatorColor: isDark ? AppColors.primaryLight : AppColors.primary,
          tabs: [
            Tab(text: 'Current Bookings (${allCurrentOrders.length})'),
            Tab(text: 'Previous Bookings (${allPreviousOrders.length})'),
          ],
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
                      // Current Bookings Tab
                      Column(
                        children: [
                          _buildFilterRow(
                            chips: [
                              {'id': 'ALL', 'label': 'All Current'},
                              {'id': 'EN_ROUTE', 'label': 'En Route / Arriving'},
                              {'id': 'COOKING', 'label': 'Cooking Now'},
                              {'id': 'SCHEDULED', 'label': 'Upcoming Scheduled'},
                            ],
                            selectedId: _currentFilter,
                            onSelected: (id) => setState(() => _currentFilter = id),
                            isDark: isDark,
                          ),
                          Expanded(
                            child: _buildOrdersList(
                              filteredCurrent,
                              emptyTitle: 'No current chef bookings',
                              emptySubtitle: 'Book a home chef for personalized dining cooked fresh in your kitchen.',
                              isDark: isDark,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              textMuted: textMuted,
                            ),
                          ),
                        ],
                      ),

                      // Previous Bookings Tab
                      Column(
                        children: [
                          _buildFilterRow(
                            chips: [
                              {'id': 'ALL', 'label': 'All Previous'},
                              {'id': 'COMPLETED', 'label': 'Completed'},
                              {'id': 'CANCELLED', 'label': 'Cancelled'},
                            ],
                            selectedId: _previousFilter,
                            onSelected: (id) => setState(() => _previousFilter = id),
                            isDark: isDark,
                          ),
                          Expanded(
                            child: _buildOrdersList(
                              filteredPrevious,
                              emptyTitle: 'No previous bookings yet',
                              emptySubtitle: 'Your past chef visits, receipts, and order summaries will be archived here.',
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

  Widget _buildFilterRow({
    required List<Map<String, String>> chips,
    required String selectedId,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.slate900 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) {
            final isSelected = c['id'] == selectedId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  c['label']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.slate700),
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                onSelected: (_) => onSelected(c['id']!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
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
  }) {
    if (items.isEmpty) {
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
                child: Center(child: Icon(Icons.soup_kitchen_outlined, size: 36, color: textMuted)),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: TextStyle(fontSize: 12, color: textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 160,
                child: EbicButton(
                  label: 'Book a Chef',
                  icon: Icons.add,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChef),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        final order = items[idx];
        final isCancelled = order.status.toUpperCase().contains('CANCEL');
        final isActive = !isCancelled &&
            order.status.toUpperCase() != 'COMPLETED' &&
            order.status.toUpperCase() != 'CLOSED';

        return EbicCard(
          onTap: () async {
            await Navigator.pushNamed(
              context,
              AppRoutes.orderDetail,
              arguments: {'orderId': order.id, 'order': order},
            );
            if (mounted) _fetchOrders();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Booking Ref & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.bookingReference ?? order.id.substring(0, 10).toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),

              // Date, Occasion, and OTP Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${dateFormat.format(order.createdAt)} • ${order.occasionLabel}',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                  if (order.startOtp != null && isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key_rounded, size: 11, color: Color(0xFF047857)),
                          const SizedBox(width: 4),
                          Text(
                            'OTP: ${order.startOtp}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Address snippet if available
              if (order.address?.line1 != null && order.address!.line1.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${order.address!.label ?? "Kitchen"}: ${order.address!.line1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ],
              Divider(height: 16, color: isDark ? AppColors.slate800 : AppColors.slate200),

              // Assigned Chef Info Row (if assigned or active)
              if (order.assignedChef != null || isActive) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySubtle,
                      child: const Icon(Icons.person, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.chefName ?? 'Executive Chef Assigned',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const Text('Certified EBIC Chef • 4.9 ★', style: TextStyle(fontSize: 10.5, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: order.isInstant
                            ? AppColors.primarySubtle
                            : (isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.isInstant ? 'Instant Cook' : 'Scheduled',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: order.isInstant ? AppColors.primaryDark : AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Items summary in a styled card container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800.withOpacity(0.5) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    ...order.items.take(3).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${item.quantity}x ${item.dishName}',
                                        style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w600),
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
                                          style: TextStyle(fontSize: 8.5, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${item.price.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12.5, color: textPrimary, fontWeight: FontWeight.bold),
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
                            style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 16, color: isDark ? AppColors.slate800 : AppColors.slate200),

              // Total & Cooking time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${order.cookingTimeMinutes} mins prep & cook',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons (2-Tier Non-Overflowing Responsive Layout)
              if (isActive) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Track Chef Live on GPS',
                        maxLines: 1,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: () {
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
        );
      },
    );
  }
}
