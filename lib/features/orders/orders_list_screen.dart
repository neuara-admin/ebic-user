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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    });

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.orders);
      if (res.success && res.data != null) {
        final rawList = res.data!['orders'] as List<dynamic>? ?? [];
        setState(() {
          _orders = rawList
              .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Section 48 Tabs: Upcoming, Active, Completed
    final activeOrders = _orders.where((o) =>
        o.status == 'CHEF_ASSIGNED' ||
        o.status == 'CHEF_EN_ROUTE' ||
        o.status == 'CHEF_ARRIVED' ||
        o.status == 'IN_PROGRESS' ||
        o.status == 'PLATING').toList();

    final upcomingOrders = _orders.where((o) =>
        o.status == 'DRAFT' ||
        o.status == 'PENDING' ||
        o.status == 'CONFIRMED').toList();

    final completedOrders = _orders.where((o) =>
        o.status == 'COMPLETED' ||
        o.status == 'CANCELLED').toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Chef Bookings & Orders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(activeOrders, emptyTitle: 'No active chef dispatches', emptySubtitle: 'When a chef is en route or cooking, track live status here.'),
                  _buildOrdersList(upcomingOrders, emptyTitle: 'No upcoming chef bookings', emptySubtitle: 'Your confirmed chef sessions will appear here.'),
                  _buildOrdersList(completedOrders, emptyTitle: 'No completed bookings yet', emptySubtitle: 'Historical completed chef visits and receipts will appear here.'),
                ],
              ),
            ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> items, {required String emptyTitle, required String emptySubtitle}) {
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
                  color: AppColors.slate200,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.slate500)),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final order = items[idx];
        final isActive = order.status != 'COMPLETED' && order.status != 'CANCELLED';

        return EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.bookingReference ?? order.id.substring(0, 10).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(order.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const Divider(height: 20),

              // Items summary
              ...order.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.dishName}',
                          style: const TextStyle(fontSize: 13, color: AppColors.slate700, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, color: AppColors.slate800, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
              if (order.items.length > 3)
                Text(
                  '+${order.items.length - 3} more dishes',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              const Divider(height: 20),

              // Total & Cooking time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: AppColors.slate400),
                      const SizedBox(width: 4),
                      Text(
                        '${order.cookingTimeMinutes} mins cooking',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                      ),
                    ],
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons (Section 48 & 49)
              Row(
                children: [
                  Expanded(
                    child: EbicButton(
                      label: isActive ? 'Track Chef' : 'View Details',
                      icon: isActive ? Icons.navigation_outlined : Icons.receipt_outlined,
                      onPressed: () {
                        if (isActive) {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.chefTracking,
                            arguments: {'orderId': order.id},
                          );
                        } else {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.orderDetail,
                            arguments: {'orderId': order.id},
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EbicButton(
                      label: 'Prep Checklist',
                      icon: Icons.checklist_rtl_rounded,
                      variant: EbicButtonVariant.outline,
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
            ],
          ),
        );
      },
    );
  }
}
