import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ebic_button.dart';

class MapLocationResult {
  final double lat;
  final double lng;
  final String? street;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? formattedAddress;
  final bool isServiceable;
  final String? hubName;

  const MapLocationResult({
    required this.lat,
    required this.lng,
    this.street,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
    this.formattedAddress,
    this.isServiceable = false,
    this.hubName,
  });
}

/// Module 3 — Section 29 & 43: Interactive Kitchen Map Location Picker
class KitchenMapPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const KitchenMapPickerSheet({
    super.key,
    this.initialLat = 17.4319, // Default: Jubilee Hills, Hyderabad
    this.initialLng = 78.4073,
  });

  static Future<MapLocationResult?> show(
    BuildContext context, {
    double initialLat = 17.4319,
    double initialLng = 78.4073,
  }) {
    return Navigator.push<MapLocationResult>(
      context,
      MaterialPageRoute(
        builder: (ctx) => KitchenMapPickerSheet(
          initialLat: initialLat,
          initialLng: initialLng,
        ),
      ),
    );
  }

  @override
  State<KitchenMapPickerSheet> createState() => _KitchenMapPickerSheetState();
}

class _KitchenMapPickerSheetState extends State<KitchenMapPickerSheet> {
  final ApiClient _api = ApiClient();
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Coordinates tracked WITHOUT setState during camera pan ──────────────
  // These are updated directly from onCameraMove, avoiding rebuild per frame.
  double _currentLat = 0;
  double _currentLng = 0;

  // ── Serviceability state (drives bottom bar) ─────────────────────────────
  bool _isCheckingServiceability = false;
  bool _isServiceable = false;
  String? _assignedHubName;

  // ── Geocoding / search ───────────────────────────────────────────────────
  bool _isReverseGeocoding = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // ── Debounce: single timer for both geocode + serviceability ─────────────
  Timer? _idleDebounce;
  Timer? _searchDebounce;

  // ── Location ─────────────────────────────────────────────────────────────
  bool _isLocatingCurrentPosition = false;
  GoogleMapController? _mapController;

  // ── Overlay value notifier: updates coordinate label without setState ─────
  final ValueNotifier<LatLng> _pinCoordNotifier = ValueNotifier(const LatLng(0, 0));

  // ── Cached reverse-geocoded result ────────────────────────────────────────
  MapLocationResult? _cachedLocationResult;
  double? _cachedLat;
  double? _cachedLng;

  // Live hubs from the backend, shown as quick-jump chips.
  List<Map<String, dynamic>> _hubZones = [];

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _pinCoordNotifier.value = LatLng(_currentLat, _currentLng);

    _loadHubZones();

    // Kick-off initial checks WITHOUT causing a rebuild cascade.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerIdleWork();

      // If opened with default center, silently locate the user's GPS position.
      final isDefault =
          (widget.initialLat - 17.4319).abs() < 0.001 &&
          (widget.initialLng - 78.4073).abs() < 0.001;
      if (isDefault) _locateCurrentPosition(silent: true);
    });
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _mapController?.dispose();
    _pinCoordNotifier.dispose();
    super.dispose();
  }

  // ── Camera callbacks ─────────────────────────────────────────────────────

  /// Called every frame while user is dragging the map.
  /// NEVER calls setState — only updates the ValueNotifier for the
  /// coordinate label overlay so only that widget repaints.
  void _onCameraMove(CameraPosition position) {
    _currentLat = position.target.latitude;
    _currentLng = position.target.longitude;
    _pinCoordNotifier.value = position.target;
  }

  /// Called once when dragging stops. Debounces network calls so rapid
  /// stopping (e.g., inertia scrolling) doesn't fire multiple requests.
  void _onCameraIdle() {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 600), _triggerIdleWork);
  }

  /// Runs geocode + serviceability in parallel after camera settles.
  void _triggerIdleWork() {
    _checkLiveServiceability();
    _reverseGeocodeAndDisplay();
  }

  // ── Camera animation ─────────────────────────────────────────────────────

  void _animateTo(double lat, double lng, {double zoom = 16}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: zoom),
      ),
    );
  }

  // ── GPS Location ─────────────────────────────────────────────────────────

  Future<void> _locateCurrentPosition({bool silent = false}) async {
    if (!mounted) return;
    setState(() => _isLocatingCurrentPosition = true);

    String? error;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        error = 'Location services are turned off. Enable GPS and try again.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied) {
          error = 'Location permission denied. Search or drag the map instead.';
        } else if (perm == LocationPermission.deniedForever) {
          error = 'Location permission permanently denied. Enable it from settings.';
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (!mounted) return;
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _pinCoordNotifier.value = LatLng(_currentLat, _currentLng);
          _cachedLocationResult = null;
          _animateTo(pos.latitude, pos.longitude, zoom: 17);
          // _onCameraIdle will fire automatically after animateCamera settles,
          // so we don't need to manually trigger serviceability checks here.
        }
      }
    } catch (_) {
      error = 'Could not determine current location. Search or drag the map instead.';
    }

    if (!mounted) return;
    setState(() => _isLocatingCurrentPosition = false);
    if (error != null && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 3)),
      );
    }
  }

  // ── Serviceability (backend hubs & service areas) ───────────────────────

  Future<void> _loadHubZones() async {
    try {
      final res = await _api.get<List<dynamic>>(
        ApiEndpoints.serviceabilityHubs,
        requiresAuth: false,
      );
      if (!mounted || !res.success || res.data == null) return;
      setState(() {
        _hubZones = res.data!
            .whereType<Map>()
            .map((h) => {
                  'name': h['name']?.toString() ?? '',
                  'lat': (h['centerLat'] as num?)?.toDouble(),
                  'lng': (h['centerLng'] as num?)?.toDouble(),
                })
            .where((z) => z['lat'] != null && z['lng'] != null)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _checkLiveServiceability() async {
    if (!mounted) return;
    // Snapshot coords at call-time to avoid race conditions
    final lat = _currentLat;
    final lng = _currentLng;

    setState(() => _isCheckingServiceability = true);

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.serviceabilityCheck,
        body: {'latitude': lat, 'longitude': lng},
        requiresAuth: false,
      );

      if (mounted && res.success && res.data != null) {
        final isServ = res.data!['serviceable'] == true;
        final hub = res.data!['hub'] as Map<String, dynamic>?;
        setState(() {
          _isServiceable = isServ;
          _assignedHubName = hub?['name'] ?? res.data!['hubName'];
          _isCheckingServiceability = false;
        });
        return;
      }
    } catch (_) {}

    // Serviceability could not be confirmed by the backend.
    if (mounted) {
      setState(() {
        _isServiceable = false;
        _assignedHubName = null;
        _isCheckingServiceability = false;
      });
    }
  }

  // ── Reverse Geocoding ─────────────────────────────────────────────────────

  /// Updates the search bar with the resolved address. Uses a lightweight
  /// setState that only touches the TextField controller, not map tiles.
  Future<void> _reverseGeocodeAndDisplay() async {
    final lat = _currentLat;
    final lng = _currentLng;
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.mapsReverseGeocode,
        queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
        requiresAuth: false,
      );
      final formatted = res.data?['formattedAddress'] as String?;
      if (formatted != null && mounted) {
        // Only update the text — no setState needed since TextField controller
        // notifies its own listeners internally.
        _searchCtrl.text = formatted;
      }
    } catch (_) {}
  }

  // ── Search / Autocomplete ─────────────────────────────────────────────────

  Future<void> _searchLocation(String query) async {
    if (query.trim().length < 3) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    if (mounted) setState(() => _isSearching = true);

    try {
      final res = await _api.get<List<dynamic>>(
        ApiEndpoints.mapsAutocomplete,
        queryParameters: {'input': query},
        requiresAuth: false,
        fromDataJson: (json) => json as List<dynamic>,
      );

      if (mounted) {
        final predictions = res.data ?? [];
        setState(() {
          _searchResults = predictions.map((p) {
            final m = p as Map<String, dynamic>;
            final main = m['mainText'] as String? ?? m['description'] as String? ?? '';
            final sec  = m['secondaryText'] as String? ?? '';
            return {
              'display_name': sec.isNotEmpty ? '$main, $sec' : main,
              'main_text': main,
              'secondary_text': sec,
              'place_id': m['placeId'],
            };
          }).toList();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> item) async {
    final query = (item['display_name'] as String?) ?? '';

    if (query.isNotEmpty) {
      if (mounted) setState(() => _isSearching = true);
      try {
        final res = await _api.get<Map<String, dynamic>>(
          ApiEndpoints.mapsGeocode,
          queryParameters: {'address': query},
          requiresAuth: false,
        );
        final data = res.data;
        final lat = (data?['lat'] as num?)?.toDouble();
        final lng = (data?['lng'] as num?)?.toDouble();

        if (lat != null && lng != null && mounted) {
          final formatted = data?['formattedAddress'] as String? ?? query;
          _currentLat = lat;
          _currentLng = lng;
          _pinCoordNotifier.value = LatLng(lat, lng);
          _cachedLocationResult = MapLocationResult(
            lat: lat, lng: lng,
            street:    data?['street']    as String?,
            locality:  data?['locality']  as String?,
            city:      data?['city']      as String? ?? '',
            state:     data?['state']     as String? ?? '',
            postalCode: data?['postalCode'] as String?,
            formattedAddress: formatted,
          );
          _cachedLat = lat;
          _cachedLng = lng;
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
          _searchCtrl.text = formatted;
          _animateTo(lat, lng);
          _checkLiveServiceability();
          return;
        }
      } catch (_) {
        // Fallback below
      }
    }

    // Legacy lat/lon extraction
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (mounted) setState(() => _isSearching = false);
    if (lat != null && lon != null) {
      _currentLat = lat;
      _currentLng = lon;
      _pinCoordNotifier.value = LatLng(lat, lon);
      setState(() {
        _searchResults = [];
        _searchCtrl.text = item['display_name'] ?? '';
      });
      _animateTo(lat, lon);
      _checkLiveServiceability();
    }
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> _confirmLocation() async {
    setState(() => _isReverseGeocoding = true);

    // Reuse cached Place Details result if coordinates match.
    if (_cachedLocationResult != null &&
        _cachedLat != null &&
        _cachedLng != null &&
        (_cachedLat! - _currentLat).abs() < 0.0001 &&
        (_cachedLng! - _currentLng).abs() < 0.0001) {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
        Navigator.pop(
          context,
          MapLocationResult(
            lat: _currentLat, lng: _currentLng,
            street:     _cachedLocationResult!.street,
            locality:   _cachedLocationResult!.locality,
            city:       _cachedLocationResult!.city,
            state:      _cachedLocationResult!.state,
            postalCode: _cachedLocationResult!.postalCode,
            formattedAddress: _cachedLocationResult!.formattedAddress,
            isServiceable: _isServiceable,
            hubName: _assignedHubName,
          ),
        );
      }
      return;
    }

    // Server-side reverse geocode for final result.
    String? street, locality, fullAddress;
    String city = '', state = '';
    String? postalCode;

    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.mapsReverseGeocode,
        queryParameters: {
          'lat': _currentLat.toString(),
          'lng': _currentLng.toString(),
        },
        requiresAuth: false,
      );
      final data = res.data;
      if (data != null) {
        fullAddress = data['formattedAddress'] as String?;
        street      = data['street']          as String?;
        locality    = data['locality']        as String?;
        city        = data['city']            as String? ?? city;
        state       = data['state']           as String? ?? state;
        postalCode  = data['postalCode']      as String?;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isReverseGeocoding = false);
      Navigator.pop(
        context,
        MapLocationResult(
          lat: _currentLat, lng: _currentLng,
          street: street, locality: locality,
          city: city, state: state,
          postalCode: postalCode,
          formattedAddress: fullAddress,
          isServiceable: _isServiceable,
          hubName: _assignedHubName,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        title: const Text('Pinpoint Kitchen on Map'),
        actions: [
          IconButton(
            icon: _isLocatingCurrentPosition
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Pin to My Current Location',
            onPressed: _isLocatingCurrentPosition
                ? null
                : () => _locateCurrentPosition(silent: false),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── 1. Google Map ─────────────────────────────────────────────────
          // buildingsEnabled & trafficEnabled off = fewer tile layers = faster
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLat, _currentLng),
              zoom: 16,
            ),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onCameraMove: _onCameraMove,   // lightweight — no setState
            onCameraIdle: _onCameraIdle,   // debounced — no immediate setState
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: false,       // reduces draw calls on dense maps
            trafficEnabled: false,
            compassEnabled: false,
          ),

          // ── 2. Center Pin & Coordinate Overlay ────────────────────────────
          // ValueListenableBuilder: only this subtree repaints on camera move.
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<LatLng>(
                    valueListenable: _pinCoordNotifier,
                    builder: (_, coord, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.slate900.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.soup_kitchen_rounded, color: AppColors.accent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${coord.latitude.toStringAsFixed(4)}, ${coord.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Pin Marker — static, never rebuilds
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 16, spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
                  Container(
                    width: 10, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── 3. Zoom Controls ──────────────────────────────────────────────
          Positioned(
            right: 16, top: 130,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.slate800,
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.slate800,
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // ── 4. Search Bar & Area Chips ────────────────────────────────────
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10, offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search locality, society, or area...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 450),
                        () => _searchLocation(val),
                      );
                    },
                  ),
                ),

                // Search Results Dropdown
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final res = _searchResults[i];
                        final main = res['main_text'] as String?;
                        final sec  = res['secondary_text'] as String?;
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.place_rounded,
                            color: AppColors.primary, size: 20,
                          ),
                          title: Text(
                            main ?? res['display_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.slate800,
                            ),
                          ),
                          subtitle: (sec != null && sec.isNotEmpty)
                              ? Text(
                                  sec,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                )
                              : null,
                          onTap: () => _selectSearchResult(res),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // Quick Culinary Zones
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _hubZones.map((zone) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: Colors.white.withOpacity(0.92),
                          elevation: 2,
                          label: Text(
                            zone['name'] as String,
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: AppColors.slate800,
                            ),
                          ),
                          avatar: const Icon(Icons.place, size: 14, color: AppColors.primary),
                          onPressed: () {
                            final zLat = zone['lat'] as double;
                            final zLng = zone['lng'] as double;
                            _searchCtrl.text = zone['name'] as String;
                            _animateTo(zLat, zLng);
                            // onCameraIdle will handle serviceability after animation
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── 4.5. My Location FAB ──────────────────────────────────────────
          Positioned(
            right: 16, bottom: 185,
            child: FloatingActionButton.extended(
              heroTag: 'my_location_fab',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 4,
              icon: _isLocatingCurrentPosition
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _isLocatingCurrentPosition ? 'Locating...' : 'My Location',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLocatingCurrentPosition
                  ? null
                  : () => _locateCurrentPosition(silent: false),
            ),
          ),

          // ── 5. Bottom Serviceability Bar ──────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16, offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Serviceability Banner
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isCheckingServiceability
                          ? Container(
                              key: const ValueKey('checking'),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Checking hub serviceability...',
                                    style: TextStyle(fontSize: 12, color: AppColors.slate600),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              key: ValueKey(_isServiceable),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _isServiceable ? AppColors.emerald50 : AppColors.amber50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isServiceable
                                      ? AppColors.emerald700.withOpacity(0.3)
                                      : AppColors.amber700.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isServiceable
                                        ? Icons.verified_rounded
                                        : Icons.warning_amber_rounded,
                                    color: _isServiceable ? AppColors.emerald700 : AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isServiceable
                                              ? '✓ Serviceable by ${_assignedHubName ?? "EBIC Hub"}'
                                              : '⚠ Outside Current Service Area',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _isServiceable
                                                ? AppColors.emerald700
                                                : AppColors.warning,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _isServiceable
                                              ? 'Certified private chefs are available for in-home cooking here.'
                                              : 'You can still save this address. Chef bookings unlock when the nearest hub activates.',
                                          style: const TextStyle(
                                            fontSize: 10, color: AppColors.slate600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    EbicButton(
                      label: 'Use This Exact Kitchen Location',
                      icon: Icons.check_circle_rounded,
                      isLoading: _isReverseGeocoding,
                      onPressed: _confirmLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
