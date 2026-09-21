import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/quote_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> confirmationData;

  const BookingConfirmationScreen({super.key, required this.confirmationData});

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _liveOrder;
  bool _isLoadingLive = true;

  final LatLng _kitchenLocation = const LatLng(12.9716, 77.5946);
  final LatLng _chefLocation = const LatLng(12.9850, 77.6100);
  late Set<Marker> _previewMarkers;
  late Set<Polyline> _previewPolylines;

  @override
  void initState() {
    super.initState();
    _previewMarkers = {
      Marker(
        markerId: const MarkerId('kitchen'),
        position: _kitchenLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('chef'),
        position: _chefLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };
    _previewPolylines = {
      Polyline(
        polylineId: const PolylineId('preview_route'),
        points: [
          _chefLocation,
          LatLng(_chefLocation.latitude - 0.004, _chefLocation.longitude - 0.004),
          LatLng(_kitchenLocation.latitude + 0.005, _kitchenLocation.longitude + 0.005),
          _kitchenLocation,
        ],
        color: AppColors.primary,
        width: 4,
      ),
    };
    _fetchLiveBookingDetails();
  }

  Future<void> _fetchLiveBookingDetails() async {
    final orderId = widget.confirmationData['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) {
      if (mounted) setState(() => _isLoadingLive = false);
      return;
    }

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(orderId));
      if (res.success && res.data != null) {
        if (mounted) {
          setState(() {
            _liveOrder = res.data;
            _isLoadingLive = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingLive = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.confirmationData['orderId']?.toString() ?? 'EBIC-8829';
    final cookingTime = widget.confirmationData['cookingTime']?.toString() ?? '35';
    final total = widget.confirmationData['total'] ?? 0.0;
    final paymentMethod = widget.confirmationData['paymentMethod']?.toString() ?? 'GATEWAY';

    // Live or Passed Details
    final bookingNumber = _liveOrder?['bookingNumber']?.toString() ??
        (orderId.length > 8 ? 'CB-${orderId.substring(0, 6).toUpperCase()}' : orderId);
    final startOtp = _liveOrder?['startOtp']?.toString() ?? '4829';
    final chefName = _liveOrder?['assignedChef']?['name']?.toString() ??
        widget.confirmationData['chefName']?.toString() ??
        'Chef Rajesh Kumar';
    final arrivalMinutes = _liveOrder?['visitCookTimeMin']?.toString() ?? '20';

    final dishes = (widget.confirmationData['dishes'] as List<dynamic>?) ?? [];
    final quote = widget.confirmationData['quote'] as QuoteModel?;
    final addressLine = widget.confirmationData['addressLine']?.toString() ??
        widget.confirmationData['address']?['street']?.toString() ??
        'Kitchen Location, Current Residence';
    final memberName = widget.confirmationData['memberName']?.toString() ?? 'Self';
    final isCancelled = (_liveOrder?['status']?.toString().toUpperCase() ?? '').contains('CANCEL');

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            'Booking Confirmed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate900),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.slate700),
              tooltip: 'Close & Return Home',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingLive)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
                  ),

                // 1. Success & OTP Celebration Banner
                _buildCelebrationHeader(bookingNumber, startOtp),
                const SizedBox(height: 16),

                // 2. Live GPS Tracking & Chef Dispatch Card
                _buildLiveGpsCard(chefName, arrivalMinutes, orderId, isCancelled),
                const SizedBox(height: 16),

                // 3. Booked Dishes & Portions Card
                _buildDishesCard(dishes, quote),
                const SizedBox(height: 16),

                // 4. Household Member & Care Details
                _buildMemberCard(memberName),
                const SizedBox(height: 16),

                // 5. Kitchen Service Address Card
                _buildAddressCard(addressLine),
                const SizedBox(height: 16),

                // 6. Pricing & Payment Breakdown
                _buildPriceBreakdownCard(total, paymentMethod, quote, cookingTime),
                const SizedBox(height: 16),

                // 7. Kitchen Preparation Instructions
                _buildPrepInstructionsCard(),
                const SizedBox(height: 24),

                // 8. Action Buttons
                EbicButton(
                  label: isCancelled ? 'Chef Booking Cancelled' : 'Track Chef on Live GPS',
                  icon: isCancelled ? Icons.cancel_rounded : Icons.navigation_rounded,
                  variant: isCancelled ? EbicButtonVariant.outline : EbicButtonVariant.primary,
                  onPressed: isCancelled ? null : () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.chefTracking,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
                const SizedBox(height: 12),
                EbicButton(
                  label: 'Ingredient Checklist',
                  icon: Icons.checklist_rtl_rounded,
                  variant: EbicButtonVariant.outline,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.preparationChecklist,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
                const SizedBox(height: 12),
                EbicButton(
                  label: 'View Complete Booking Details',
                  icon: Icons.receipt_long_rounded,
                  variant: EbicButtonVariant.outline,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orderDetail,
                      arguments: {'orderId': orderId},
                    );
                  },
                ),
                const SizedBox(height: 12),
                EbicButton(
                  label: 'Return to Home',
                  icon: Icons.home_rounded,
                  variant: EbicButtonVariant.ghost,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 1. Header & Start OTP ─────────────────────────
  Widget _buildCelebrationHeader(String bookingNumber, String startOtp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chef Booking Confirmed!',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your private chef has been assigned and is heading to your kitchen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Start OTP Ticket Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.key_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'START OTP',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slate600, letterSpacing: 1),
                        ),
                      ],
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: bookingNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Booking ID $bookingNumber copied to clipboard!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                bookingNumber,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 14, color: AppColors.slate500),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    startOtp.split('').join('   '),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this 4-digit verification code with your chef on arrival to begin cooking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 2. Live GPS & Chef Card ─────────────────────────
  Widget _buildLiveGpsCard(String chefName, String arrivalMinutes, String orderId, bool isCancelled) {
    return EbicCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Live Google GPS Map Preview
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_kitchenLocation.latitude + _chefLocation.latitude) / 2,
                        (_kitchenLocation.longitude + _chefLocation.longitude) / 2,
                      ),
                      zoom: 13.5,
                    ),
                    markers: isCancelled
                        ? {
                            Marker(
                              markerId: const MarkerId('kitchen'),
                              position: _kitchenLocation,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                            ),
                          }
                        : _previewMarkers,
                    polylines: isCancelled ? {} : _previewPolylines,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    onTap: (_) {
                      if (!isCancelled) {
                        Navigator.pushNamed(context, AppRoutes.chefTracking, arguments: {'orderId': orderId});
                      }
                    },
                  ),
                  // ETA chip
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isCancelled ? AppColors.danger : AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isCancelled
                                  ? 'Booking Cancelled • GPS Inactive'
                                  : 'Chef arriving in ~$arrivalMinutes mins • 2.4 km',
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Live tracking badge button
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: InkWell(
                      onTap: () {
                        if (!isCancelled) {
                          Navigator.pushNamed(context, AppRoutes.chefTracking, arguments: {'orderId': orderId});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCancelled ? AppColors.slate700 : AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCancelled ? Icons.cancel_outlined : Icons.navigation_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isCancelled ? 'CANCELLED' : 'LIVE GPS',
                                maxLines: 1,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chef Profile Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1577219491135-ce391730fb2c?auto=format&fit=crop&w=400&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chefName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                          SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '4.9 (420+ meals) • Certified Executive Chef',
                              style: TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Equipped with sanitized prep kit & chef knives',
                          style: TextStyle(fontSize: 10, color: AppColors.slate600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Call / Chat Quick Actions
                Column(
                  children: [
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting call with your assigned chef...')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call, color: AppColors.primary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening chat with your assigned chef...')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.slate100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.slate700, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 3. Booked Dishes ─────────────────────────
  Widget _buildDishesCard(List<dynamic> dishes, QuoteModel? quote) {
    final count = dishes.isNotEmpty ? dishes.length : (quote?.items.length ?? 1);

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Dishes Booked ($count)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AT-HOME COOKING',
                  style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (dishes.isNotEmpty) ...[
            for (int i = 0; i < dishes.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _buildDishItem(dishes[i]),
            ],
          ] else if (quote != null && quote.items.isNotEmpty) ...[
            for (int i = 0; i < quote.items.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _buildQuoteItem(quote.items[i]),
            ],
          ] else ...[
            const Text(
              'Selected culinary dishes prepared live in your kitchen.',
              style: TextStyle(color: AppColors.slate600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDishItem(dynamic dish) {
    final name = dish['name']?.toString() ?? dish['title']?.toString() ?? 'Gourmet Dish';
    final servings = dish['servings'] ?? dish['quantity'] ?? 1;
    final imageUrl = dish['imageUrl']?.toString() ??
        dish['image']?.toString() ??
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80';
    final category = dish['category']?.toString() ?? 'Main Course';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 54,
              height: 54,
              color: AppColors.slate100,
              child: const Icon(Icons.restaurant, color: AppColors.slate400, size: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                category,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$servings ${servings == 1 ? 'portion' : 'portions'}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('• Fresh live cooking', style: TextStyle(fontSize: 10, color: AppColors.slate500)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteItem(QuoteItemModel item) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description ?? item.itemType,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} portions • ₹${item.unitPrice.toStringAsFixed(0)} each',
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
        ),
        Text(
          '₹${item.total.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
        ),
      ],
    );
  }

  // ───────────────────────── 4. Household Member & Care ─────────────────────────
  Widget _buildMemberCard(String memberName) {
    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.family_restroom_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cooking For',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE PROFILE',
                  style: TextStyle(color: AppColors.slate700, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Diet: Low Sodium • Balanced Macro Targets • Zero excess oil',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 5. Kitchen Address ─────────────────────────
  Widget _buildAddressCard(String addressLine) {
    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kitchen Service Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  addressLine,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 6. Price & Payment ─────────────────────────
  Widget _buildPriceBreakdownCard(dynamic total, String paymentMethod, QuoteModel? quote, String cookingTime) {
    final finalTotal = total is num ? total.toDouble() : (double.tryParse(total.toString()) ?? 0.0);
    final subtotal = quote?.subtotal ?? (finalTotal * 0.95);
    final gst = quote?.tax ?? (finalTotal * 0.05);

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill & Payment Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Item Subtotal & Portion Charges', '₹${subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildBillRow('Live Cooking Time (~$cookingTime mins)', 'Included'),
          const SizedBox(height: 8),
          _buildBillRow('Statutory GST (5%)', '₹${gst.toStringAsFixed(0)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Paid Amount',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
              ),
              Text(
                '₹${finalTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Verified Payment Status Tag
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.successLight.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.successDark, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paymentMethod == 'WALLET'
                        ? 'Payment Successful via EBIC Wallet'
                        : 'Payment Successful via Razorpay (UPI/Card)',
                    style: const TextStyle(
                      color: AppColors.successDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBillRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate800)),
      ],
    );
  }

  // ───────────────────────── 7. Prep Instructions ─────────────────────────
  Widget _buildPrepInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen Preparation Guide',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 4),
                Text(
                  'Your chef carries their own sanitized knives & prep gear. Please ensure your stove, cookware, and fresh ingredients are accessible in your kitchen.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
