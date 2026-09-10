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
import '../chef_booking/cancel_booking_dialog.dart';
import 'rate_order_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiClient _api = ApiClient();
  OrderModel? _order;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(widget.orderId));
      if (res.success && res.data != null) {
        setState(() {
          _order = OrderModel.fromJson(res.data!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message ?? 'Failed to load booking details';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Order not found', style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              EbicButton(label: 'Retry', onPressed: _fetchOrderDetail),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isActive = order.status != 'COMPLETED' && order.status != 'CANCELLED';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text(order.bookingReference ?? 'Booking Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrderDetail,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              EbicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.bookingReference ?? order.id.toUpperCase(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateFormat.format(order.createdAt),
                      style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                    ),
                    const Divider(height: 20),
                    _buildRow('Booking Mode', order.orderType == 'INSTANT' ? 'Instant Dispatch (V1)' : 'Scheduled Visit'),
                    const SizedBox(height: 6),
                    _buildRow('Assigned Chef', order.chefName ?? 'Assigned Executive Chef'),
                    const SizedBox(height: 6),
                    _buildRow('Estimated Cooking Time', '${order.cookingTimeMinutes} minutes'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Items Ordered (Section 49)
              const Text('Dishes & Portions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              EbicCard(
                child: Column(
                  children: order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.dishName}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800),
                            ),
                          ),
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Preparation Checklist Quick Access
              EbicCard(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.preparationChecklist,
                    arguments: {'orderId': order.id},
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingredient Preparation Checklist',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Track ingredients and kitchen prep for your chef',
                            style: TextStyle(color: AppColors.slate500, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Authoritative Price Breakdown (Section 36 & 49)
              const Text('Payment & Price Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              EbicCard(
                child: Column(
                  children: [
                    _buildRow('Chef Service Fee', '₹${(order.totalAmount * 0.4).toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    _buildRow('Culinary Dispatches & Prep', '₹${(order.totalAmount * 0.6).toStringAsFixed(0)}'),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              if (isActive) ...[
                EbicButton(
                  label: 'Track Chef Live',
                  icon: Icons.navigation_outlined,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.chefTracking,
                      arguments: {'orderId': order.id},
                    );
                  },
                ),
                const SizedBox(height: 10),
                EbicButton(
                  label: 'Cancel Booking',
                  variant: EbicButtonVariant.danger,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => CancelBookingDialog(
                        orderId: order.id,
                        onCancelled: _fetchOrderDetail,
                      ),
                    );
                  },
                ),
              ] else if (order.status == 'COMPLETED') ...[
                EbicButton(
                  label: 'Rate Your Chef',
                  icon: Icons.star_rate_rounded,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RateOrderDialog(
                        orderId: order.id,
                        chefName: order.chefName ?? 'Chef',
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),

              EbicButton(
                label: 'Contact Support',
                icon: Icons.support_agent_rounded,
                variant: EbicButtonVariant.ghost,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate800)),
      ],
    );
  }
}
