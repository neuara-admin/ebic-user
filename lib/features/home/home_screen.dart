import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/session_manager.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';
import '../health_pass/data/health_pass_repository.dart';
import '../../core/config/app_config.dart';
import '../../core/config/remote_config_service.dart';
import '../system/app_update_screen.dart';
import '../profile/widgets/kitchen_map_picker_sheet.dart';
import 'package:geolocator/geolocator.dart';
import 'widgets/auto_scroll_banner_carousel.dart';
import 'widgets/health_journey_banner.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  bool _hasPartialError = false;

  Map<String, dynamic>? _homeData;
  int _unreadNotifications = 0;
  MyHealthPassModel? _healthPass;
  ConsultationModel? _upcomingConsultation;
  ConsultationModel? _completedConsultation;
  /// Latest NO_SHOW newer than the latest delivered one — still reschedulable.
  ConsultationModel? _missedConsultation;
  /// Latest delivered consultation whose notes the dietitian hasn't saved yet.
  ConsultationModel? _notesPendingConsultation;
  /// Auto-cancelled because the dietitian never started it.
  ConsultationModel? _dietitianMissedConsultation;
  StreamSubscription<StandardSocketEnvelope>? _consultationSub;
  StreamSubscription<StandardSocketEnvelope>? _notificationSub;
  OrderModel? _activeOrder;
  AddressModel? _currentAddress;
  Map<String, dynamic>? _todayMeal;
  String? _networkErrorMessage;
  bool _isUpdateAvailable = false;

  // Local state for hydration quick-log
  double _loggedWaterLiters = 0.0;
  static const double _targetWaterLiters = 3.0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    HealthPassRepository.passUpdateNotifier.addListener(_loadHomeData);
    // Live updates: a dietitian starting/ending/completing a consultation
    // refreshes the journey card without pull-to-refresh.
    _consultationSub = RealtimeService().consultationUpdates.listen((_) => _loadHomeData(silent: true));
    _notificationSub = RealtimeService().notifications.listen((_) {
      if (mounted) setState(() => _unreadNotifications += 1);
    });
  }

  @override
  void dispose() {
    HealthPassRepository.passUpdateNotifier.removeListener(_loadHomeData);
    _consultationSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _isLoading = true;
      _hasPartialError = false;
      _networkErrorMessage = null;
    });

    try {
      // 0. Remote Config Check for Updates
      try {
        final rc = RemoteConfigService();
        await rc.fetchRemoteConfig();
        if (mounted) {
          setState(() {
            _isUpdateAvailable = rc.isOptionalUpdateAvailable(AppConfig.appVersion);
          });
        }
      } catch (_) {}

      // 1. Primary Home Aggregation (Section 61–63)
      final homeRes = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.home,
        requiresAuth: false,
      );
      if (homeRes.success && homeRes.data != null) {
        _homeData = homeRes.data;
        _unreadNotifications = (homeRes.data!['notifications']?['unreadCount'] as num?)?.toInt() ?? 0;
        final waterFromApi = (homeRes.data!['health_snapshot']?['water'] as num?)?.toDouble();
        if (waterFromApi != null && waterFromApi > 0) {
          _loggedWaterLiters = waterFromApi;
        }
        if (homeRes.data!['today_plan'] is Map<String, dynamic>) {
          _todayMeal = homeRes.data!['today_plan'] as Map<String, dynamic>;
        }
      } else {
        // Safe default home data for offline / guest mode so user is never blocked from browsing
        _homeData ??= {
          'quick_actions': [
            {'id': 'book_chef', 'title': 'Book Chef', 'icon': 'chef', 'route': AppRoutes.bookChef},
            {'id': 'diet_plan', 'title': 'Diet Plan', 'icon': 'diet_plan', 'route': AppRoutes.dietPlan},
            {'id': 'dietitian', 'title': 'Dietitian', 'icon': 'dietitian', 'route': AppRoutes.dietitian},
            {'id': 'health', 'title': 'Health', 'icon': 'health', 'route': AppRoutes.health},
          ],
        };
      }

      List<dynamic> extractList(dynamic data) {
        if (data == null) return [];
        if (data is List) return data;
        if (data is Map) {
          if (data['items'] is List) return data['items'] as List;
          if (data['orders'] is List) return data['orders'] as List;
          if (data['bookings'] is List) return data['bookings'] as List;
          if (data['data'] is List) return data['data'] as List;
          if (data['data'] is Map) {
            final nested = data['data'] as Map;
            if (nested['items'] is List) return nested['items'] as List;
            if (nested['orders'] is List) return nested['orders'] as List;
            if (nested['bookings'] is List) return nested['bookings'] as List;
            if (nested.containsKey('id') && (nested.containsKey('status') || nested.containsKey('line1'))) return [nested];
          }
          if (data.containsKey('id') && (data.containsKey('status') || data.containsKey('line1'))) return [data];
        }
        return [];
      }

      if (SessionManager().isAuthenticated) {
        // 2. Health Pass (Safely check active pass via /health-pass/current)
        try {
          final hpRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.healthPassCurrent);
          if (hpRes.success && hpRes.data != null && hpRes.data!.isNotEmpty) {
            _healthPass = MyHealthPassModel.fromJson(hpRes.data!);
          } else {
            _healthPass = null;
          }
        } catch (e) {
          debugPrint('Health pass current query info: $e');
          _healthPass = null;
        }

        // 3. Consultations (Safely parse upcoming or active consultations)
        try {
          final consultRes = await _api.get<dynamic>(ApiEndpoints.consultations);
          if (consultRes.success && consultRes.data != null) {
            final listRaw = extractList(consultRes.data);

            final list = <ConsultationModel>[];
            for (final item in listRaw) {
              if (item is Map) {
                try {
                  list.add(ConsultationModel.fromJson(Map<String, dynamic>.from(item)));
                } catch (ce) {
                  debugPrint('Skipping unparseable consultation: $ce');
                }
              }
            }

            if (list.isNotEmpty) {
              list.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

              // Booked or live only. A call that has ended is *delivered*;
              // pending notes are the dietitian's task, not an open consultation.
              final upcomingOrActive = list.where(
                (c) => c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING',
              ).toList();
              _upcomingConsultation = upcomingOrActive.isNotEmpty ? upcomingOrActive.first : null;

              final completed = list.where((c) => c.status == 'COMPLETED').toList();
              _completedConsultation = completed.isNotEmpty ? completed.first : null;

              final delivered = list.where((c) => c.isDelivered).toList();
              final latestDelivered = delivered.isNotEmpty ? delivered.first : null;
              _notesPendingConsultation =
                  latestDelivered != null && latestDelivered.isNotesPending ? latestDelivered : null;

              bool newerThanDelivered(ConsultationModel c) =>
                  latestDelivered == null || c.scheduledAt.isAfter(latestDelivered.scheduledAt);

              final missed = list.where((c) => c.status == 'NO_SHOW').toList();
              _missedConsultation =
                  missed.isNotEmpty && newerThanDelivered(missed.first) ? missed.first : null;

              final dietitianMissed = list.where((c) => c.isDietitianNoShow).toList();
              _dietitianMissedConsultation =
                  dietitianMissed.isNotEmpty && newerThanDelivered(dietitianMissed.first) ? dietitianMissed.first : null;
            } else {
              _upcomingConsultation = null;
              _completedConsultation = null;
              _missedConsultation = null;
              _notesPendingConsultation = null;
              _dietitianMissedConsultation = null;
            }
          } else {
            _upcomingConsultation = null;
            _completedConsultation = null;
            _missedConsultation = null;
            _notesPendingConsultation = null;
            _dietitianMissedConsultation = null;
          }
        } catch (e) {
          debugPrint('Consultations query info: $e');
          _upcomingConsultation = null;
          _completedConsultation = null;
          _missedConsultation = null;
          _notesPendingConsultation = null;
          _dietitianMissedConsultation = null;
        }

        // 4. Active order / Chef Booking
        try {
          final ordersRes = await _api.get<dynamic>(
            ApiEndpoints.orders,
            queryParameters: {'tab': 'active', 'limit': 1},
          );
          List<dynamic> activeItems = [];
          if (ordersRes.success && ordersRes.data != null) {
            activeItems = extractList(ordersRes.data);
          }

          if (activeItems.isEmpty) {
            final cbRes = await _api.get<dynamic>(
              ApiEndpoints.chefBookings,
              queryParameters: {'tab': 'active', 'limit': 1},
            );
            if (cbRes.success && cbRes.data != null) {
              activeItems = extractList(cbRes.data);
            }
          }

          if (activeItems.isNotEmpty && activeItems.first is Map) {
            _activeOrder = OrderModel.fromJson(Map<String, dynamic>.from(activeItems.first as Map));
          } else {
            _activeOrder = null;
          }
        } catch (e) {
          debugPrint('Active order query info: $e');
          _activeOrder = null;
        }

        // 5. Today's diet plan (Optional refresh from todayDietPlan endpoint)
        try {
          final mealRes = await _api.get<Map<String, dynamic>>(ApiEndpoints.todayDietPlan);
          if (mealRes.success && mealRes.data != null) {
            _todayMeal = mealRes.data;
          }
        } catch (e) {
          debugPrint('Today diet plan query info: $e');
        }

        // 6. Delivery Kitchen Address for Header (Section 29)
        try {
          final addrRes = await _api.get<dynamic>(ApiEndpoints.customerAddresses);
          if (addrRes.success && addrRes.data != null) {
            final rawAddresses = extractList(addrRes.data);
            final addresses = <AddressModel>[];
            for (final item in rawAddresses) {
              if (item is Map) {
                try {
                  addresses.add(AddressModel.fromJson(Map<String, dynamic>.from(item)));
                } catch (_) {}
              }
            }
            if (addresses.isNotEmpty) {
              _currentAddress = addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => addresses.first,
              );
            }
          }
        } catch (e) {
          debugPrint('Address fetch info: $e');
        }
      } else {
        _healthPass = null;
        _upcomingConsultation = null;
        _completedConsultation = null;
        _activeOrder = null;
      }

      // Auto-detect & auto-select current kitchen address (for both logged-in and guest users)
      await _autoDetectCurrentKitchenAddress();
    } catch (e) {
      debugPrint('Home screen load exception: $e');
      if (_homeData == null) {
        _hasPartialError = true;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Automatically locates current GPS coordinates and reverse-geocodes to kitchen address
  Future<void> _autoDetectCurrentKitchenAddress() async {
    if (_currentAddress != null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );

          final res = await _api.get<Map<String, dynamic>>(
            ApiEndpoints.mapsReverseGeocode,
            queryParameters: {
              'lat': pos.latitude.toString(),
              'lng': pos.longitude.toString(),
            },
            requiresAuth: false,
          );

          if (res.success && res.data != null) {
            final formatted = res.data!['formattedAddress'] as String?;
            final locality = res.data!['locality'] as String?;
            final city = res.data!['city'] as String?;

            if (mounted) {
              setState(() {
                _currentAddress = AddressModel(
                  id: 'current_gps_kitchen',
                  label: 'Current Kitchen',
                  line1: formatted?.isNotEmpty == true
                      ? formatted!
                      : 'Current Kitchen Location',
                  locality: locality ?? city ?? 'Current Location',
                  city: city ?? '',
                  state: res.data!['state']?.toString() ?? '',
                  postalCode: res.data!['postalCode']?.toString() ?? '',
                  lat: pos.latitude,
                  lng: pos.longitude,
                  isDefault: true,
                );
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-detect GPS address info: $e');
    }

    // No saved or detected address: the header prompts the user to pick one.
  }

  bool get _hasActiveHealthPass =>
      _healthPass != null && _healthPass!.isActive && !_healthPass!.isExpired;

  /// Evaluates exact Health Pass journey stage
  HealthPassStage get _healthPassStage {
    if (!_hasActiveHealthPass) {
      return HealthPassStage.noPass;
    }
    if (_upcomingConsultation != null) {
      if (_upcomingConsultation!.status == 'IN_PROGRESS') {
        return HealthPassStage.consultationInProgress;
      }
      return HealthPassStage.consultationScheduled;
    }
    if (_missedConsultation != null) {
      return HealthPassStage.consultationMissed;
    }
    if (_dietitianMissedConsultation != null) {
      return HealthPassStage.consultationDietitianMissed;
    }
    if (_notesPendingConsultation != null) {
      return HealthPassStage.consultationAwaitingNotes;
    }
    if (_completedConsultation != null) {
      final hasPlan = _todayMeal?['hasPlan'] == true ||
          ((_todayMeal?['meals'] as List?)?.isNotEmpty ?? false);
      if (hasPlan) {
        return HealthPassStage.mealsAssigned;
      }
      return HealthPassStage.mealCurationInProgress;
    }
    if (_healthPass!.endDate == null) {
      return HealthPassStage.kickoffNeeded;
    }
    return HealthPassStage.subscriptionActive;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _quickLogWater() {
    if (!SessionManager().isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    setState(() {
      _loggedWaterLiters = (_loggedWaterLiters + 0.25).clamp(0.0, 6.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+250ml logged! Current total: ${_loggedWaterLiters.toStringAsFixed(2)}L 💧'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<BannerMediaItem>? _parseBanners() {
    final rawBanners = _homeData?['banners'] as List<dynamic>?;
    if (rawBanners == null || rawBanners.isEmpty) return null;

    try {
      final items = rawBanners.map<BannerMediaItem>((b) {
        final map = b as Map<String, dynamic>;
        String? colorHex = map['tagColor']?.toString();
        Color tagColor = const Color(0xFF059669);
        if (colorHex != null && colorHex.startsWith('#')) {
          final hex = colorHex.replaceFirst('#', '');
          if (hex.length == 6) {
            tagColor = Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            tagColor = Color(int.parse(hex, radix: 16));
          }
        }

        return BannerMediaItem(
          id: map['id']?.toString() ?? 'banner',
          title: map['title']?.toString() ?? '',
          subtitle: map['subtitle']?.toString() ?? '',
          tag: map['tag']?.toString() ?? 'FEATURED',
          tagColor: tagColor,
          imageUrl: map['imageUrl']?.toString() ?? '',
          isVideo: map['isVideo'] == true,
          videoUrl: map['videoUrl']?.toString(),
          videoDuration: map['videoDuration']?.toString(),
          autoPlay: map['autoPlay'] != false, // default true if not specified
          isMuted: map['isMuted'] == true,    // default false if not specified
          targetRoute: map['targetRoute']?.toString(),
          ctaText: map['ctaText']?.toString(),
          routeArguments: map['routeArguments'] is Map<String, dynamic>
              ? map['routeArguments'] as Map<String, dynamic>
              : null,
        );
      }).toList();

      // Sort by backend priority (lower number = first)
      items.sort((a, b) {
        final pa = (rawBanners.firstWhere(
          (r) => (r as Map)['id'] == a.id,
          orElse: () => {'priority': 999},
        ) as Map)['priority'] as num? ?? 999;
        final pb = (rawBanners.firstWhere(
          (r) => (r as Map)['id'] == b.id,
          orElse: () => {'priority': 999},
        ) as Map)['priority'] as num? ?? 999;
        return pa.compareTo(pb);
      });

      return items;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isAuthed = SessionManager().isAuthenticated;
    final userName = user?['name'] ?? (isAuthed ? 'Friend' : 'Guest');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        elevation: 0,
        foregroundColor: textPrimary,
        title: InkWell(
          onTap: () async {
            if (isAuthed) {
              await Navigator.pushNamed(context, AppRoutes.addresses);
              _loadHomeData();
            } else {
              final picked = await KitchenMapPickerSheet.show(
                context,
                initialLat: _currentAddress?.lat ?? 17.4435,
                initialLng: _currentAddress?.lng ?? 78.3772,
              );
              if (picked != null && mounted) {
                setState(() {
                  _currentAddress = AddressModel(
                    id: 'guest_picked_kitchen',
                    label: picked.hubName != null ? 'Kitchen (${picked.hubName})' : 'Selected Kitchen',
                    line1: picked.formattedAddress ?? 'Selected Kitchen Location',
                    locality: picked.locality ?? picked.city ?? 'Selected Kitchen',
                    city: picked.city ?? '',
                    state: picked.state ?? '',
                    postalCode: picked.postalCode ?? '',
                    lat: picked.lat,
                    lng: picked.lng,
                    isDefault: true,
                  );
                });
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _currentAddress != null
                            ? '${_currentAddress!.kitchenLabelDisplayName} • ${_currentAddress!.locality ?? _currentAddress!.city ?? _currentAddress!.line1}'
                            : 'Select Kitchen Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 16),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${_getGreeting()}, $userName 👋',
                  style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: _unreadNotifications > 0
                ? Badge(
                    label: Text('$_unreadNotifications', style: const TextStyle(fontSize: 10)),
                    backgroundColor: AppColors.danger,
                    child: Icon(Icons.notifications_none_rounded, color: textPrimary),
                  )
                : Icon(Icons.notifications_none_rounded, color: textPrimary),
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications).then((_) => _loadHomeData()),
          ),
          InkWell(
            onTap: () => widget.onNavigateTab?.call(4),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySubtle,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _networkErrorMessage != null && _homeData == null
              ? _buildNetworkErrorView()
              : RefreshIndicator(
                  onRefresh: _loadHomeData,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 600,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 1. In-App Update Banner
                      if (_isUpdateAvailable) ...[
                        _buildUpdateBanner(),
                        const SizedBox(height: 12),
                      ],

                      // Guest Exploration Banner (App Store / Play Store compliance)
                      if (!isAuthed) ...[
                        _buildGuestBanner(isDark),
                        const SizedBox(height: 12),
                      ],

                      // 2. Urgent Video Call Alert (if consultation is active right now)
                      if (_upcomingConsultation?.status == 'IN_PROGRESS') ...[
                        _buildUrgentVideoCallBanner(_upcomingConsultation!),
                        const SizedBox(height: 12),
                      ],

                      // 3. Auto-Scrolling Interactive Media Carousel (TOP POSITION)
                      if (_parseBanners() case final banners? when banners.isNotEmpty) ...[
                        RepaintBoundary(
                          child: AutoScrollBannerCarousel(banners: banners),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 4. Primary State-Driven Action Card (Active Chef Order OR Journey Stage Card)
                      _buildActiveServiceCard(),
                      const SizedBox(height: 16),

                      // 6. Health Journey Stepper (Only for Health Pass members)
                      if (_healthPassStage != HealthPassStage.noPass) ...[
                        HealthJourneyStepper(
                          currentStage: _healthPassStage,
                          dietitianName: _upcomingConsultation?.dietitianName ?? _completedConsultation?.dietitianName,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 7. Quick Actions Row
                      _buildQuickActionsRow(),
                      const SizedBox(height: 16),

                      // 8. Today's Plan & Assigned Meals Card (Only for active Health Pass members)
                      if (_hasActiveHealthPass) ...[
                        _buildTodayPlanCard(),
                        const SizedBox(height: 16),
                      ],

                      // 9. Health Pass Section (Active Membership, Expired Renewal, or New User Showcase)
                      _buildHealthPassSection(),
                      const SizedBox(height: 16),

                      // 10. Health Progress & Vitals Snapshot Card
                      _buildHealthSnapshotCard(),
                      const SizedBox(height: 16),

                      // 11. Assigned Dietitian Card (when consultation is completed)
                      if (_completedConsultation != null) ...[
                        _buildAssignedDietitianCard(_completedConsultation!),
                        const SizedBox(height: 16),
                      ],

                      // 12. Contextual Refer & Earn Card (Section 5 & 6)
                      _buildContextualReferralCard(),
                      const SizedBox(height: 16),

                      // 13. Partial Error Warning (if any)
                      if (_hasPartialError) ...[
                        _buildPartialErrorBanner(),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  // ───────────────────────── 1. Top Update & Call Banners ─────────────────────────

  Widget _buildGuestBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exploring as Guest',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sign in anytime to book chefs & save health metrics.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.welcome),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Version Available',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                ),
                Text(
                  'Update to v${RemoteConfigService().latestVersion} for the latest features.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppUpdateScreen()),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentVideoCallBanner(ConsultationModel consultation) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VIDEO SESSION ACTIVE NOW',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                Text(
                  'Dr. ${consultation.dietitianName} is waiting',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Tap to join your consultation room',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF92400E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.consultationVideo,
                arguments: {'consultation': consultation},
              ).then((_) => _loadHomeData());
            },
            child: const Text('Join Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 2. State-Driven Active Card ─────────────────────────

  Widget _buildActiveServiceCard() {
    // A. Active Chef Booking
    if (_activeOrder != null) {
      if (_activeOrder!.isCancelled) {
        return _buildCancelledOrFailedOrderCard(_activeOrder!);
      }
      return _buildLiveChefOrderCard(_activeOrder!);
    }

    // B. No Active Chef Booking: Display Journey Stage Card
    return _buildJourneyStageHeroCard(_healthPassStage);
  }

  Widget _buildLiveChefOrderCard(OrderModel order) {
    final status = order.status.toUpperCase();
    final isEnRoute = status == 'EN_ROUTE' || status == 'CHEF_EN_ROUTE';
    final isArrived = status == 'ARRIVED' || status == 'WAITING_CUSTOMER';
    final isCooking = status == 'COOKING' || status == 'PLATING' || status == 'IN_PROGRESS';
    final isSearching = status == 'SEARCHING' || status == 'CREATED' || status == 'PENDING';

    return EbicCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail, arguments: {'orderId': order.id}).then((_) => _loadHomeData()),
      gradient: isEnRoute
          ? const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isEnRoute ? AppColors.primaryLight : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.isInstant ? 'INSTANT CHEF DISPATCH' : 'ACTIVE CHEF BOOKING',
                    style: TextStyle(
                      color: isEnRoute ? AppColors.primaryLight : AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                status: order.status,
                color: isEnRoute ? Colors.white : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                isEnRoute ? '🛵' : (isArrived ? '📍' : (isCooking ? '🍳' : '🧑‍🍳')),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSearching
                          ? 'Assigning Executive Chef...'
                          : (isEnRoute
                              ? 'Chef is on the way'
                              : (isArrived
                                  ? 'Chef has arrived at doorstep'
                                  : (isCooking ? 'Cooking in progress' : 'Chef ${order.chefName} Assigned'))),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isEnRoute ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    Text(
                      isEnRoute
                          ? '${order.occasionLabel} • Arriving in ~18 mins'
                          : (isArrived
                              ? 'Share Start OTP to begin cooking'
                              : (isCooking
                                  ? 'Estimated cook time: ${order.cookingTimeMinutes} mins'
                                  : 'Preparing ingredients & packing kit')),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isEnRoute ? Colors.white70 : AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: isEnRoute ? 'Track Live on GPS' : (isArrived ? 'View OTP & Details' : 'View Booking Details'),
                  icon: isEnRoute ? Icons.navigation_rounded : Icons.receipt_long_rounded,
                  onPressed: () {
                    if (isEnRoute) {
                      Navigator.pushNamed(context, AppRoutes.chefTracking, arguments: {'orderId': order.id}).then((_) => _loadHomeData());
                    } else {
                      Navigator.pushNamed(context, AppRoutes.orderDetail, arguments: {'orderId': order.id}).then((_) => _loadHomeData());
                    }
                  },
                ),
              ),
              if (order.meals.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  icon: Icon(Icons.checklist_rounded, color: isEnRoute ? Colors.white : AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: isEnRoute ? Colors.white.withOpacity(0.18) : AppColors.primarySubtle,
                  ),
                  tooltip: 'Pantry Preparation',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.preparationChecklist, arguments: {'orderId': order.id});
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledOrFailedOrderCard(OrderModel order) {
    final isNoSupply = order.status.toUpperCase() == 'FAILED_NO_SUPPLY';

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
                  Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text('BOOKING STATUS', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isNoSupply ? 'No Executive Chef Available in Area' : 'Chef Booking Cancelled',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            isNoSupply
                ? 'We could not find an available chef in your area at this time. Your payment is 100% refunded.'
                : 'This chef booking was cancelled. Your refund has been initiated to your source account.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 160,
            child: EbicButton(
              label: 'Book Chef Again',
              icon: Icons.refresh_rounded,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChef),
            ),
          ),
        ],
      ),
    );
  }

  /// Journey Stage Card when there is NO active chef order
  Widget _buildJourneyStageHeroCard(HealthPassStage stage) {
    switch (stage) {
      // 1. Without Health Pass
      case HealthPassStage.noPass:
        return EbicCard(
          padding: const EdgeInsets.all(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ON-DEMAND CHEF DISPATCH',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                    ),
                  ),
                  const Text('⚡ 20-min dispatch', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Private Chef in Your Kitchen',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose your favorite dishes or healthy diet recipes. An executive chef arrives with fresh ingredients and cleans up.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: EbicButton(
                      label: 'Browse Chef Menu',
                      icon: Icons.restaurant_menu_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChefCatalogue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: EbicButton(
                      label: 'Book a Chef',
                      icon: Icons.soup_kitchen_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: () {
                        if (!SessionManager().isAuthenticated) {
                          Navigator.pushNamed(context, AppRoutes.login);
                          return;
                        }
                        Navigator.pushNamed(context, AppRoutes.bookChef);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      // 2. Health Pass Owned, Kickoff Consultation Needed
      case HealthPassStage.kickoffNeeded:
        return EbicCard(
          padding: const EdgeInsets.all(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'STEP 1: KICKOFF CALL',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                  const Text('Activate Pass ⏳', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Schedule Clinical Kickoff Call',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect with your clinical nutritionist to evaluate vitals, assign your doctor, and activate your Health Pass countdown.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 16),
              EbicButton(
                label: 'Schedule Kickoff Consultation',
                icon: Icons.calendar_today_rounded,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadHomeData()),
              ),
            ],
          ),
        );

      // 3. Consultation Scheduled & Upcoming
      case HealthPassStage.consultationScheduled:
        final c = _upcomingConsultation!;
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.event_available_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('UPCOMING CONSULTATION', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ],
                  ),
                  StatusBadge.info('CONFIRMED'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Clinical Session with Dr. ${c.dietitianName}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDateTime(c.scheduledAt)} • 45-min HD Video Consultation',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: EbicButton(
                      label: 'View Session Details',
                      icon: Icons.video_call_rounded,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.consultationDetail, arguments: {'consultation': c}).then((_) => _loadHomeData());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      // 4. Consultation In Progress
      case HealthPassStage.consultationInProgress:
        final c = _upcomingConsultation!;
        return EbicCard(
          padding: const EdgeInsets.all(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFB45309), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('VIDEO SESSION LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  StatusBadge.warning('ACTIVE'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Consultation with Dr. ${c.dietitianName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dietitian is reviewing your dietary profile and clinical records in real-time.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              EbicButton(
                label: 'Join Video Call Now',
                icon: Icons.video_call_rounded,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.consultationVideo, arguments: {'consultation': c}).then((_) => _loadHomeData());
                },
              ),
            ],
          ),
        );

      // 4b. Video call done, dietitian finalizing notes (VIDEO_COMPLETED)
      case HealthPassStage.consultationAwaitingNotes:
        final c = _notesPendingConsultation!;
        final passStart = _healthPass?.startDate;
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0369A1), size: 18),
                      SizedBox(width: 8),
                      Text('CONSULTATION COMPLETED', style: TextStyle(color: Color(0xFF0369A1), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ],
                  ),
                  StatusBadge.info(c.isInitial ? 'KICKOFF' : 'FOLLOW-UP'),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Consultation completed',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Your consultation with ${c.dietitianDisplayName}${c.callEndedAt != null ? ' on ${_formatDateTime(c.callEndedAt!)}' : ''} is complete. Your dietitian\'s notes are pending.'
                '${c.isInitial && passStart != null ? '\nYour Health Pass started on ${DateFormat('d MMM yyyy').format(passStart)}.' : ''}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.35),
              ),
              const SizedBox(height: 16),
              EbicButton(
                label: 'View Consultation',
                icon: Icons.description_outlined,
                variant: EbicButtonVariant.outline,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.consultationDetail, arguments: {'consultation': c}).then((_) => _loadHomeData(silent: true));
                },
              ),
            ],
          ),
        );

      // 4d. Dietitian never started the call — auto-cancelled, not counted
      case HealthPassStage.consultationDietitianMissed:
        final c = _dietitianMissedConsultation!;
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: Color(0xFFB45309), size: 18),
                  SizedBox(width: 8),
                  Text('CONSULTATION CANCELLED', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${c.dietitianDisplayName} couldn\'t join',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Your consultation on ${_formatDateTime(c.scheduledAt)} wasn\'t started by your dietitian, so it was cancelled and not counted against your plan. Please book a new time.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.35),
              ),
              const SizedBox(height: 16),
              EbicButton(
                label: 'Book a New Time',
                icon: Icons.calendar_today_rounded,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadHomeData(silent: true)),
              ),
            ],
          ),
        );

      // 4c. Consultation missed (NO_SHOW) — reschedule the same one
      case HealthPassStage.consultationMissed:
        final c = _missedConsultation!;
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text('CONSULTATION MISSED', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'You missed your ${c.isInitial ? 'kickoff' : 'follow-up'} with ${c.dietitianDisplayName}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'It was scheduled for ${_formatDateTime(c.scheduledAt)}. Reschedule it at no extra cost — it still counts as this booking.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.35),
              ),
              const SizedBox(height: 16),
              EbicButton(
                label: 'Reschedule Consultation',
                icon: Icons.event_repeat_rounded,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.consultationDetail, arguments: {'consultation': c}).then((_) => _loadHomeData(silent: true));
                },
              ),
            ],
          ),
        );

      // 5. Consultation Done, Meal Curation In Progress
      case HealthPassStage.mealCurationInProgress:
        final doctor = _completedConsultation?.dietitianName ?? 'your Clinical Dietitian';
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 18),
                      SizedBox(width: 8),
                      Text('STEP 3: MEAL CURATION', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('CURATING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Dr. $doctor is Curating Your Meals',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your consultation notes and clinical targets are being transformed into custom daily recipes. Estimated within 24 hours.',
                style: TextStyle(fontSize: 12.5, color: AppColors.slate600, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: EbicButton(
                      label: 'Chat with Dietitian',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.dietitianChat),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EbicButton(
                      label: 'Book a Chef',
                      isOutlined: true,
                      icon: Icons.soup_kitchen_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChef),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      // 6. Meals Assigned and Ready!
      case HealthPassStage.mealsAssigned:
        return EbicCard(
          padding: const EdgeInsets.all(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF047857), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MEALS ASSIGNED & VERIFIED',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                  const Text('✓ Doctor Approved', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Diet Plan is Live!',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              const Text(
                'Personalized recipes assigned for today. Book an executive chef to cook these exact clinical meals at home.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: EbicButton(
                      label: 'Book Chef for Assigned Meal',
                      icon: Icons.soup_kitchen_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChefAssigned),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                      child: const Text('View Plan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      // 7. Active Subscription Ongoing
      case HealthPassStage.subscriptionActive:
        return EbicCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('HEALTH PASS ACTIVE', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ],
                  ),
                  StatusBadge.success('ACTIVE'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _healthPass?.planName ?? 'EBIC Health Pass',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _healthPass?.endDate != null
                    ? 'Valid until ${_formatDate(_healthPass!.endDate!)} • ${_healthPass?.coveredMembersCount ?? 1} Covered'
                    : 'Unlimited clinical dietitian consultations & home dining discounts.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: EbicButton(
                      label: 'Book Chef',
                      icon: Icons.soup_kitchen_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.bookChefAssigned),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EbicButton(
                      label: 'Diet Plan',
                      isOutlined: true,
                      icon: Icons.restaurant_menu_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  // ───────────────────────── 3. Quick Actions Row ─────────────────────────

  Widget _buildQuickActionsRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      _QuickAction(
        emoji: '📖',
        label: 'Chef\nMenu',
        onTap: () => Navigator.pushNamed(context, AppRoutes.bookChefCatalogue),
      ),
      _QuickAction(
        emoji: '🍳',
        label: 'Book\nChef',
        onTap: () {
          if (!SessionManager().isAuthenticated) {
            Navigator.pushNamed(context, AppRoutes.login);
            return;
          }
          if (_healthPassStage == HealthPassStage.mealsAssigned) {
            Navigator.pushNamed(context, AppRoutes.bookChefAssigned);
          } else {
            Navigator.pushNamed(context, AppRoutes.bookChef);
          }
        },
      ),
      _QuickAction(
        emoji: '🥗',
        label: 'Diet\nPlan',
        onTap: () {
          if (!SessionManager().isAuthenticated) {
            Navigator.pushNamed(context, AppRoutes.login);
            return;
          }
          Navigator.pushNamed(context, AppRoutes.dietPlan);
        },
      ),
      _QuickAction(
        emoji: '👩‍⚕️',
        label: 'Dietitian',
        onTap: () {
          if (!SessionManager().isAuthenticated) {
            Navigator.pushNamed(context, AppRoutes.login);
            return;
          }
          Navigator.pushNamed(context, AppRoutes.dietitian);
        },
      ),
      _QuickAction(
        emoji: '❤️',
        label: 'Health\nHub',
        onTap: () => widget.onNavigateTab?.call(1),
      ),
    ];


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionItem(
                    action: actions[i],
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required _QuickAction action,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(action.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            SizedBox(
              height: 26,
              child: Center(
                child: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.slate800,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 4. Today's Plan & Assigned Meals Card ─────────────────────────

  Widget _buildTodayPlanCard() {
    if (!_hasActiveHealthPass) {
      return const SizedBox.shrink();
    }

    final todayPlanData = _todayMeal ?? (_homeData?['today_plan'] as Map<String, dynamic>?);
    final hasPlan = todayPlanData?['hasPlan'] == true;
    final rawMeals = (todayPlanData?['meals'] as List<dynamic>?) ?? [];

    final List<Map<String, dynamic>> meals = hasPlan && rawMeals.isNotEmpty
        ? rawMeals
            .map((m) => {
                  'occasion': m['occasion']?.toString() ?? 'Meal',
                  'name': m['name']?.toString() ?? 'Personalized Meal',
                  'completed': m['completed'] == true,
                })
            .toList()
        : [
            {'occasion': 'Breakfast', 'name': 'Spinach & Moong Dal Chilla • 240 kcal', 'completed': true},
            {'occasion': 'Lunch', 'name': 'Balanced High-Protein Thali • 480 kcal', 'completed': false},
            {'occasion': 'Dinner', 'name': 'Grilled Herb Protein & Veggies • 320 kcal', 'completed': false},
          ];

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Curated Diet Plan",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('Full Plan →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...meals.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildMealPlanRow(m['occasion'] as String, m['name'] as String, m['completed'] as bool),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
              label: Text(
                _healthPassStage == HealthPassStage.mealsAssigned
                    ? 'Book Chef for Assigned Meal'
                    : 'Book Chef to Cook This',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              onPressed: () {
                if (_healthPassStage == HealthPassStage.mealsAssigned) {
                  Navigator.pushNamed(context, AppRoutes.bookChefAssigned);
                } else {
                  Navigator.pushNamed(context, AppRoutes.bookChef);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanRow(String occasion, String name, bool completed) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: completed ? AppColors.success : AppColors.slate400,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          '$occasion: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.slate800),
        ),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 5. Health Snapshot & Progress Card ─────────────────────────

  Widget _buildHealthSnapshotCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Guest / Not Logged In State -> Dedicated Preview Card
    if (!SessionManager().isAuthenticated) {
      return _buildGuestHealthSnapshotCard(isDark);
    }

    final snapshot = _homeData?['health_snapshot'] as Map<String, dynamic>?;
    final num? weightNum = snapshot?['weight'] as num?;
    final num? stepsNum = snapshot?['steps'] as num?;
    final dynamic rawSleep = snapshot?['sleep'];
    final String? sleepStr = rawSleep != null
        ? (rawSleep.toString().endsWith('h') ? rawSleep.toString() : '${rawSleep}h')
        : null;
    final num? adherenceNum = (snapshot?['adherence'] ?? snapshot?['dietAdherence']) as num?;

    final bool hasVitals = weightNum != null || stepsNum != null || sleepStr != null || _loggedWaterLiters > 0;

    final hydrationRatio = _targetWaterLiters > 0
        ? (_loggedWaterLiters / _targetWaterLiters).clamp(0.0, 1.0)
        : 0.0;
    final stepRatio = stepsNum != null ? (stepsNum / 10000).clamp(0.0, 1.0) : 0.0;

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Health Progress & Vitals',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab?.call(1),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('Health Hub →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hydration Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('💧', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        _loggedWaterLiters > 0
                            ? 'Daily Hydration (${_loggedWaterLiters.toStringAsFixed(1)} / ${_targetWaterLiters.toStringAsFixed(0)}L)'
                            : 'Daily Hydration (0.0 / ${_targetWaterLiters.toStringAsFixed(0)}L)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.slate200 : AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _quickLogWater,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Text('+250ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: hydrationRatio,
                  minHeight: 7,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daily Steps Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('👟', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        stepsNum != null
                            ? 'Active Steps ($stepsNum / 10,000)'
                            : 'Active Steps (— / 10,000)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.slate200 : AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    stepsNum != null ? '${(stepRatio * 100).toInt()}%' : '0%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stepRatio,
                  minHeight: 7,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics 3-column stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSnapshotMetric(
                'Weight',
                weightNum != null ? '${weightNum.toStringAsFixed(1)} kg' : '—',
                weightNum != null ? '🎯 Target: 65 kg' : 'Tap to log',
                isDark: isDark,
              ),
              Container(width: 1, height: 36, color: isDark ? AppColors.slate800 : AppColors.slate200),
              _buildSnapshotMetric(
                'Sleep',
                sleepStr ?? '—',
                sleepStr != null ? '😴 Restful' : 'Tap to log',
                isDark: isDark,
              ),
              Container(width: 1, height: 36, color: isDark ? AppColors.slate800 : AppColors.slate200),
              _buildSnapshotMetric(
                'Diet Adherence',
                adherenceNum != null ? '${adherenceNum.toInt()}%' : (_hasActiveHealthPass ? '100%' : '—'),
                adherenceNum != null ? '🥗 Verified' : (_hasActiveHealthPass ? '🥗 In Progress' : 'No plan active'),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!hasVitals) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No vitals logged yet today. Tap below or quick-log water above!',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(
            width: double.infinity,
            child: EbicButton(
              label: hasVitals ? 'Update Health Vitals' : 'Log Health Vitals',
              icon: Icons.add_chart_rounded,
              onPressed: () => widget.onNavigateTab?.call(1),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Guest State: Health Progress & Vitals ─────────────────────────

  Widget _buildGuestHealthSnapshotCard(bool isDark) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Progress & Vitals',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      Text(
                        'Guest Mode • Real-time Tracking',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'SYNC OFF',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Track your daily hydration, active steps, sleep, and diet adherence seamlessly with an EBIC account.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            ),
          ),
          const SizedBox(height: 14),

          // 4 Vitals Preview Tiles
          Row(
            children: [
              Expanded(
                child: _buildGuestMetricTile(
                  icon: '💧',
                  title: 'Hydration',
                  value: '—',
                  goal: '3.0 L goal',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGuestMetricTile(
                  icon: '👟',
                  title: 'Steps',
                  value: '—',
                  goal: '10k goal',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGuestMetricTile(
                  icon: '⚖️',
                  title: 'Weight',
                  value: '—',
                  goal: 'Target log',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGuestMetricTile(
                  icon: '😴',
                  title: 'Sleep',
                  value: '—',
                  goal: '8h restful',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Informational Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF047857).withValues(alpha: 0.35) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sign in to link fitness wearables and save your personal vitals.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.slate200 : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: EbicButton(
                  label: 'Sign In to Log Vitals',
                  icon: Icons.login_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate300,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Health Hub',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMetricTile({
    required String icon,
    required String title,
    required String value,
    required String goal,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800.withValues(alpha: 0.6) : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            goal,
            style: TextStyle(
              fontSize: 8.5,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotMetric(String label, String value, String hint, {bool isDark = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 9.5,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 6. Health Pass Card & Promotion ─────────────────────────

  // ───────────────────────── 6. Health Pass Section (Showcase, Renewal, or Active Details) ─────────────────────────

  Widget _buildHealthPassSection() {
    final hasPass = _healthPass != null && _healthPass!.isActive && !_healthPass!.isExpired;
    final isExpired = _healthPass != null && (_healthPass!.isExpired || _healthPass!.status == 'EXPIRED' || (!_healthPass!.isActive && _healthPass!.status != 'CANCELLED'));

    // Case 1: Expired Health Pass -> Prominent Renewal Section
    if (isExpired) {
      return _buildExpiredHealthPassCard(_healthPass!);
    }

    // Case 2: No Health Pass Taken Yet -> High-Converting VIP Showcase Section
    if (!hasPass) {
      return _buildNoHealthPassShowcaseCard();
    }

    // Case 3: Active Health Pass -> Active Membership Details
    return _buildActiveHealthPassCard(_healthPass!);
  }

  Widget _buildExpiredHealthPassCard(MyHealthPassModel pass) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'EBIC Health Pass',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EXPIRED',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${pass.planName} Expired',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(
            pass.endDate != null
                ? 'Your membership expired on ${_formatDate(pass.endDate)}. In-home chef visits, clinical dietitian consults, and tailored nutrition charts are currently paused.'
                : 'Your membership is inactive. Renew now to restore your in-home chefs and clinical nutrition care.',
            style: const TextStyle(color: AppColors.slate600, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),

          // Perks to restore
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reactivate your monthly in-home chef visit quota',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resume 1-on-1 clinical dietitian consultations & lab reviews',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text(
                'Renew Health Pass Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHealthPassShowcaseCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'CLINICAL & CHEF SUBSCRIPTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'UP TO 35% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'EBIC Health Pass Membership',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The complete clinical nutrition & home dining subscription for your entire household.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),

          // 4 Feature Pillars in a 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildHealthPassFeatureItem(
                  icon: Icons.medical_services_outlined,
                  title: 'Clinical Dietitian',
                  subtitle: '1-on-1 consultations',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthPassFeatureItem(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'In-Home Chefs',
                  subtitle: 'Cooked in kitchen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHealthPassFeatureItem(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'Personal Diet Plan',
                  subtitle: 'Macro & calorie goals',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHealthPassFeatureItem(
                  icon: Icons.groups_rounded,
                  title: 'Whole Household',
                  subtitle: 'Up to 6 members',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text(
                'Explore Health Pass Plans',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPassFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF34D399), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHealthPassCard(MyHealthPassModel pass) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.health_and_safety, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'EBIC Health Pass',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge(
                label: 'ACTIVE',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pass.planName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            pass.endDate != null
                ? 'Valid until ${_formatDate(pass.endDate!)} • ${pass.coveredMembersCount} Household Members Covered'
                : 'Pass countdown starts upon clinical kickoff consultation',
            style: const TextStyle(color: AppColors.slate500, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          EbicButton(
            label: 'Manage Health Pass',
            icon: Icons.card_membership_rounded,
            onPressed: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3); // Health Pass is tab index 3 in MainNavShell
              } else {
                Navigator.pushNamed(context, AppRoutes.healthPass);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDietitianCard(ConsultationModel consultation) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'My Clinical Dietitian',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ASSIGNED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: consultation.dietitianPhotoUrl != null ? NetworkImage(consultation.dietitianPhotoUrl!) : null,
                onBackgroundImageError: consultation.dietitianPhotoUrl != null ? (_, __) {} : null,
                child: consultation.dietitianPhotoUrl == null
                    ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${consultation.dietitianName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    Text(
                      consultation.dietitianQualification ?? 'Clinical Nutritionist (RD)',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EbicButton(
                  label: 'Chat with Doctor',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.dietitianChat,
                    arguments: {
                      'dietitianId': consultation.dietitianId,
                      'dietitianName': consultation.dietitianName,
                      'dietitianQualification': consultation.dietitianQualification,
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EbicButton(
                  label: 'Book Session',
                  isOutlined: true,
                  icon: Icons.video_call_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _loadHomeData()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextualReferralCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Refer friends & earn rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Invite your friends to EBIC.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF064E3B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.referrals),
            child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Some health cards could not be refreshed.', style: TextStyle(fontSize: 12, color: AppColors.slate700)),
          ),
          TextButton(
            onPressed: _loadHomeData,
            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connection Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 8),
            Text(
              _networkErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: EbicButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _loadHomeData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pending';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM • hh:mm a').format(dt);
  }
}

/// Lightweight data holder for quick-action tiles on the home screen.
class _QuickAction {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
}

