import 'dart:async';
import 'dart:math' as math;
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

  late double _currentLat;
  late double _currentLng;
  int _zoom = 15;

  bool _isCheckingServiceability = false;
  bool _isServiceable = false;
  String? _assignedHubName;

  bool _isReverseGeocoding = false;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Preset Culinary Zones in Hyderabad & Bengaluru
  static const List<Map<String, dynamic>> _culinaryZones = [
    {'name': 'Jubilee Hills', 'lat': 17.4319, 'lng': 78.4073, 'hub': 'HYD-WEST'},
    {'name': 'HITEC City', 'lat': 17.4435, 'lng': 78.3772, 'hub': 'HYD-WEST'},
    {'name': 'Gachibowli', 'lat': 17.4401, 'lng': 78.3489, 'hub': 'HYD-WEST'},
    {'name': 'Banjara Hills', 'lat': 17.4156, 'lng': 78.4350, 'hub': 'HYD-CENTRAL'},
    {'name': 'Central Abids', 'lat': 17.3850, 'lng': 78.4867, 'hub': 'HYD-CENTRAL'},
    {'name': 'Hyderabad East (Uppal/Boduppal)', 'lat': 17.4065, 'lng': 78.5583, 'hub': 'HYD-EAST'},
    {'name': 'Koramangala (Bengaluru)', 'lat': 12.9352, 'lng': 77.6146, 'hub': 'KORAMANGALA'},
  ];

  bool _isLocatingCurrentPosition = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _checkLiveServiceability();
    _reverseGeocodeAndDisplay();

    // If opened with default center, automatically attempt to locate user's current GPS position
    final isDefaultCoord = (widget.initialLat - 17.4319).abs() < 0.001 && (widget.initialLng - 78.4073).abs() < 0.001;
    if (isDefaultCoord) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateCurrentPosition(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _currentLat = position.target.latitude;
    _currentLng = position.target.longitude;
  }

  void _onCameraIdle() {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkLiveServiceability();
      _reverseGeocodeAndDisplay();
    });
  }

  void _animateTo(double lat, double lng, {double? zoom}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: zoom ?? _zoom.toDouble()),
      ),
    );
  }

  /// Requests device GPS location (with permission handling) and centers the
  /// map on it via Google's FusedLocationProvider / CoreLocation.
  Future<void> _locateCurrentPosition({bool silent = false}) async {
    if (!mounted) return;
    setState(() => _isLocatingCurrentPosition = true);

    String? errorMessage;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorMessage = 'Location services are turned off. Please enable GPS and try again.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied) {
          errorMessage = 'Location permission denied. You can search or drag the map instead.';
        } else if (permission == LocationPermission.deniedForever) {
          errorMessage = 'Location permission permanently denied. Enable it from app settings.';
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (!mounted) return;
          setState(() {
            _currentLat = position.latitude;
            _currentLng = position.longitude;
            _cachedLocationResult = null;
          });
          _animateTo(position.latitude, position.longitude, zoom: 17);
          _checkLiveServiceability();
          _reverseGeocodeAndDisplay();
        }
      }
    } catch (_) {
      errorMessage = 'Could not determine current location. You can search or drag the map instead.';
    }

    if (!mounted) return;
    setState(() => _isLocatingCurrentPosition = false);
    if (errorMessage != null && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 3)),
      );
    }
  }

  /// Client-side geometric calculation to guarantee instant serviceability validation
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static String? _evaluateLocalHub(double lat, double lng) {
    // 1. HYD-WEST (Jubilee Hills, HITEC City, Gachibowli) - 6.0 km
    if (_haversineKm(lat, lng, 17.4375, 78.3840) <= 6.0) return 'Hyderabad West Hub';
    // 2. HYD-EAST (Uppal, Ramanthapur, Boduppal, LB Nagar) - 5.5 km
    if (_haversineKm(lat, lng, 17.4065, 78.5583) <= 5.5) return 'Hyderabad East Hub';
    // 3. HYD-CENTRAL (Abids, Banjara Hills, Himayatnagar) - 4.5 km
    if (_haversineKm(lat, lng, 17.3850, 78.4867) <= 4.5) return 'Hyderabad Central Hub';
    // 4. KORAMANGALA (Bengaluru) - 6.0 km
    if (_haversineKm(lat, lng, 12.9352, 77.6146) <= 6.0) return 'Koramangala Hub';
    return null;
  }

  Future<void> _checkLiveServiceability() async {
    if (!mounted) return;
    setState(() => _isCheckingServiceability = true);

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.serviceabilityCheck,
        body: {
          'latitude': _currentLat,
          'longitude': _currentLng,
        },
        requiresAuth: false,
      );

      if (mounted) {
        if (res.success && res.data != null) {
          final isServ = res.data!['serviceable'] == true;
          final hub = res.data!['hub'] as Map<String, dynamic>?;
          setState(() {
            _isServiceable = isServ;
            _assignedHubName = hub?['name'] ?? res.data!['hubName'];
            _isCheckingServiceability = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback: Local geometric evaluation if backend is unreachable over Wi-Fi
    if (mounted) {
      final fallbackHub = _evaluateLocalHub(_currentLat, _currentLng);
      setState(() {
        _isServiceable = fallbackHub != null;
        _assignedHubName = fallbackHub;
        _isCheckingServiceability = false;
      });
    }
  }

  /// Automatically updates the search bar text with the real reverse-geocoded
  /// address, resolved server-side (Google Geocoding with a Nominatim
  /// fallback — no client-side API key required).
  Future<void> _reverseGeocodeAndDisplay() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.mapsReverseGeocode,
        queryParameters: {'lat': _currentLat.toString(), 'lng': _currentLng.toString()},
        requiresAuth: false,
      );
      final formatted = res.data?['formattedAddress'] as String?;
      if (formatted != null && mounted) {
        setState(() => _searchCtrl.text = formatted);
      }
    } catch (_) {}
  }

  // Cached reverse-geocoded metadata from Google Place Details or Geocoding
  MapLocationResult? _cachedLocationResult;
  double? _cachedLat;
  double? _cachedLng;

  /// Address predictions resolved server-side via /maps/autocomplete
  /// (Google Places with a Nominatim fallback — no client-side API key).
  Future<void> _searchLocation(String query) async {
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

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
            final mainText = m['mainText'] as String? ?? m['description'] as String? ?? '';
            final secText = m['secondaryText'] as String? ?? '';
            final displayName = secText.isNotEmpty ? '$mainText, $secText' : mainText;
            return {
              'display_name': displayName,
              'main_text': mainText,
              'secondary_text': secText,
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

  /// Resolves the tapped prediction's exact coordinates by geocoding its
  /// description server-side (/maps/geocode) — no client-side API key.
  Future<void> _selectSearchResult(Map<String, dynamic> item) async {
    final query = (item['display_name'] as String?) ?? '';

    if (query.isNotEmpty) {
      setState(() => _isSearching = true);
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
          final formattedAddr = data?['formattedAddress'] as String? ?? query;
          setState(() {
            _currentLat = lat;
            _currentLng = lng;
            _searchResults = [];
            _searchCtrl.text = formattedAddr;
            _isSearching = false;

            _cachedLat = lat;
            _cachedLng = lng;
            _cachedLocationResult = MapLocationResult(
              lat: lat,
              lng: lng,
              street: data?['street'] as String?,
              locality: data?['locality'] as String?,
              city: data?['city'] as String? ?? 'Hyderabad',
              state: data?['state'] as String? ?? 'Telangana',
              postalCode: data?['postalCode'] as String?,
              formattedAddress: formattedAddr,
            );
          });
          _animateTo(lat, lng);
          _checkLiveServiceability();
          return;
        }
      } catch (_) {
        // Fallback to standard lat/lon below
      }
    }

    // Standard lat/lon extraction (used by legacy result shapes)
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (mounted) setState(() => _isSearching = false);
    if (lat != null && lon != null) {
      setState(() {
        _currentLat = lat;
        _currentLng = lon;
        _searchResults = [];
        _searchCtrl.text = item['display_name'] ?? '';
      });
      _animateTo(lat, lon);
      _checkLiveServiceability();
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isReverseGeocoding = true);

    // If coordinates match cached Google Place details, reuse directly
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
            lat: _currentLat,
            lng: _currentLng,
            street: _cachedLocationResult!.street,
            locality: _cachedLocationResult!.locality,
            city: _cachedLocationResult!.city,
            state: _cachedLocationResult!.state,
            postalCode: _cachedLocationResult!.postalCode,
            formattedAddress: _cachedLocationResult!.formattedAddress,
            isServiceable: _isServiceable,
            hubName: _assignedHubName,
          ),
        );
        return;
      }
    }

    String? street;
    String? locality;
    String? city = 'Hyderabad';
    String? state = 'Telangana';
    String? postalCode;
    String? fullAddress;

    // Reverse-geocode server-side (/maps/reverse) — Google Geocoding with a
    // Nominatim fallback, no client-side API key required.
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.mapsReverseGeocode,
        queryParameters: {'lat': _currentLat.toString(), 'lng': _currentLng.toString()},
        requiresAuth: false,
      );
      final data = res.data;
      if (data != null) {
        fullAddress = data['formattedAddress'] as String?;
        street = data['street'] as String?;
        locality = data['locality'] as String?;
        city = data['city'] as String? ?? city;
        state = data['state'] as String? ?? state;
        postalCode = data['postalCode'] as String?;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isReverseGeocoding = false);
      Navigator.pop(
        context,
        MapLocationResult(
          lat: _currentLat,
          lng: _currentLng,
          street: street,
          locality: locality,
          city: city,
          state: state,
          postalCode: postalCode,
          formattedAddress: fullAddress,
          isServiceable: _isServiceable,
          hubName: _assignedHubName,
        ),
      );
    }
  }

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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Pin to My Current Location',
            onPressed: _isLocatingCurrentPosition ? null : () => _locateCurrentPosition(silent: false),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Real Google Map (drag to move the fixed center pin)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLat, _currentLng),
              zoom: _zoom.toDouble(),
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Fixed Center Pin with Pulsing Target (wrapped in IgnorePointer so it never blocks gestures!)
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slate900.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Pin Marker
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 16, spreadRadius: 2),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
                  // Shadow / point of pin
                  Container(
                    width: 10,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 40), // Offset so tip touches center
                ],
              ),
            ),
          ),

          // 3. Zoom Controls (+ / -)
          Positioned(
            right: 16,
            top: 130,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.slate800,
                  onPressed: () {
                    if (_zoom < 18) {
                      _zoom++;
                      _mapController?.animateCamera(CameraUpdate.zoomIn());
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.slate800,
                  onPressed: () {
                    if (_zoom > 10) {
                      _zoom--;
                      _mapController?.animateCamera(CameraUpdate.zoomOut());
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // 4. Top Search Bar & Quick Area Chips
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
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
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _searchLocation(val);
                      });
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
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final res = _searchResults[i];
                        final isGoogle = res['is_google'] == true;
                        final mainText = res['main_text'] as String?;
                        final secText = res['secondary_text'] as String?;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isGoogle ? Icons.place_rounded : Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            mainText ?? res['display_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800),
                          ),
                          subtitle: (secText != null && secText.isNotEmpty)
                              ? Text(
                                  secText,
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
                    children: _culinaryZones.map((zone) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: Colors.white.withOpacity(0.92),
                          elevation: 2,
                          label: Text(
                            zone['name'] as String,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800),
                          ),
                          avatar: const Icon(Icons.place, size: 14, color: AppColors.primary),
                          onPressed: () {
                            final zoneLat = zone['lat'] as double;
                            final zoneLng = zone['lng'] as double;
                            setState(() {
                              _currentLat = zoneLat;
                              _currentLng = zoneLng;
                              _searchCtrl.text = zone['name'] as String;
                            });
                            _animateTo(zoneLat, zoneLng);
                            _checkLiveServiceability();
                            _reverseGeocodeAndDisplay();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 4.5. Floating "My Location" Button (Above Bottom Action Bar)
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton.extended(
              heroTag: 'my_location_extended_fab',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 4,
              icon: _isLocatingCurrentPosition
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _isLocatingCurrentPosition ? 'Locating...' : 'My Location',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLocatingCurrentPosition ? null : () => _locateCurrentPosition(silent: false),
            ),
          ),

          // 5. Bottom Action & Live Serviceability Confirmation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Serviceability Banner
                    Container(
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
                            _isServiceable ? Icons.verified_rounded : Icons.warning_amber_rounded,
                            color: _isServiceable ? AppColors.emerald700 : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCheckingServiceability
                                      ? 'Checking hub serviceability...'
                                      : (_isServiceable
                                          ? '✓ Serviceable by ${_assignedHubName ?? "EBIC Hub"}'
                                          : '⚠ Outside Current Service Area'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _isServiceable ? AppColors.emerald700 : AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isServiceable
                                      ? 'Certified private chefs are available for in-home cooking here.'
                                      : 'You can still save this kitchen address. Chef bookings unlock when the nearest hub activates.',
                                  style: const TextStyle(fontSize: 10, color: AppColors.slate600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirm Location Button
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
