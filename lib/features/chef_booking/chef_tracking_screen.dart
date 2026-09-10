import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';
import 'add_items_sheet.dart';
import 'cancel_booking_dialog.dart';

class ChefTrackingScreen extends StatefulWidget {
  final String orderId;

  const ChefTrackingScreen({super.key, required this.orderId});

  @override
  State<ChefTrackingScreen> createState() => _ChefTrackingScreenState();
}

class _ChefTrackingScreenState extends State<ChefTrackingScreen> {
  final ApiClient _api = ApiClient();
  Timer? _pollingTimer;
  OrderModel? _order;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
    // Poll every 8s for live chef movements and status transitions (Section 68)
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchOrder(isBackground: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrder({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(widget.orderId));
      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _order = OrderModel.fromJson(res.data!);
            _isLoading = false;
          });
        }
      } else {
        if (!isBackground && mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = res.message ?? 'Unable to fetch booking tracking info';
          });
        }
      }
    } catch (e) {
      if (!isBackground && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Section 45 Timeline Steps
  final List<Map<String, dynamic>> _steps = [
    {'status': 'CONFIRMED', 'label': 'Booking Confirmed', 'desc': 'Order verified & slotted'},
    {'status': 'CHEF_ASSIGNED', 'label': 'Chef Assigned', 'desc': 'Executive chef assigned automatically'},
    {'status': 'CHEF_EN_ROUTE', 'label': 'Chef Departed', 'desc': 'Chef is travelling to your kitchen'},
    {'status': 'CHEF_ARRIVED', 'label': 'Chef Arrived', 'desc': 'Chef reached your doorstep'},
    {'status': 'IN_PROGRESS', 'label': 'Cooking', 'desc': 'Dishes being crafted in your kitchen'},
    {'status': 'PLATING', 'label': 'Plating', 'desc': 'Garnishing and table presentation'},
    {'status': 'COMPLETED', 'label': 'Completed', 'desc': 'Kitchen sanitized and order done'},
  ];

  int _getStepIndex(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
      case 'PENDING':
      case 'CONFIRMED':
        return 0;
      case 'CHEF_ASSIGNED':
      case 'ACCEPTED':
        return 1;
      case 'CHEF_EN_ROUTE':
      case 'EN_ROUTE':
        return 2;
      case 'CHEF_ARRIVED':
      case 'ARRIVED':
        return 3;
      case 'IN_PROGRESS':
      case 'COOKING':
        return 4;
      case 'PLATING':
        return 5;
      case 'COMPLETED':
        return 6;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _order?.status ?? 'CHEF_EN_ROUTE';
    final isCancelled = currentStatus == 'CANCELLED';
    final activeIndex = _getStepIndex(currentStatus);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Chef Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchOrder(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _order == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      EbicButton(label: 'Retry', onPressed: () => _fetchOrder()),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchOrder(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live ETA Hero Header (Section 46: Backend-controlled ETA)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: isCancelled ? AppColors.darkGradient : AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isCancelled ? 'BOOKING CANCELLED' : 'CHEF EN ROUTE',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  StatusBadge(status: currentStatus),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (!isCancelled) ...[
                                Text(
                                  'Estimated Arrival in ~${_order?.etaMinutes ?? 18} mins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'ETA determined automatically by real-time traffic and routing engine.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ] else ...[
                                const Text(
                                  'This booking was cancelled.',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Assigned Chef Info Card (Customer NEVER selects chef, Section 44)
                        EbicCard(
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 32),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _order?.chefName ?? 'Chef Vikram Rathore',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Certified EBIC Executive Chef • 4.9 ★',
                                      style: TextStyle(color: AppColors.slate500, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Temperature Checked & Sanitized',
                                        style: TextStyle(color: AppColors.emerald700, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Quick Access Actions
                        Row(
                          children: [
                            Expanded(
                              child: EbicButton(
                                label: 'Prep Checklist',
                                icon: Icons.checklist_rtl_rounded,
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.preparationChecklist,
                                    arguments: {'orderId': widget.orderId},
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EbicButton(
                                label: 'Add Items',
                                icon: Icons.add_circle_outline,
                                variant: EbicButtonVariant.outline,
                                onPressed: isCancelled
                                    ? null
                                    : () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => AddItemsSheet(
                                            orderId: widget.orderId,
                                            onItemsAdded: () => _fetchOrder(),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Status Progression Timeline (Section 45)
                        const Text(
                          'Dispatch Timeline',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                        ),
                        const SizedBox(height: 16),

                        ...List.generate(_steps.length, (idx) {
                          final step = _steps[idx];
                          final isDone = !isCancelled && idx <= activeIndex;
                          final isCurrent = !isCancelled && idx == activeIndex;
                          final isLast = idx == _steps.length - 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? AppColors.primary
                                          : AppColors.slate200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: isDone
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : Text(
                                              '${idx + 1}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold),
                                            ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 36,
                                      color: isDone && idx < activeIndex ? AppColors.primary : AppColors.slate200,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step['label'],
                                        style: TextStyle(
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                          color: isCurrent
                                              ? AppColors.primaryDark
                                              : (isDone ? AppColors.slate900 : AppColors.slate400),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        step['desc'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isCurrent ? AppColors.slate700 : AppColors.slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),

                        const SizedBox(height: 16),
                        if (!isCancelled) ...[
                          Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                              label: const Text('Cancel Booking', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => CancelBookingDialog(
                                    orderId: widget.orderId,
                                    onCancelled: () => _fetchOrder(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
