import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';
import 'cancel_booking_dialog.dart';
import 'tracking/tracking_geo.dart';
import 'tracking/tracking_markers.dart';
import 'tracking/tracking_stream.dart';

/// Live chef dispatch tracking — full-screen Google Map with the chef's real
/// GPS position animating along the road route to the customer's home, and a
/// draggable status sheet (Swiggy / Uber style).
class ChefTrackingScreen extends StatefulWidget {
  final String orderId;

  const ChefTrackingScreen({super.key, required this.orderId});

  @override
  State<ChefTrackingScreen> createState() => _ChefTrackingScreenState();
}

class _ChefTrackingScreenState extends State<ChefTrackingScreen> with TickerProviderStateMixin {
  static const _pollInterval = Duration(seconds: 3);
  static const _sheetInitial = 0.42;
  static const _sheetMin = 0.24;
  static const _sheetMaxCap = 0.92;

  final ApiClient _api = ApiClient();
  Timer? _pollingTimer;
  bool _isFetching = false;
  OrderModel? _order;

  // Tracking telemetry (from GET /chef-bookings/:id/tracking)
  double? _distanceKm;
  int? _etaMins;
  bool _isStale = false;
  bool _isNearby = false;
  String? _chefPhone;
  String? _trackingChefName;
  String? _delayReason;
  int? _delayMins;
  DateTime? _lastUpdatedAt;

  // Live timers. Anchored to local receipt time from server-computed durations
  // (etaSeconds / trip elapsed), so a wrong phone clock can't skew them.
  DateTime? _etaArrivalLocal;
  DateTime? _tripStartLocal;
  Map<String, dynamic>? _trip;
  String? _etaSource;
  Timer? _clockTimer;
  final ValueNotifier<int> _clock = ValueNotifier(0);

  // Map state
  GoogleMapController? _mapController;
  bool _autoFollow = true;
  LatLng? _destination;
  String? _destinationLabel;
  List<LatLng> _route = const [];
  String? _routeEncoded;

  // Chef marker animation between GPS fixes — along the road, not as the crow flies.
  late final AnimationController _moveController;
  LatLng? _chefTo;
  LatLng? _chefShown;
  double _bearingShown = 0;
  List<LatLng> _animPath = const [];
  DateTime? _lastFixAt;

  // Journey so far (delivery-app style): where the trip visibly started and
  // the road already driven. Server trail is authoritative; fixes received
  // live between fetches are appended locally so the grey line keeps up.
  LatLng? _origin;
  List<LatLng> _serverTrail = const [];
  final List<LatLng> _liveTrail = [];
  bool _didJourneyFit = false;

  // Live updates over SSE; polling becomes a slow safety net while it's up.
  TrackingStream? _stream;
  StreamSubscription<Map<String, dynamic>>? _streamSub;
  DateTime _lastFullFetch = DateTime.fromMillisecondsSinceEpoch(0);
  static const _pollWhileStreaming = Duration(seconds: 15);

  /// Bumped whenever map overlays change; only the map rebuilds on ticks.
  final ValueNotifier<int> _mapTick = ValueNotifier(0);
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_sheetInitial);
  final ValueNotifier<double> _mapBottomExtent = ValueNotifier(_sheetInitial);
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Timer? _mapPaddingDebounce;

  BitmapDescriptor? _chefIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _homeIcon;
  String? _homeIconLabel;
  bool _markersLoading = false;

  bool _isOrderCancelled(String? status) {
    if (status == null) return false;
    final s = status.toUpperCase();
    return s.contains('CANCEL') ||
        s == 'FAILED_NO_SUPPLY' ||
        s == 'CHEF_CANCELLED' ||
        s == 'CANCELLED_CUSTOMER' ||
        s == 'CANCELLED_NOSHOW';
  }

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this, duration: _pollInterval)
      ..addListener(_onMoveTick);

    _fetchOrder();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _clock.value++);

    if (TrackingStream.supported) {
      final stream = TrackingStream(widget.orderId);
      _stream = stream;
      _streamSub = stream.events.listen(_onStreamEvent);
      stream.start();
    }
  }

  /// Full refresh every 3 s without a live stream; every 15 s while the
  /// stream is delivering positions (it still resyncs status, route and trail).
  void _pollTick() {
    final streaming = _stream?.connected.value ?? false;
    final due = DateTime.now().difference(_lastFullFetch) >= (streaming ? _pollWhileStreaming : _pollInterval);
    if (due) _fetchOrder();
  }

  void _onStreamEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    switch (e['event']) {
      case 'chef.location.updated':
        final lat = double.tryParse('${e['latitude']}');
        final lng = double.tryParse('${e['longitude']}');
        if (lat != null && lng != null && _isEnRoute) _onChefPosition(LatLng(lat, lng));
        final etaMin = int.tryParse('${e['etaMinutes']}');
        if (etaMin != null) setState(() => _etaMins = etaMin);
        _lastUpdatedAt = DateTime.now();
        _isStale = false;
        break;
      case 'chef.eta.updated':
        final secs = int.tryParse('${e['etaSeconds']}');
        setState(() {
          if (secs != null) _etaArrivalLocal = DateTime.now().add(Duration(seconds: secs));
          _etaMins = int.tryParse('${e['etaMinutes']}') ?? _etaMins;
          _distanceKm = double.tryParse('${e['distanceRemainingKm']}') ?? _distanceKm;
          if (e['isNearby'] == true) _isNearby = true;
        });
        break;
      case 'chef.tracking.status_changed':
        // Departed / arrived / cooking… — pull the full order + route now.
        _fetchOrder();
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureMarkerIcons();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _stream?.dispose();
    _pollingTimer?.cancel();
    _moveController.dispose();
    _mapController?.dispose();
    _mapTick.dispose();
    _clockTimer?.cancel();
    _clock.dispose();
    _sheetExtent.dispose();
    _mapBottomExtent.dispose();
    _mapPaddingDebounce?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _fetchOrder() async {
    if (_isFetching) return;
    _isFetching = true;
    _lastFullFetch = DateTime.now();
    try {
      final results = await Future.wait([
        _api.get<Map<String, dynamic>>(ApiEndpoints.orderDetail(widget.orderId)),
        _api.get<Map<String, dynamic>>(ApiEndpoints.chefBookingTracking(widget.orderId)),
      ]);
      var orderRes = results[0];
      final trackRes = results[1];
      if (!orderRes.success || orderRes.data == null) {
        orderRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.chefBooking(widget.orderId));
      }
      if (!mounted) return;

      if (orderRes.success && orderRes.data != null) {
        final parsed = OrderModel.fromJson(orderRes.data!);
        final isCancel = _isOrderCancelled(parsed.status);
        final isComp = parsed.status.toUpperCase() == 'COMPLETED';
        if (isCancel || isComp) {
          _pollingTimer?.cancel();
          _pollingTimer = null;
          _streamSub?.cancel();
          _stream?.dispose();
          _stream = null;
        }
        setState(() => _order = parsed);
        _destination ??= _addressLatLng(parsed.address);
        _destinationLabel ??= parsed.address?.label;
      }

      if (trackRes.success && trackRes.data != null) {
        _applyTracking(trackRes.data!);
      }
      _refreshOverlays();
    } catch (_) {
      // Transient network failure — next poll retries.
    } finally {
      _isFetching = false;
    }
  }

  LatLng? _addressLatLng(OrderAddressModel? address) {
    if (address?.lat == null || address?.lng == null) return null;
    if (address!.lat == 0 && address.lng == 0) return null;
    return LatLng(address.lat!, address.lng!);
  }

  void _applyTracking(Map<String, dynamic> data) {
    final dest = data['destination'];
    if (dest is Map) {
      final lat = double.tryParse('${dest['latitude']}');
      final lng = double.tryParse('${dest['longitude']}');
      if (lat != null && lng != null && !(lat == 0 && lng == 0)) {
        _destination = LatLng(lat, lng);
      }
      _destinationLabel = dest['label']?.toString() ?? _destinationLabel;
    }

    final encoded = data['routePolyline']?.toString();
    if (encoded != null && encoded.isNotEmpty && encoded != _routeEncoded) {
      _routeEncoded = encoded;
      _route = TrackingGeo.decodePolyline(encoded);
    }

    // Journey so far: visible start point + road already driven.
    final origin = data['origin'];
    if (origin is Map) {
      final lat = double.tryParse('${origin['latitude']}');
      final lng = double.tryParse('${origin['longitude']}');
      _origin = lat != null && lng != null ? LatLng(lat, lng) : null;
    } else {
      _origin = null;
    }
    final trail = data['travelledPath'];
    if (trail is List) {
      _serverTrail = [
        for (final p in trail)
          if (p is List && p.length >= 2 && p[0] is num && p[1] is num)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      // The server trail now covers everything received so far.
      _liveTrail.clear();
    }

    final chef = data['assignedChef'];
    if (chef is Map) {
      _trackingChefName = chef['name']?.toString();
      _chefPhone = chef['phone']?.toString();
    }

    final delay = data['activeDelay'];
    _delayReason = delay is Map ? delay['reason']?.toString() : null;
    _delayMins = delay is Map ? int.tryParse('${delay['estimatedDelayMinutes']}') : null;

    final now = DateTime.now();
    final etaSeconds = int.tryParse('${data['etaSeconds']}');
    _etaArrivalLocal = etaSeconds != null ? now.add(Duration(seconds: etaSeconds)) : null;
    _etaSource = data['etaSource']?.toString();

    final trip = data['trip'];
    _trip = trip is Map ? Map<String, dynamic>.from(trip) : null;
    final elapsed = int.tryParse('${_trip?['travelDurationSeconds']}');
    _tripStartLocal = elapsed != null && _trip?['isCompleted'] != true ? now.subtract(Duration(seconds: elapsed)) : null;

    setState(() {
      _etaMins = int.tryParse('${data['etaMinutes']}') ?? _etaMins;
      _distanceKm = double.tryParse('${data['distanceRemainingKm']}') ?? _distanceKm;
      _isStale = data['isStale'] == true;
      _isNearby = data['isNearby'] == true;
      _lastUpdatedAt = DateTime.tryParse('${data['lastUpdatedAt']}')?.toLocal();
    });

    final loc = data['location'];
    if (loc is Map) {
      final lat = double.tryParse('${loc['latitude']}');
      final lng = double.tryParse('${loc['longitude']}');
      if (lat != null && lng != null) _onChefPosition(LatLng(lat, lng));
    }
  }

  // ---------------------------------------------------------------------------
  // Chef marker animation
  // ---------------------------------------------------------------------------

  void _onChefPosition(LatLng next) {
    final now = DateTime.now();
    if (_chefShown == null) {
      _chefTo = _chefShown = next;
      _lastFixAt = now;
      if (_destination != null) _bearingShown = TrackingGeo.bearing(next, _destination!);
      _fitJourneyOnce();
      return;
    }
    final moved = TrackingGeo.distanceMeters(_chefTo!, next);
    if (moved < 3) return;

    // Glide for about as long as fixes are arriving apart, so the marker is
    // always moving rather than jumping and then waiting (1–6 s).
    final gap = _lastFixAt == null ? _pollInterval : now.difference(_lastFixAt!);
    _lastFixAt = now;
    final ms = gap.inMilliseconds.clamp(1000, 6000);
    _moveController.duration = Duration(milliseconds: ms);

    final from = _chefShown!;
    _chefTo = next;
    _appendLiveTrail(next);

    if (moved > 2000) {
      // GPS jump (e.g. first fix after being offline) — don't glide across the city.
      _animPath = [next, next];
      _chefShown = next;
      _bearingShown = TrackingGeo.bearing(from, next);
      _moveController.value = 1;
    } else {
      // Follow the road between the two fixes (corners included).
      _animPath = TrackingGeo.pathAlongRoute(_route, from, next);
      _moveController.forward(from: 0);
    }
    if (_autoFollow) _fitCamera();
  }

  /// Grows the grey "already driven" line between full refreshes. Only once
  /// the server has revealed the journey (chef past the privacy radius around
  /// where they set off), so nothing near the chef's start is ever drawn.
  void _appendLiveTrail(LatLng p) {
    if (_origin == null) return;
    final last = _liveTrail.isNotEmpty ? _liveTrail.last : (_serverTrail.isNotEmpty ? _serverTrail.last : null);
    if (last == null || TrackingGeo.distanceMeters(last, p) >= 12) _liveTrail.add(p);
  }

  /// First time we know where the chef is: frame the whole journey (start,
  /// chef, home) the way delivery apps do; after that the camera follows.
  void _fitJourneyOnce() {
    if (_didJourneyFit) {
      if (_autoFollow) _fitCamera();
      return;
    }
    final controller = _mapController;
    final points = <LatLng>[?_origin, ..._serverTrail, ?_chefShown, ?_destination];
    if (controller == null || points.length < 2) {
      _fitCamera();
      return;
    }
    _didJourneyFit = true;
    controller.animateCamera(CameraUpdate.newLatLngBounds(TrackingGeo.boundsOf(points), 64));
  }

  int _lastTickMs = 0;
  void _onMoveTick() {
    if (_animPath.length < 2) return;
    final t = Curves.easeInOut.transform(_moveController.value);
    final at = TrackingGeo.pointAlong(_animPath, t);
    _chefShown = at.point;
    // Ease the heading towards the road's direction so turns look natural.
    _bearingShown = TrackingGeo.lerpBearing(_bearingShown, at.bearing, 0.25);

    // ~30 fps is plenty for marker updates over the platform channel.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTickMs >= 33 || _moveController.isCompleted) {
      _lastTickMs = now;
      _mapTick.value++;
    }
  }

  // ---------------------------------------------------------------------------
  // Map overlays & camera
  // ---------------------------------------------------------------------------

  int get _activeIndex => _getStepIndex(_order?.status ?? 'PENDING');
  bool get _isCancelled => _isOrderCancelled(_order?.status);
  bool get _isCompleted => (_order?.status ?? '').toUpperCase() == 'COMPLETED' || _activeIndex >= 6;
  bool get _isEnRoute => !_isCancelled && !_isCompleted && _activeIndex == 2;
  bool get _hasArrived => !_isCancelled && !_isCompleted && _activeIndex == 3;

  String? get _homeBubbleLabel {
    if (_isCancelled) return null;
    if (_hasArrived) return 'Chef is here';
    final eta = _etaMinsLive;
    if (_isEnRoute && eta != null) return eta <= 1 ? 'Arriving now' : '$eta min';
    return 'Your home';
  }

  Future<void> _ensureMarkerIcons() async {
    if (_markersLoading) return;
    final label = _homeBubbleLabel;
    if (_chefIcon != null && _homeIcon != null && _homeIconLabel == label) return;
    _markersLoading = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      _chefIcon ??= await TrackingMarkers.chef(dpr);
      _originIcon ??= await TrackingMarkers.origin(dpr);
      _homeIcon = await TrackingMarkers.home(dpr, label: label);
      _homeIconLabel = label;
      _mapTick.value++;
    } catch (_) {
      // Falls back to default Google markers.
    } finally {
      _markersLoading = false;
    }
    if (mounted && _homeIconLabel != _homeBubbleLabel) _ensureMarkerIcons();
  }

  void _refreshOverlays() {
    if (!mounted) return;
    _ensureMarkerIcons();
    _mapTick.value++;
  }

  /// Chef position to show on the map for the current booking stage.
  LatLng? get _chefDisplayPosition {
    if (_isCancelled || _activeIndex >= 4) return null;
    if (_hasArrived) return _destination ?? _chefShown;
    return _isEnRoute ? _chefShown : null;
  }

  List<LatLng> get _remainingRoute {
    final chef = _chefDisplayPosition;
    if (!_isEnRoute || chef == null || _destination == null) return const [];
    if (_route.length >= 2) return TrackingGeo.remainingRoute(_route, chef);
    return [chef, _destination!];
  }

  bool get _showJourney => !_isCancelled && (_isEnRoute || _hasArrived);

  /// Road already driven: server trail + live fixes + the marker's current
  /// animated spot, so the grey line ends exactly under the chef.
  List<LatLng> get _drivenPath {
    if (!_showJourney || _origin == null) return const [];
    return [
      ..._serverTrail,
      ..._liveTrail,
      if (_isEnRoute && _chefShown != null) _chefShown!,
      if (_hasArrived && _destination != null) _destination!,
    ];
  }

  Set<Marker> _buildMarkers() {
    final chef = _chefDisplayPosition;
    return {
      if (_showJourney && _origin != null)
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 0,
          icon: _originIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Chef set off'),
        ),
      if (_destination != null)
        Marker(
          markerId: const MarkerId('home'),
          position: _destination!,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 1,
          icon: _homeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: _destinationLabel ?? 'Your home', snippet: _order?.address?.fullAddress),
        ),
      if (chef != null && !_hasArrived)
        Marker(
          markerId: const MarkerId('chef'),
          position: chef,
          rotation: _bearingShown,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          icon: _chefIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: _chefDisplayName),
        ),
    };
  }

  Set<Polyline> _buildPolylines(bool isDark) {
    // Delivery-app style: grey = already driven, green = still to go.
    final driven = _drivenPath;
    final drivenLine = driven.length >= 2
        ? Polyline(
            polylineId: const PolylineId('driven'),
            points: driven,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
            width: 5,
            zIndex: 0,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          )
        : null;

    final points = _remainingRoute;
    if (points.length < 2) return {?drivenLine};
    final isRoadRoute = _route.length >= 2;
    if (!isRoadRoute) {
      // No road geometry yet (fallback ETA) — dashed straight line.
      return {
        ?drivenLine,
        Polyline(
          polylineId: const PolylineId('route_direct'),
          points: points,
          color: AppColors.primary,
          width: 4,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
      };
    }
    return {
      ?drivenLine,
      Polyline(
        polylineId: const PolylineId('route_casing'),
        points: points,
        color: isDark ? const Color(0xFF0B1F17) : AppColors.emerald900,
        width: 9,
        zIndex: 1,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppColors.primaryLight,
        width: 5,
        zIndex: 2,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Circle> _buildCircles() {
    final chef = _chefDisplayPosition;
    return {
      if (chef != null && _isEnRoute)
        Circle(
          circleId: const CircleId('chef_halo'),
          center: chef,
          radius: 45,
          fillColor: AppColors.primary.withValues(alpha: 0.14),
          strokeWidth: 0,
        ),
      if (_destination != null && !_isEnRoute && !_isCancelled)
        Circle(
          circleId: const CircleId('home_halo'),
          center: _destination!,
          radius: 90,
          fillColor: AppColors.accent.withValues(alpha: 0.12),
          strokeColor: AppColors.accent.withValues(alpha: 0.35),
          strokeWidth: 1,
        ),
    };
  }

  void _fitCamera() {
    final controller = _mapController;
    if (controller == null) return;
    final points = <LatLng>[
      ?_chefDisplayPosition,
      ?_destination,
      ..._remainingRoute,
    ];
    if (points.isEmpty) return;

    final span = points.length > 1 ? TrackingGeo.distanceMeters(points.first, points[1]) : 0.0;
    if (points.length == 1 || span < 150) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
    } else {
      controller.animateCamera(CameraUpdate.newLatLngBounds(TrackingGeo.boundsOf(points), 56));
    }
  }

  void _recenter() {
    setState(() => _autoFollow = true);
    _fitCamera();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get _chefDisplayName {
    final name = _trackingChefName ?? _order?.assignedChef?.name;
    if (name == null || name.trim().isEmpty) return 'Your chef';
    return name.toLowerCase().startsWith('chef') ? name : 'Chef $name';
  }

  Future<void> _callChef() async {
    final phone = _chefPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chef contact will be available once the chef is assigned.')),
      );
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to call $phone')));
    }
  }

  String _lastUpdatedText() {
    final at = _lastUpdatedAt;
    if (at == null) return 'a while ago';
    final mins = DateTime.now().difference(at).inMinutes;
    if (mins < 1) return 'just now';
    return '$mins min ago';
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
      case 'CREATED':
      case 'SEARCHING':
      case 'SEARCHING_REPLACEMENT':
        return 0;
      case 'CHEF_ASSIGNED':
      case 'ACCEPTED':
      case 'ASSIGNED':
        return 1;
      case 'CHEF_EN_ROUTE':
      case 'EN_ROUTE':
        return 2;
      case 'CHEF_ARRIVED':
      case 'ARRIVED':
      case 'WAITING_CUSTOMER':
        return 3;
      case 'IN_PROGRESS':
      case 'COOKING':
        return 4;
      case 'PLATING':
        return 5;
      case 'COMPLETED':
        return 6;
      default:
        // Unknown status: never claim the chef is en route without evidence.
        return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final sheetMax = _sheetMaxFor(context);

    if (_order == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.slate900 : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.slate800),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Chef Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_isCancelled || _isCompleted) {
      return _buildInactiveOrderScreen(context, isDark, _isCancelled, _isCompleted);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      body: Stack(
        children: [
          // 1. Full-screen live map. Its bottom padding follows the sheet only once
          // the sheet settles — resizing the native map on every drag frame is
          // what made the sheet stutter and drop flings.
          Positioned.fill(
            child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _mapBottomExtent,
              builder: (context, extent, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _mapTick,
                  builder: (context, _, __) {
                    return Listener(
                      onPointerDown: (_) {
                        if (_autoFollow) setState(() => _autoFollow = false);
                      },
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _destination ?? _chefShown ?? const LatLng(12.9716, 77.5946),
                          zoom: 14.5,
                        ),
                        style: isDark ? TrackingMapStyles.dark : TrackingMapStyles.light,
                        padding: EdgeInsets.only(
                          top: media.padding.top + 64,
                          bottom: screenH * extent.clamp(_sheetMin, 0.55),
                        ),
                        markers: _buildMarkers(),
                        polylines: _buildPolylines(isDark),
                        circles: _buildCircles(),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        buildingsEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          Future.delayed(const Duration(milliseconds: 300), _fitJourneyOnce);
                        },
                      ),
                    );
                  },
                );
              },
            ),
            ),
          ),

          // 2. Top bar
          Positioned(
            top: media.padding.top + 8,
            left: 14,
            right: 14,
            child: _buildTopBar(isDark),
          ),

          // 3. Recenter button, floating above the sheet
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, _) {
              if (extent > 0.6) return const SizedBox.shrink();
              return Positioned(
                right: 14,
                bottom: screenH * extent + 14,
                child: AnimatedScale(
                  scale: _autoFollow ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_tracking_map',
                    backgroundColor: isDark ? AppColors.slate900 : Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    onPressed: _recenter,
                    child: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),
              );
            },
          ),

          // 4. Draggable status sheet
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              _sheetExtent.value = n.extent; // cheap: only the Flutter FAB listens per frame
              _mapPaddingDebounce?.cancel();
              _mapPaddingDebounce = Timer(const Duration(milliseconds: 180), () {
                if (mounted) _mapBottomExtent.value = n.extent.clamp(_sheetMin, 0.55);
              });
              return false;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _sheetInitial,
              minChildSize: _sheetMin,
              maxChildSize: sheetMax,
              snap: true,
              snapSizes: const [_sheetInitial],
              snapAnimationDuration: const Duration(milliseconds: 220),
              builder: (context, scrollController) =>
                  RepaintBoundary(child: _buildSheet(isDark, scrollController)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    final surface = isDark ? AppColors.slate900.withValues(alpha: 0.95) : Colors.white;
    final shadow = [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 3))];

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(color: surface, shape: BoxShape.circle, boxShadow: shadow),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.slate800, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: shadow),
            child: Row(
              children: [
                _LiveDot(active: _isEnRoute && !_isStale),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _order?.bookingReference ?? 'Chef visit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      Text(
                        _isCancelled
                            ? 'Booking cancelled'
                            : _isEnRoute
                                ? (_isStale ? 'Live location paused' : 'Live tracking')
                                : _steps[_activeIndex]['label'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isCancelled ? AppColors.danger : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.support),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text('Help', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fully expanded, the sheet stops just below the top bar (back button + order pill).
  double _sheetMaxFor(BuildContext context) {
    final media = MediaQuery.of(context);
    final topBarBottom = media.padding.top + 8 + 56 + 10;
    return (1 - topBarBottom / media.size.height).clamp(_sheetInitial + 0.1, _sheetMaxCap);
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;
    final max = _sheetMaxFor(context);
    final target = _sheetController.size < (_sheetInitial + max) / 2 ? max : _sheetInitial;
    _sheetController.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  Widget _buildSheet(bool isDark, ScrollController scrollController) {
    final activeIndex = _activeIndex;
    final currentStatus = _order?.status ?? 'PENDING';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          // Drag handle — also tap to expand / collapse
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleSheet,
            child: SizedBox(
              height: 26,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          if (_isCancelled) ...[
            _buildCancelledBanner(),
            const SizedBox(height: 16),
          ] else ...[
            _buildEtaHeader(isDark, currentStatus),
            const SizedBox(height: 16),
            _buildStageProgress(isDark, activeIndex),
            if (_isEnRoute && _isStale) ...[
              const SizedBox(height: 12),
              _buildInfoChip(
                icon: Icons.gps_off_rounded,
                color: AppColors.warning,
                text: "Chef's live location paused — last updated ${_lastUpdatedText()}",
              ),
            ],
            if (_delayReason != null) ...[
              const SizedBox(height: 10),
              _buildInfoChip(
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
                text: 'Running late${_delayMins != null ? ' by ~$_delayMins min' : ''} • ${_delayReason!.replaceAll('_', ' ').toLowerCase()}',
              ),
            ],
            const SizedBox(height: 16),
          ],

          _buildChefCard(isDark),
          const SizedBox(height: 14),

          if (!_isCancelled) ..._buildOtpCards(activeIndex),

          if (_order?.address != null) ...[
            _buildAddressRow(isDark),
            const SizedBox(height: 14),
          ],

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
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.preparationChecklist,
                arguments: {'orderId': widget.orderId},
              ),
            ),
          ),

          if (!_isCancelled && activeIndex < 4) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 16),
                label: const Text('Cancel Booking',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => CancelBookingDialog.show(
                  context,
                  orderId: widget.orderId,
                  onCancelled: () => _fetchOrder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Seconds until the estimated arrival, counting down locally between polls.
  int? get _etaSecondsLive {
    final at = _etaArrivalLocal;
    if (at == null) return null;
    final s = at.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Remaining road distance measured along the route from the chef's live
  /// (animated) position; falls back to the backend's last calculated value.
  double? get _liveDistanceKm {
    if (_route.length >= 2 && _isEnRoute && _chefShown != null) {
      final remaining = _remainingRoute;
      var meters = 0.0;
      for (var i = 0; i < remaining.length - 1; i++) {
        meters += TrackingGeo.distanceMeters(remaining[i], remaining[i + 1]);
      }
      return meters / 1000;
    }
    return _distanceKm;
  }

  int? get _etaMinsLive {
    final s = _etaSecondsLive;
    return s == null ? _etaMins : (s / 60).ceil();
  }

  static String _fmtClock(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String _fmtDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
    if (m > 0) return s > 0 ? '$m min $s s' : '$m min';
    return '$s s';
  }

  Widget _buildEtaHeader(bool isDark, String currentStatus) {
    // Rebuilds every second for the live countdown / elapsed timers.
    return ValueListenableBuilder<int>(
      valueListenable: _clock,
      builder: (context, _, __) => _buildEtaHeaderContent(isDark, currentStatus),
    );
  }

  Widget _buildEtaHeaderContent(bool isDark, String currentStatus) {
    final String title;
    final String subtitle;
    final etaMins = _etaMinsLive;
    if (_order == null) {
      title = 'Loading your booking…';
      subtitle = 'Fetching live status';
    } else if (_isEnRoute) {
      if (_chefShown == null) {
        title = 'Chef is on the way';
        subtitle = 'Connecting to live location…';
      } else if (_isNearby || (etaMins != null && etaMins <= 2)) {
        title = 'Arriving now';
        subtitle = '$_chefDisplayName is almost at your door';
      } else {
        title = etaMins != null ? 'Arriving in $etaMins min' : 'Chef is on the way';
        final km = _liveDistanceKm;
        subtitle = km != null
            ? '$_chefDisplayName is ${km.toStringAsFixed(1)} km away'
            : '$_chefDisplayName is heading to your home';
      }
    } else if (_hasArrived) {
      title = 'Chef has arrived';
      subtitle = 'Share the start OTP with $_chefDisplayName';
    } else if (_activeIndex >= 6) {
      title = 'Service completed';
      subtitle = 'Hope you enjoyed your meal!';
    } else if (_activeIndex >= 4) {
      title = _activeIndex == 5 ? 'Plating your meal' : 'Cooking in progress';
      subtitle = '$_chefDisplayName is cooking in your kitchen';
    } else if (_activeIndex == 1) {
      title = 'Chef assigned';
      subtitle = 'Live tracking starts when $_chefDisplayName leaves';
    } else {
      title = 'Booking confirmed';
      subtitle = "We're assigning a verified chef";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(status: currentStatus),
          ],
        ),
        if (_isEnRoute && _chefShown != null) ...[
          const SizedBox(height: 12),
          _buildLiveTimers(isDark),
        ],
        if (!_isEnRoute && _trip?['isCompleted'] == true) ...[
          const SizedBox(height: 12),
          _buildTripSummary(isDark),
        ],
      ],
    );
  }

  /// Swiggy/Uber-style live timers: ETA countdown + arrival clock time, and
  /// how long the chef has been on the way.
  Widget _buildLiveTimers(bool isDark) {
    final etaSecs = _etaSecondsLive;
    final arrival = _etaArrivalLocal;
    final elapsed = _tripStartLocal != null ? DateTime.now().difference(_tripStartLocal!).inSeconds : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildJourneyProgress(isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            if (etaSecs != null)
              Expanded(
                child: _timerTile(
                  isDark,
                  icon: Icons.timer_outlined,
                  value: _fmtClock(etaSecs),
                  label: arrival != null ? 'ETA · by ${TimeOfDay.fromDateTime(arrival).format(context)}' : 'ETA',
                  highlight: true,
                ),
              ),
            if (etaSecs != null && elapsed != null) const SizedBox(width: 10),
            if (elapsed != null)
              Expanded(
                child: _timerTile(
                  isDark,
                  icon: Icons.two_wheeler_rounded,
                  value: _fmtClock(elapsed < 0 ? 0 : elapsed),
                  label: 'On the way${_trip?['travelledDistanceKm'] != null ? ' · ${_trip!['travelledDistanceKm']} km' : ''}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              _etaSource == 'FALLBACK_ROUTING' ? Icons.info_outline_rounded : Icons.traffic_rounded,
              size: 13,
              color: AppColors.slate400,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _etaSource == 'FALLBACK_ROUTING'
                    ? 'Approximate ETA — live traffic unavailable right now.'
                    : 'Google Maps ETA with live traffic · updates as the chef moves.',
                style: const TextStyle(fontSize: 10.5, color: AppColors.slate400),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Start ●━━━━🛵─────🏠 — how far along the chef is, like delivery apps.
  Widget _buildJourneyProgress(bool isDark) {
    final travelledM = double.tryParse('${_trip?['travelledDistanceMeters']}') ?? 0;
    final remainingKm = _liveDistanceKm;
    final remainingM = remainingKm != null ? remainingKm * 1000 : null;
    final progress = remainingM == null ? null : TrackingGeo.progress(travelledM, remainingM);
    final startedAt = DateTime.tryParse('${_trip?['startedAt']}')?.toLocal();
    final track = isDark ? AppColors.slate700 : AppColors.slate200;

    return Column(
      children: [
        SizedBox(
          height: 30,
          child: LayoutBuilder(
            builder: (context, box) {
              const endW = 22.0;
              final barW = box.maxWidth - endW * 2;
              final p = progress ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: endW,
                    right: endW,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: track,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Positioned(left: 0, child: Icon(Icons.radio_button_checked_rounded, size: 20, color: AppColors.slate500)),
                  Positioned(right: 0, child: Icon(Icons.home_rounded, size: 22, color: AppColors.accent)),
                  if (progress != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      left: endW + barW * p - 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? AppColors.slate900 : Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              startedAt != null ? 'Set off ${TimeOfDay.fromDateTime(startedAt).format(context)}' : 'On the way',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (remainingKm != null)
              Text(
                '${remainingKm.toStringAsFixed(1)} km to go',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }

  Widget _timerTile(bool isDark,
      {required IconData icon, required String value, required String label, bool highlight = false}) {
    final accent = highlight ? AppColors.primary : AppColors.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
            : (isDark ? AppColors.slate800 : AppColors.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: highlight ? AppColors.primaryDark : (isDark ? Colors.white : AppColors.slate800),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Actual journey once the chef has arrived, with the planned estimate for comparison.
  Widget _buildTripSummary(bool isDark) {
    final secs = int.tryParse('${_trip?['travelDurationSeconds']}');
    final km = _trip?['travelledDistanceKm'];
    final plannedM = double.tryParse('${_trip?['plannedDistanceMeters']}');
    final plannedS = int.tryParse('${_trip?['plannedDurationSeconds']}');
    final planned = [
      if (plannedS != null) 'est. ${_fmtDuration(plannedS)}',
      if (plannedM != null) '${(plannedM / 1000).toStringAsFixed(1)} km',
    ].join(' · ');

    return _buildInfoChip(
      icon: Icons.flag_rounded,
      color: AppColors.primary,
      text: [
        'Reached in ${secs != null ? _fmtDuration(secs) : '—'}',
        if (km != null) '$km km travelled',
        if (planned.isNotEmpty) '($planned)',
      ].join(' · '),
    );
  }

  Widget _buildStageProgress(bool isDark, int activeIndex) {
    const stages = [
      (Icons.check_circle_rounded, 'Confirmed'),
      (Icons.person_rounded, 'Assigned'),
      (Icons.two_wheeler_rounded, 'On the way'),
      (Icons.home_rounded, 'Arrived'),
      (Icons.soup_kitchen_rounded, 'Cooking'),
    ];
    final idle = isDark ? AppColors.slate700 : AppColors.slate200;

    return Row(
      children: List.generate(stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = activeIndex > i ~/ 2;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: done ? AppColors.primary : idle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final done = activeIndex >= idx;
        final current = activeIndex == idx || (idx == 4 && activeIndex > 4);
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: current ? 34 : 28,
              height: current ? 34 : 28,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : idle,
                shape: BoxShape.circle,
                boxShadow: current
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10)]
                    : null,
              ),
              child: Icon(stages[idx].$1, size: current ? 18 : 15, color: done ? Colors.white : AppColors.slate400),
            ),
            const SizedBox(height: 4),
            Text(
              stages[idx].$2,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                color: done ? (isDark ? Colors.white : AppColors.slate800) : AppColors.slate400,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoChip({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildChefCard(bool isDark) {
    return EbicCard(
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
                        _chefDisplayName,
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
                  'Certified EBIC Executive Chef',
                  style: TextStyle(color: AppColors.slate500, fontSize: 11),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.primarySubtle,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.call_rounded, color: AppColors.primary),
              tooltip: 'Call chef',
              onPressed: _callChef,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.home_rounded, color: AppColors.amber700, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _destinationLabel ?? _order!.address!.label ?? 'Home',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _order!.address!.fullAddress,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOtpCards(int activeIndex) {
    return [
      if (activeIndex < 4 && _order?.startOtp != null) ...[
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857), letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('Share code with chef upon arrival', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
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
                      fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (activeIndex >= 4 && _order?.completionOtp != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
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
                        Icon(Icons.verified_rounded, color: Color(0xFF9333EA), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'COMPLETION OTP',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF7E22CE), letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Share code with chef once meal is cooked & plated to complete service',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8), height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9333EA), width: 1.8),
                ),
                child: Text(
                  _order!.completionOtp!,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF7E22CE)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _buildCancelledBanner() {
    return Container(
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
              Text('BOOKING CANCELLED',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
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
    );
  }

  void _showCompleteStatusSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled = _isCancelled;
    final activeIndex = _activeIndex;

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
                        const Text('Complete Dispatch Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          _order?.bookingReference ??
                              'Booking Ref: EBIC-${widget.orderId.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    if (isCancelled) ...[
                      _buildInfoChip(
                        icon: Icons.cancel_rounded,
                        color: AppColors.danger,
                        text: 'This chef visit has been cancelled. Dispatch tracking is stopped.',
                      ),
                      const SizedBox(height: 16),
                    ] else if (_isEnRoute) ...[
                      _buildInfoChip(
                        icon: Icons.navigation_rounded,
                        color: AppColors.primary,
                        text: [
                          '$_chefDisplayName is en route',
                          if (_distanceKm != null) '${_distanceKm!.toStringAsFixed(1)} km away',
                          if (_etaMins != null) 'arriving in ~$_etaMins min',
                        ].join(' • '),
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
                                      : (isDone
                                          ? AppColors.primarySubtle
                                          : (isDark ? AppColors.slate800 : AppColors.slate200)),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.primaryDark
                                        : (isDone ? AppColors.primary : Colors.transparent),
                                    width: 1.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isCurrent
                                      ? const Icon(Icons.navigation_rounded, size: 14, color: Colors.white)
                                      : (isDone
                                          ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                                          : Text('${idx + 1}',
                                              style: const TextStyle(
                                                  fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 42,
                                  color: isDone && idx < activeIndex
                                      ? AppColors.primary
                                      : (isDark ? AppColors.slate800 : AppColors.slate200),
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
                                      Flexible(
                                        child: Text(
                                          step['label'],
                                          style: TextStyle(
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 14,
                                            color: isCurrent
                                                ? AppColors.primaryDark
                                                : (isDone
                                                    ? (isDark ? Colors.white : AppColors.slate900)
                                                    : AppColors.slate400),
                                          ),
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
                                          child: const Text('CURRENT STAGE',
                                              style: TextStyle(
                                                  fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(step['desc'],
                                      style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3)),
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
                child: SizedBox(
                  width: double.infinity,
                  child: EbicButton(label: 'Close Status', onPressed: () => Navigator.pop(ctx)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInactiveOrderScreen(
    BuildContext context,
    bool isDark,
    bool isCancelled,
    bool isCompleted,
  ) {
    final activeIndex = _activeIndex;
    final order = _order!;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.slate800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.bookingReference ?? 'Chef Visit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            Text(
              isCancelled ? 'Booking Cancelled • GPS Inactive' : 'Service Completed • Dining Finished',
              style: TextStyle(
                fontSize: 11,
                color: isCancelled ? AppColors.danger : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
            child: const Text('Help', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Status Card (No GoogleMap)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                        Container(
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
                                isCancelled ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isCancelled ? 'VISIT CANCELLED' : 'CULINARY COMPLETED',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            StatusBadge.formatStatus(order.status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCancelled ? AppColors.danger : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isCancelled ? 'Booking Cancelled' : 'Visit Completed & Kitchen Sanitized',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCancelled
                          ? 'This chef booking has been cancelled. Live GPS tracking and dispatch are stopped. If applicable, refund is credited to your payment method.'
                          : 'Your executive chef completed the cooking session, served the dishes, and left your kitchen sanitized to certified hygiene standards.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Stage Progress
              _buildStageProgress(isDark, activeIndex),
              const SizedBox(height: 16),

              // 3. Chef Card
              _buildChefCard(isDark),
              const SizedBox(height: 14),

              // 4. Address Row
              if (order.address != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
                  ),
                  child: _buildAddressRow(isDark),
                ),
                const SizedBox(height: 14),
              ],

              // 5. Completion Photos (if any)
              if (order.completionPhotos.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Freshly Cooked Meal Photos',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: order.completionPhotos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, idx) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              AppConfig.resolveMediaUrl(order.completionPhotos[idx]) ?? order.completionPhotos[idx],
                              width: 110,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 110,
                                color: AppColors.slate200,
                                child: const Icon(Icons.broken_image_rounded, color: AppColors.slate400),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 6. Action buttons
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.timeline_rounded, size: 18),
                  label: const Text(
                    'View Complete Dispatch Milestones',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCompleteStatusSheet(context),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'View Booking Details & Invoice',
                  icon: Icons.receipt_long_rounded,
                  variant: EbicButtonVariant.primary,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.orderDetail,
                    arguments: {'orderId': widget.orderId},
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'Return to Home',
                  icon: Icons.home_rounded,
                  variant: EbicButtonVariant.outline,
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing "live" indicator dot.
class _LiveDot extends StatefulWidget {
  final bool active;
  const _LiveDot({required this.active});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.primaryLight : AppColors.slate400;
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              Container(
                width: 8 + 10 * _c.value,
                height: 8 + 10 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.4 * (1 - _c.value)),
                ),
              ),
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          ],
        ),
      ),
    );
  }
}
