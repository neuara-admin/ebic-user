import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';
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

  // Google Maps Controller & State
  GoogleMapController? _mapController;
  late LatLng _kitchenLocation;
  late LatLng _chefLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Custom marker bitmaps
  BitmapDescriptor? _chefMarkerIcon;
  BitmapDescriptor? _kitchenMarkerIcon;

  // Telemetry metrics
  late List<LatLng> _routeCoordinates;
  double _remainingDistanceKm = 2.8;
  int _dynamicEtaMins = 16;
  double _currentBearing = 45.0;

  bool _isOrderCancelled(String? status) {
    if (status == null) return false;
    final s = status.toUpperCase();
    return s.contains('CANCEL') ||
        s == 'CHEF_CANCELLED' ||
        s == 'CANCELLED_CUSTOMER' ||
        s == 'CANCELLED_NOSHOW';
  }

  @override
  void initState() {
    super.initState();
    // Default base coordinates (Bangalore Kitchen & Chef Hub)
    _kitchenLocation = const LatLng(12.9716, 77.5946);
    _chefLocation = const LatLng(12.9860, 77.6150);

    _initSimulationRoute();
    _loadCustomMarkers();
    _fetchOrder();

    // Background sync polling for backend status (every 10s)
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchOrder(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _initSimulationRoute() {
    final lat1 = _chefLocation.latitude;
    final lng1 = _chefLocation.longitude;
    final lat2 = _kitchenLocation.latitude;
    final lng2 = _kitchenLocation.longitude;

    // 40 realistic waypoints with smooth curves for continuous, non-jittery road travel
    _routeCoordinates = List.generate(40, (i) {
      final t = i / 39.0;
      final curveLat = math.sin(t * math.pi) * 0.0022;
      final curveLng = math.sin(t * math.pi * 2) * 0.0016;
      return LatLng(
        lat1 + (lat2 - lat1) * t + curveLat,
        lng1 + (lng2 - lng1) * t + curveLng,
      );
    });
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _chefMarkerIcon = await _createChefMarkerBitmap();
      _kitchenMarkerIcon = await _createKitchenMarkerBitmap();
      if (mounted) {
        _initMapOverlays();
      }
    } catch (_) {
      _initMapOverlays();
    }
  }

  Future<BitmapDescriptor> _createChefMarkerBitmap() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 110.0;

    // Outer glow / shadow
    final shadowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(size / 2, size / 2), 46, shadowPaint);

    // Main Circle background
    final bgPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(const Offset(size / 2, size / 2), 40, bgPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), 40, ringPaint);

    // Navigation / Chef En Route Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.navigation_rounded.codePoint),
      style: TextStyle(
        fontSize: 48,
        fontFamily: Icons.navigation_rounded.fontFamily,
        package: Icons.navigation_rounded.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createKitchenMarkerBitmap() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 110.0;

    // Outer glow / shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(size / 2, size / 2), 46, shadowPaint);

    // Main Circle background (Emerald Green)
    final bgPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(const Offset(size / 2, size / 2), 40, bgPaint);

    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), 40, ringPaint);

    // Home / Kitchen Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.home_filled.codePoint),
      style: TextStyle(
        fontSize: 44,
        fontFamily: Icons.home_filled.fontFamily,
        package: Icons.home_filled.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void _initMapOverlays() {
    final isCancelled = _isOrderCancelled(_order?.status);

    _markers = {
      Marker(
        markerId: const MarkerId('kitchen'),
        position: _kitchenLocation,
        icon: _kitchenMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Kitchen Destination', snippet: 'Delivery & Cooking Address'),
      ),
      if (!isCancelled)
        Marker(
          markerId: const MarkerId('chef_location'),
          position: _chefLocation,
          rotation: _currentBearing,
          anchor: const Offset(0.5, 0.5),
          icon: _chefMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '${_order?.chefName ?? "Executive Chef"} (En Route)',
            snippet: 'En Route • ${_remainingDistanceKm.toStringAsFixed(1)} km (~$_dynamicEtaMins mins)',
          ),
        ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('chef_route'),
        points: _routeCoordinates,
        color: isCancelled ? AppColors.slate400 : AppColors.primary,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  void _updateChefLocationFromBackend(Map<String, dynamic>? trackingData, int activeIndex) {
    if (_isOrderCancelled(_order?.status)) {
      _remainingDistanceKm = 0.0;
      _dynamicEtaMins = 0;
      _initMapOverlays();
      return;
    }

    if (activeIndex >= 3) {
      // Chef arrived or in kitchen
      _chefLocation = _kitchenLocation;
      _remainingDistanceKm = 0.0;
      _dynamicEtaMins = 0;
      _initMapOverlays();
      return;
    }

    if (trackingData != null) {
      final loc = trackingData['location'] as Map<String, dynamic>?;
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final lat = double.tryParse(loc['latitude'].toString());
        final lng = double.tryParse(loc['longitude'].toString());
        if (lat != null && lng != null) {
          final newPos = LatLng(lat, lng);
          final dLat = newPos.latitude - _chefLocation.latitude;
          final dLng = newPos.longitude - _chefLocation.longitude;
          // Only update and rotate if the vehicle actually moved
          if (dLat.abs() > 0.00008 || dLng.abs() > 0.00008) {
            _currentBearing = (math.atan2(dLng, dLat) * 180 / math.pi) % 360;
            _chefLocation = newPos;
          }
        }
      }

      if (trackingData['distanceRemainingKm'] != null) {
        _remainingDistanceKm = double.tryParse(trackingData['distanceRemainingKm'].toString()) ?? _remainingDistanceKm;
      }
      if (trackingData['etaMinutes'] != null) {
        _dynamicEtaMins = int.tryParse(trackingData['etaMinutes'].toString()) ?? _dynamicEtaMins;
      }
    }
    _initMapOverlays();
  }

  void _recenterMap() {
    if (_mapController == null) return;
    final southwestLat = _kitchenLocation.latitude < _chefLocation.latitude ? _kitchenLocation.latitude : _chefLocation.latitude;
    final southwestLng = _kitchenLocation.longitude < _chefLocation.longitude ? _kitchenLocation.longitude : _chefLocation.longitude;
    final northeastLat = _kitchenLocation.latitude > _chefLocation.latitude ? _kitchenLocation.latitude : _chefLocation.latitude;
    final northeastLng = _kitchenLocation.longitude > _chefLocation.longitude ? _kitchenLocation.longitude : _chefLocation.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(southwestLat - 0.004, southwestLng - 0.004),
      northeast: LatLng(northeastLat + 0.004, northeastLng + 0.004),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _fetchOrder({bool isBackground = false}) async {
    try {
      var orderRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(widget.orderId));
      if (!orderRes.success || orderRes.data == null) {
        orderRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.chefBooking(widget.orderId));
      }

      Map<String, dynamic>? trackingData;
      try {
        final trackRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.chefBookingTracking(widget.orderId));
        if (trackRes.success && trackRes.data != null) {
          trackingData = trackRes.data;
        }
      } catch (_) {}

      if (orderRes.success && orderRes.data != null && mounted) {
        final parsed = OrderModel.fromJson(orderRes.data!);
        final isCancelled = _isOrderCancelled(parsed.status);

        if (isCancelled) {
          _pollingTimer?.cancel();
          _pollingTimer = null;
        }

        final activeIndex = _getStepIndex(parsed.status);

        setState(() {
          _order = parsed;
        });

        _updateChefLocationFromBackend(trackingData, activeIndex);
      }
    } catch (_) {}
  }

  final List<Map<String, dynamic>> _steps = [
    {'status': 'CONFIRMED', 'label': 'Booking Confirmed', 'desc': 'Order verified & culinary slot secured'},
    {'status': 'CHEF_ASSIGNED', 'label': 'Executive Chef Assigned', 'desc': 'Verified chef assigned & hygiene certified'},
    {'status': 'CHEF_EN_ROUTE', 'label': 'Chef En Route', 'desc': 'Executive chef is travelling to your kitchen'},
    {'status': 'CHEF_ARRIVED', 'label': 'Arrived at Doorstep', 'desc': 'Chef reached kitchen destination'},
    {'status': 'IN_PROGRESS', 'label': 'Cooking in Progress', 'desc': 'Healthy dishes crafted in your kitchen'},
    {'status': 'PLATING', 'label': 'Plating & Table Setup', 'desc': 'Garnishing and dining presentation'},
    {'status': 'COMPLETED', 'label': 'Completed & Sanitized', 'desc': 'Kitchen cleaned and service completed'},
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
        return 2;
    }
  }

  void _showCompleteStatusSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStatus = _order?.status ?? 'CHEF_EN_ROUTE';
    final isCancelled = _isOrderCancelled(currentStatus);
    final activeIndex = _getStepIndex(currentStatus);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete Dispatch Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _order?.bookingReference ?? 'Booking Ref: EBIC-${widget.orderId.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    if (isCancelled) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cancel_rounded, color: AppColors.danger, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BOOKING CANCELLED',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'This chef visit has been cancelled. Dispatch tracking is stopped.',
                                    style: TextStyle(fontSize: 11.5, color: AppColors.slate600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LIVE CHEF DISPATCH ACTIVE',
                                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chef ${_order?.chefName ?? "Vikram"} is en route to your kitchen',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_remainingDistanceKm.toStringAsFixed(1)} km away • Arriving in ~$_dynamicEtaMins mins',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

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
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : (isDone ? AppColors.primarySubtle : (isDark ? AppColors.slate800 : AppColors.slate200)),
                                  border: Border.all(
                                    color: isCurrent ? AppColors.primaryDark : (isDone ? AppColors.primary : Colors.transparent),
                                    width: 1.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isCurrent
                                      ? const Icon(Icons.navigation_rounded, size: 14, color: Colors.white)
                                      : (isDone
                                          ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                                          : Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 42,
                                  color: isDone && idx < activeIndex ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        step['label'],
                                        style: TextStyle(
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                          color: isCurrent ? AppColors.primaryDark : (isDone ? (isDark ? Colors.white : AppColors.slate900) : AppColors.slate400),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                          ),
                                          child: const Text('CURRENT STAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    step['desc'],
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: EbicButton(
                        label: 'Ingredient Checklist',
                        icon: Icons.checklist_rtl_rounded,
                        variant: EbicButtonVariant.outline,
                        onPressed: () {
                          Navigator.pop(ctx);
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
                        label: 'Close Status',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStatus = _order?.status ?? 'CHEF_EN_ROUTE';
    final isCancelled = _isOrderCancelled(currentStatus);
    final activeIndex = _getStepIndex(currentStatus);

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      body: Stack(
        children: [
          // 1. Google Maps (or Static Route if cancelled)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.46,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _chefLocation,
                    zoom: 14.8,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _recenterMap();
                  },
                ),
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_tracking_map',
                    backgroundColor: isDark ? AppColors.slate900 : Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    onPressed: _recenterMap,
                    child: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // 2. Top Header Overlay (Back Button + Live GPS Bike Pill + Complete Status Link)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? AppColors.slate900.withOpacity(0.92) : Colors.white.withOpacity(0.95),
                  radius: 20,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.slate800, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCompleteStatusSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900.withOpacity(0.94) : Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isCancelled ? AppColors.danger.withOpacity(0.15) : AppColors.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCancelled ? Icons.cancel_rounded : Icons.navigation_rounded,
                              size: 15,
                              color: isCancelled ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isCancelled
                                      ? 'Booking Cancelled'
                                      : activeIndex >= 3
                                          ? 'Chef Arrived at Doorstep'
                                          : 'Chef En Route • ~$_dynamicEtaMins mins',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCancelled ? AppColors.danger : (isDark ? Colors.white : AppColors.slate900),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  isCancelled ? 'Tap to view details' : 'View Complete Status →',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCancelled ? AppColors.danger : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _fetchOrder(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Sheet Content Overlay
          Positioned(
            top: MediaQuery.of(context).size.height * 0.42,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate700 : AppColors.slate300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // If Cancelled, show dedicated cancellation banner
                      if (isCancelled) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.cancel_rounded, color: AppColors.danger, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'BOOKING CANCELLED',
                                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'This chef booking has been cancelled. Live tracking and dispatch are stopped.',
                                style: TextStyle(fontSize: 12, color: AppColors.slate700, height: 1.3),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                      label: const Text('View Bookings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.slate700,
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.support_agent_rounded, size: 16),
                                      label: const Text('Support', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Active ETA & Status Hero Card
                        GestureDetector(
                          onTap: () => _showCompleteStatusSheet(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.navigation_rounded, size: 15, color: Colors.white70),
                                          const SizedBox(width: 6),
                                          Text(
                                            activeIndex >= 3
                                                ? 'CHEF AT KITCHEN'
                                                : 'CHEF EN ROUTE • ${_remainingDistanceKm.toStringAsFixed(1)} KM',
                                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        activeIndex >= 3
                                            ? 'Ready to Start Cooking'
                                            : 'Arriving in ~$_dynamicEtaMins mins',
                                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.35)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timeline_rounded, size: 13, color: Colors.white),
                                            SizedBox(width: 5),
                                            Text(
                                              'Tap to View Complete Status',
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
                                    ],
                                  ),
                                ),
                                StatusBadge(status: currentStatus),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Start OTP Card
                        if (_order?.startOtp != null && activeIndex < 5) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              border: Border.all(color: const Color(0xFF10B981)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.key_rounded, color: Color(0xFF047857), size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'START OTP',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857), letterSpacing: 0.8),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Share code with chef upon arrival',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF059669), width: 1.5),
                                  ),
                                  child: Text(
                                    _order!.startOtp!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],

                      // Assigned Chef Card
                      EbicCard(
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 28),
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
                                          _order?.chefName ?? 'Chef Vikram Rathore',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: AppColors.primary, size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Certified EBIC Executive Chef • 4.9 ★',
                                    style: TextStyle(color: AppColors.slate500, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                              tooltip: 'Call Chef',
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(text: '+919876543210'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chef contact +91 98765 43210 copied!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick Actions
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primary, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.timeline_rounded, size: 18),
                          label: const Text(
                            'View Complete Status & Dispatch Milestones',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showCompleteStatusSheet(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: EbicButton(
                          label: 'Ingredient Checklist',
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
                      const SizedBox(height: 20),

                      // Dispatch Timeline
                      const Text(
                        'Live Dispatch Timeline',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

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
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: isDone
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : Text(
                                            '${idx + 1}',
                                            style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 30,
                                    color: isDone && idx < activeIndex ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step['label'],
                                      style: TextStyle(
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                        color: isCurrent
                                            ? AppColors.primaryDark
                                            : (isDone ? (isDark ? Colors.white : AppColors.slate900) : AppColors.slate400),
                                      ),
                                    ),
                                    Text(
                                      step['desc'],
                                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      if (!isCancelled && activeIndex < 4) ...[
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 16),
                            label: const Text('Cancel Booking', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () {
                              CancelBookingDialog.show(
                                context,
                                orderId: widget.orderId,
                                onCancelled: () => _fetchOrder(),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
