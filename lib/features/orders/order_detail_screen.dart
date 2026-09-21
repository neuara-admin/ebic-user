import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final OrderModel? initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiClient _api = ApiClient();
  OrderModel? _order;
  List<dynamic>? _timeline;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _isLoading = widget.initialOrder == null;
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    if (_order == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Fetch primary order / chef booking details
      var res = await _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(widget.orderId));
      if (!res.success || res.data == null) {
        res = await _api.get<Map<String, dynamic>>(ApiEndpoints.chefBooking(widget.orderId));
      }

      // 2. Fetch timeline if available
      try {
        final timelineRes = await _api.get<List<dynamic>>(ApiEndpoints.chefBookingTimeline(widget.orderId));
        if (timelineRes.success && timelineRes.data != null) {
          _timeline = timelineRes.data;
        }
      } catch (_) {}

      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _order = OrderModel.fromJson(res.data!);
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted && _order == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = res.message ?? 'Failed to load booking details';
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted && _order == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isOrderActive {
    if (_order == null) return false;
    return !_order!.isCancelled && _order!.status.toUpperCase() != 'COMPLETED';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.slate950 : const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Chef Booking Details'), elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.slate950 : const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Chef Booking Details'), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Booking not found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                const SizedBox(height: 16),
                EbicButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _fetchOrderDetail,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _isOrderActive;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.isInstant ? 'Instant Cook Dispatch' : 'Chef Booking Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              order.bookingReference != null
                  ? '${order.bookingReference!} • ${order.isInstant ? "On-Demand Dispatch" : order.occasionLabel}'
                  : (order.isInstant ? 'On-Demand Dispatch' : order.occasionLabel),
              style: const TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchOrderDetail,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, order, isActive, isDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchOrderDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Status & Tracking Banner
                _buildHeroStatusCard(context, order, isActive, isDark, dateFormat),
                const SizedBox(height: 14),

                // 2. Start OTP Card (if active and available)
                if (order.startOtp != null && isActive && order.statusStepIndex < 4) ...[
                  _buildOtpCard(context, order.startOtp!, isDark),
                  const SizedBox(height: 14),
                ],

                // 3. Assigned Executive Chef Card
                _buildChefProfileCard(context, order, isDark),
                const SizedBox(height: 14),

                // 4. Booking Summary Card
                _buildBookingSummaryCard(context, order, isDark, dateFormat),
                const SizedBox(height: 14),

                // 5. Attending Members & Curated Dishes Breakdown
                _buildDishesBreakdownCard(context, order, isDark),
                const SizedBox(height: 14),

                // 6. Pantry & Ingredient Preparation Checklist Card
                _buildIngredientChecklistCard(context, order, isDark),
                const SizedBox(height: 14),

                // 7. Payment & Price Breakdown Card
                _buildFinancialBreakdownCard(context, order, isDark),
                const SizedBox(height: 20),

                // 8. Secondary Actions
                _buildSecondaryActions(context, order, isActive),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(
    BuildContext context,
    OrderModel order,
    bool isActive,
    bool isDark,
    DateFormat dateFormat,
  ) {
    final isCancelled = order.isCancelled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isCancelled
            ? const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isCancelled ? AppColors.danger : AppColors.primary).withOpacity(0.35),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCancelled
                            ? Icons.error_outline_rounded
                            : (isActive ? Icons.navigation_rounded : Icons.check_circle_rounded),
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          order.isInstant ? 'INSTANT DISPATCH' : order.occasionLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCancelled ? AppColors.danger : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      StatusBadge.formatStatus(order.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isCancelled ? AppColors.danger : AppColors.primaryDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.customerStatusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.status.toUpperCase() == 'FAILED_NO_SUPPLY'
                ? 'No executive chef was available in your area. Your payment is 100% refunded.'
                : isCancelled
                    ? 'This booking was cancelled.'
                    : (order.isInstant && isActive
                        ? (order.promisedEtaAt != null
                            ? 'Instant Dispatch • Arriving by ${DateFormat('hh:mm a').format(order.promisedEtaAt!)}'
                            : 'Instant Dispatch • Chef arriving in ~15-20 mins')
                        : (order.promisedEtaAt != null
                            ? 'Expected Arrival: ${dateFormat.format(order.promisedEtaAt!)}'
                            : 'Booked on ${dateFormat.format(order.createdAt)}')),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showTimelineSheet(context, order),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.32)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timeline_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'View Complete Status & Milestones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.white),
                ],
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18, color: AppColors.primary),
                    label: Text(
                      order.isInstant ? 'Track Instant Dispatch' : 'Track Chef Live on GPS',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showTimelineSheet(BuildContext context, OrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeIndex = order.statusStepIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Booking Dispatch Milestones',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            order.bookingReference ?? 'Booking #${order.id.substring(0, 8)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    if (_timeline != null && _timeline!.isNotEmpty) ...[
                      ...List.generate(_timeline!.length, (idx) {
                        final item = _timeline![idx] as Map<String, dynamic>;
                        final title = item['title']?.toString() ?? 'Milestone';
                        final desc = item['description']?.toString() ?? '';
                        final status = item['status']?.toString() ?? 'DONE';
                        final isDone = status == 'DONE';
                        final isLast = idx == _timeline!.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isDone ? Icons.check : Icons.circle,
                                    size: isDone ? 14 : 8,
                                    color: isDone ? Colors.white : AppColors.slate400,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 42,
                                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isDone ? (isDark ? Colors.white : AppColors.slate900) : AppColors.slate400,
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ] else ...[
                      ...[
                        {'label': 'Booking Confirmed', 'desc': 'Order verified & culinary slot secured'},
                        {'label': 'Executive Chef Assigned', 'desc': 'Verified chef assigned & hygiene certified'},
                        {'label': 'Chef En Route', 'desc': 'Executive chef is travelling to your kitchen'},
                        {'label': 'Arrived at Doorstep', 'desc': 'Chef reached kitchen destination'},
                        {'label': 'Cooking in Progress', 'desc': 'Healthy dishes crafted in your kitchen'},
                        {'label': 'Plating & Table Setup', 'desc': 'Garnishing and dining presentation'},
                        {'label': 'Completed & Sanitized', 'desc': 'Kitchen cleaned and service completed'},
                      ].asMap().entries.map((entry) {
                        final idx = entry.key;
                        final step = entry.value;
                        final isDone = idx <= activeIndex;
                        final isLast = idx == 6;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isDone ? Icons.check : Icons.circle,
                                    size: isDone ? 14 : 8,
                                    color: isDone ? Colors.white : AppColors.slate400,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 42,
                                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step['label']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isDone ? (isDark ? Colors.white : AppColors.slate900) : AppColors.slate400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      step['desc']!,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtpCard(BuildContext context, String otp, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.key_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHEF ARRIVAL OTP',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  otp,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Share with chef upon arrival to initiate cooking',
                  style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF047857), size: 20),
            tooltip: 'Copy OTP',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: otp));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chef arrival OTP copied to clipboard'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChefProfileCard(BuildContext context, OrderModel order, bool isDark) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ASSIGNED EXECUTIVE CHEF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981), width: 0.6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Color(0xFF047857)),
                    SizedBox(width: 3),
                    Text(
                      'Hygiene Certified',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.chefName ?? 'Executive Culinary Specialist',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                        SizedBox(width: 2),
                        Text(
                          '4.9 ★ • 200+ Visits • Clean Kit',
                          style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
                ),
                tooltip: 'Call Chef',
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: '+919876543210'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chef contact +91 98765 43210 copied!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryCard(
    BuildContext context,
    OrderModel order,
    bool isDark,
    DateFormat dateFormat,
  ) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'BOOKING SUMMARY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate600,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (order.bookingReference != null) {
                    Clipboard.setData(ClipboardData(text: order.bookingReference!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${order.bookingReference} to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        order.bookingReference ?? order.id,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: AppColors.slate500),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2x2 Grid of Key Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800.withOpacity(0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryGridItem(
                        icon: Icons.electric_bolt_rounded,
                        label: 'Service Mode',
                        value: order.orderTypeLabel,
                        isDark: isDark,
                      ),
                    ),
                    Container(width: 1, height: 44, color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildSummaryGridItem(
                          icon: Icons.restaurant_rounded,
                          label: 'Dining Occasion',
                          value: order.occasionLabel,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(height: 20, color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryGridItem(
                        icon: Icons.calendar_month_rounded,
                        label: order.isInstant ? 'Arrival Window' : 'Scheduled Slot',
                        value: order.isInstant
                            ? (order.promisedEtaAt != null
                                ? 'Arriving by ${DateFormat('hh:mm a').format(order.promisedEtaAt!)}'
                                : 'Immediate (~20 mins)')
                            : (order.promisedEtaAt != null
                                ? dateFormat.format(order.promisedEtaAt!)
                                : dateFormat.format(order.createdAt)),
                        isDark: isDark,
                      ),
                    ),
                    Container(width: 1, height: 44, color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildSummaryGridItem(
                          icon: Icons.timer_outlined,
                          label: 'Chef Cook Duration',
                          value: '${order.cookingTimeMinutes} mins in kitchen',
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Kitchen Address Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.address?.label ?? 'Designated Home Kitchen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.address?.fullAddress ?? 'Designated Kitchen Destination, Bangalore',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (order.cookingNotes != null && order.cookingNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kitchen Instructions: ${order.cookingNotes}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (order.allergyAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Allergy Alerts: ${order.allergyAlerts.join(", ")}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryGridItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.slate500, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate900,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDishesBreakdownCard(BuildContext context, OrderModel order, bool isDark) {
    final allDishes = order.meals.expand((m) => m.dishes).toList();
    final totalPortions = allDishes.fold<int>(0, (sum, d) => sum + d.servings);
    final totalDishesCount = allDishes.isNotEmpty ? allDishes.length : order.items.length;

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'SELECTED DISHES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate600,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalDishesCount ${totalDishesCount == 1 ? "Dish" : "Dishes"} • ${totalPortions > 0 ? totalPortions : totalDishesCount} Portions',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (order.meals.isNotEmpty) ...[
            ...order.meals.map((meal) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: AppColors.primarySubtle,
                                child: const Icon(Icons.person, size: 15, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  meal.memberDisplayName,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.slate900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${meal.dishes.length} ${meal.dishes.length == 1 ? "Dish" : "Dishes"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppColors.slate700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of dishes for this member
                    ...meal.dishes.map((dish) {
                      return _buildDishItemCard(dish: dish, isDark: isDark);
                    }),
                  ],
                ),
              );
            }),
          ] else ...[
            // Fallback to order.items
            ...order.items.map((item) {
              return _buildOrderItemCard(item: item, isDark: isDark);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDishItemCard({required OrderMealDishModel dish, required bool isDark}) {
    final price = dish.price > 0 ? dish.price : (dish.servings * 199.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.restaurant_rounded, size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.dishName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    if (dish.description != null && dish.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dish.description!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate500, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const Text(
                    'Prep Included',
                    style: TextStyle(fontSize: 9.5, color: AppColors.slate400, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildDishTag(
                icon: Icons.people_alt_outlined,
                label: '${dish.servings} ${dish.servings == 1 ? "Portion" : "Portions"}',
                color: AppColors.primary,
                bgColor: AppColors.primarySubtle,
              ),
              _buildDishTag(
                icon: Icons.timer_outlined,
                label: '${dish.cookTimeMin}m Cook Time',
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
              if (dish.cuisine != null && dish.cuisine!.isNotEmpty)
                _buildDishTag(
                  icon: Icons.local_dining_outlined,
                  label: dish.cuisine!,
                  color: const Color(0xFF6366F1),
                  bgColor: const Color(0xFFEEF2FF),
                ),
              if (dish.isFromDietPlan)
                _buildDishTag(
                  icon: Icons.verified_rounded,
                  label: 'Dietitian Approved',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard({required OrderItemModel item, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.dishName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
              Text(
                '₹${item.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildDishTag(
                icon: Icons.people_alt_outlined,
                label: '${item.quantity} ${item.quantity == 1 ? "Portion" : "Portions"}',
                color: AppColors.primary,
                bgColor: AppColors.primarySubtle,
              ),
              if (item.cookTimeMin != null && item.cookTimeMin! > 0)
                _buildDishTag(
                  icon: Icons.timer_outlined,
                  label: '${item.cookTimeMin}m Cook Time',
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              if (item.cuisine != null && item.cuisine!.isNotEmpty)
                _buildDishTag(
                  icon: Icons.local_dining_outlined,
                  label: item.cuisine!,
                  color: const Color(0xFF6366F1),
                  bgColor: const Color(0xFFEEF2FF),
                ),
              if (item.isFromDietPlan)
                _buildDishTag(
                  icon: Icons.verified_rounded,
                  label: 'Dietitian Approved',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDishTag({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientChecklistCard(BuildContext context, OrderModel order, bool isDark) {
    return EbicCard(
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredient Preparation Checklist',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Check off required ingredients & kitchen pantry items',
                  style: TextStyle(color: AppColors.slate500, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdownCard(BuildContext context, OrderModel order, bool isDark) {
    const chefVisitFee = 249.0;
    final prepFee = order.priceSubtotal > chefVisitFee ? (order.priceSubtotal - chefVisitFee) : 398.0;

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'PRICING & BILL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate600,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981), width: 0.6),
                ),
                child: const Text(
                  'Tax Invoice',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildDetailRow(
            'Executive Chef Home Visit Fee',
            '₹${chefVisitFee.toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Selected Recipe Culinary Preparation',
            '₹${prepFee.toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Subtotal (Culinary & Visit)',
            '₹${order.priceSubtotal.toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Applicable Taxes & GST (5%)',
            '₹${order.priceGst.toStringAsFixed(0)}',
            isDark,
          ),
          if (order.couponDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Promo / Coupon Discount',
                    style: TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '-₹${order.couponDiscount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (order.walletDeduction > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'EBIC Health Wallet Applied',
                    style: TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '-₹${order.walletDeduction.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Amount Paid',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.paymentMode != null
                        ? 'Pre-paid Online via ${order.paymentMode}'
                        : 'Pre-paid Online via UPI / Razorpay (Confirmed)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.slate700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActions(BuildContext context, OrderModel order, bool isActive) {
    return Column(
      children: [
        if (isActive) ...[
          EbicButton(
            label: 'Cancel Chef Booking',
            variant: EbicButtonVariant.danger,
            icon: Icons.cancel_outlined,
            onPressed: () {
              CancelBookingDialog.show(
                context,
                orderId: order.id,
                onCancelled: _fetchOrderDetail,
              );
            },
          ),
          const SizedBox(height: 10),
        ] else if (order.status.toUpperCase() == 'COMPLETED') ...[
          EbicButton(
            label: 'Rate Chef Experience',
            icon: Icons.star_rate_rounded,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => RateOrderDialog(
                  orderId: order.id,
                  chefName: order.chefName ?? 'Executive Chef',
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        EbicButton(
          label: 'Contact Support Assistance',
          icon: Icons.support_agent_rounded,
          variant: EbicButtonVariant.ghost,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
        ),
      ],
    );
  }

  Widget? _buildBottomBar(BuildContext context, OrderModel order, bool isActive, bool isDark) {
    if (!isActive) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text(
              'Track Chef Live on GPS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate500, fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            color: isDark ? Colors.white : AppColors.slate800,
          ),
        ),
      ],
    );
  }
}
