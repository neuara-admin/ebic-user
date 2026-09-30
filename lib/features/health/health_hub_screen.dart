import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_outlined_button.dart';
import '../../shared/widgets/member_switcher_widget.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/session_manager.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/token_storage.dart';
import '../../shared/models/health_pass_model.dart';
import '../dietitian/dietitian_profile_screen.dart';
import '../../shared/models/dietitian_model.dart';
import '../health_pass/data/health_pass_repository.dart';
import 'presentation/widgets/provenance_badge.dart';
import 'presentation/widgets/bmi_meter_widget.dart';

/// Section 31 & 35: Health Hub Screen
/// Designed as a cohesive health dashboard rather than a list of disconnected features.
class HealthHubScreen extends StatefulWidget {
  final bool isActive;
  const HealthHubScreen({super.key, this.isActive = true});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _healthSnapshot;
  List<dynamic> _connectedSources = [];
  DietitianModel? _assignedDietitian;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncMessage;
  String? _errorMessage;
  String _lastUpdatedText = 'Recently';

  static num? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val;
    if (val is String) return num.tryParse(val.trim());
    return null;
  }

  static double? _parseDouble(dynamic val) {
    final n = _parseNum(val);
    return n?.toDouble();
  }

  static int? _parseInt(dynamic val) {
    final n = _parseNum(val);
    return n?.toInt();
  }

  @override
  void initState() {
    super.initState();
    SessionManager().addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadHealthData();
        _fetchAssignedDietitian();
      }
    });
  }

  void _onSessionChanged() {
    if (mounted && (SessionManager().isAuthenticated || TokenStorage.hasCachedSession)) {
      _loadHealthData();
      _fetchAssignedDietitian();
    }
  }

  @override
  void didUpdateWidget(covariant HealthHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadHealthData();
      _fetchAssignedDietitian();
    }
  }

  @override
  void dispose() {
    SessionManager().removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _fetchAssignedDietitian() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final hasAuth = SessionManager().isAuthenticated || (token != null && token.isNotEmpty);
      if (hasAuth) {
        // 1. Direct query to dedicated customer assigned dietitian endpoint
        final assignedRes = await _api.get<dynamic>(
          ApiEndpoints.assignedDietitian,
          requiresAuth: true,
        );
        if (assignedRes.success && assignedRes.data != null && mounted) {
          final data = assignedRes.data is Map<String, dynamic>
              ? assignedRes.data as Map<String, dynamic>
              : (assignedRes.data is Map ? Map<String, dynamic>.from(assignedRes.data as Map) : null);
          if (data != null && data['id'] != null) {
            setState(() {
              _assignedDietitian = DietitianModel.fromJson(data);
            });
            return;
          }
        }

        // 2. Query from active Health Pass
        final currentPass = await HealthPassRepository().fetchCurrentPass();
        if (currentPass != null && mounted) {
          final assigned = currentPass.assignedDietitian;
          if (assigned != null && assigned.id.isNotEmpty) {
            // Fetch complete public profile from backend
            final profileRes = await _api.get<Map<String, dynamic>>(
              ApiEndpoints.dietitian(assigned.id),
            );
            if (profileRes.success && profileRes.data != null && mounted) {
              setState(() {
                _assignedDietitian = DietitianModel.fromJson(profileRes.data!);
              });
              return;
            } else if (mounted) {
              setState(() {
                _assignedDietitian = DietitianModel(
                  id: assigned.id,
                  name: assigned.name,
                  qualification: assigned.qualification ?? 'Clinical Nutritionist (RD)',
                  specialization: assigned.specializations.isNotEmpty
                      ? assigned.specializations.join(', ')
                      : null,
                  photoUrl: assigned.photoUrl,
                  experienceYears: assigned.experienceYears,
                  rating: assigned.rating,
                  languages: assigned.languages,
                  bio: assigned.bio,
                );
              });
              return;
            }
          }

          // Active consultation on pass
          if (currentPass.activeConsultation != null) {
            final c = currentPass.activeConsultation!;
            if (c.dietitianId.isNotEmpty) {
              final profileRes = await _api.get<Map<String, dynamic>>(
                ApiEndpoints.dietitian(c.dietitianId),
              );
              if (profileRes.success && profileRes.data != null && mounted) {
                setState(() {
                  _assignedDietitian = DietitianModel.fromJson(profileRes.data!);
                });
                return;
              } else if (mounted) {
                setState(() {
                  _assignedDietitian = DietitianModel(
                    id: c.dietitianId,
                    name: c.dietitianName,
                    qualification: c.dietitianQualification ?? 'Clinical Nutritionist (RD)',
                    specialization: 'Clinical Nutrition',
                    photoUrl: c.dietitianPhotoUrl,
                  );
                });
                return;
              }
            }
          }
        }

        // 3. Check customer consultations history for assigned specialist
        final consultRes = await _api.get<List<dynamic>>(
          ApiEndpoints.consultations,
          requiresAuth: true,
        );
        if (consultRes.success && consultRes.data != null && consultRes.data!.isNotEmpty && mounted) {
          final first = consultRes.data!.first as Map<String, dynamic>;
          final dietitianId = first['dietitianId']?.toString();
          if (dietitianId != null && dietitianId.isNotEmpty) {
            final profileRes = await _api.get<Map<String, dynamic>>(
              ApiEndpoints.dietitian(dietitianId),
            );
            if (profileRes.success && profileRes.data != null && mounted) {
              setState(() {
                _assignedDietitian = DietitianModel.fromJson(profileRes.data!);
              });
              return;
            } else if (mounted) {
              final name = first['dietitianName']?.toString() ?? 'Assigned Dietitian';
              setState(() {
                _assignedDietitian = DietitianModel(
                  id: dietitianId,
                  name: name,
                  qualification: first['dietitianQualification']?.toString() ?? 'Clinical Nutritionist (RD)',
                  specialization: 'Clinical Nutrition',
                  photoUrl: first['dietitianPhotoUrl']?.toString(),
                );
              });
              return;
            }
          }
        }
      }
    } catch (_) {}

    // When no dietitian is assigned in backend, keep null — no dummy data
    if (mounted) {
      setState(() {
        _assignedDietitian = null;
      });
    }
  }

  Future<void> _loadHealthData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenStorage.getAccessToken();
      final isAuth = SessionManager().isAuthenticated || (token != null && token.isNotEmpty);

      final now = DateTime.now();
      final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final minute = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final formattedTime = 'Today $hour:$minute $period';

      if (isAuth) {
        final res = await _api.get<Map<String, dynamic>>(
          ApiEndpoints.healthOverview,
          requiresAuth: true,
        );
        if (res.success && res.data != null) {
          if (mounted) {
            final today = res.data!['today'] as Map<String, dynamic>? ?? {};
            final sources = res.data!['connectedSources'] as List<dynamic>? ?? [];
            final metricSources = today['sources'] as Map<String, dynamic>? ?? {};

            dynamic weight = today['weightKg'];
            dynamic height = today['heightCm'];
            dynamic bmi = today['bmi'];

            // Resilient fallback: Query health profile if height or BMI is missing
            if (height == null || bmi == null || weight == null) {
              try {
                final profileRes = await _api.get<Map<String, dynamic>>(
                  ApiEndpoints.healthProfile,
                  requiresAuth: true,
                );
                if (profileRes.success && profileRes.data != null) {
                  final pData = profileRes.data!;
                  height ??= pData['heightCm'];
                  weight ??= pData['currentWeightKg'];
                  if (bmi == null && pData['latestMetrics'] is Map) {
                    final lm = pData['latestMetrics'] as Map<String, dynamic>;
                    bmi ??= lm['BMI']?['value'];
                  }
                }
              } catch (_) {}
            }

            final weightNum = _parseDouble(weight);
            final heightNum = _parseDouble(height);
            double? bmiNum = _parseDouble(bmi);

            // Derive BMI on client if both weight and height are present
            if (bmiNum == null && weightNum != null && heightNum != null && heightNum > 0) {
              final hM = heightNum / 100.0;
              bmiNum = double.parse((weightNum / (hM * hM)).toStringAsFixed(1));
            }

            final waterMlNum = _parseDouble(today['waterMl']);
            final sleepMinNum = _parseInt(today['sleepMinutes']);

            setState(() {
              _connectedSources = sources;
              _healthSnapshot = {
                'weight': weightNum,
                'height': heightNum,
                'bmi': bmiNum,
                'water': waterMlNum != null ? waterMlNum / 1000.0 : null,
                'steps': _parseInt(today['steps']),
                'sleep': sleepMinNum != null
                    ? '${sleepMinNum ~/ 60}h ${sleepMinNum % 60}m'
                    : null,
                'heartRate': _parseInt(today['restingHeartRate']),
                'calories': _parseInt(today['activeCalories']),
                'sources': metricSources,
              };
              _lastUpdatedText = formattedTime;
              _isLoading = false;
              _errorMessage = null;
            });
            return;
          }
        }
      }

      // Fallback
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.home,
        requiresAuth: false,
      );
      if (res.success && res.data != null) {
        if (mounted) {
          final snap = res.data!['health_snapshot'] as Map<String, dynamic>?;
          setState(() {
            _healthSnapshot = snap != null
                ? {
                    'weight': _parseDouble(snap['weight']),
                    'height': _parseDouble(snap['height']),
                    'bmi': _parseDouble(snap['bmi']),
                    'water': _parseDouble(snap['water']),
                    'steps': _parseInt(snap['steps']),
                    'sleep': snap['sleep']?.toString(),
                    'heartRate': _parseInt(snap['heartRate']),
                    'calories': _parseInt(snap['calories']),
                    'sources': snap['sources'] as Map<String, dynamic>? ?? {},
                  }
                : {};
            _lastUpdatedText = formattedTime;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _healthSnapshot = {};
            _isLoading = false;
            _errorMessage = isAuth
                ? (res.error?.message ?? 'Unable to fetch health snapshot')
                : null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _healthSnapshot = {};
          _isLoading = false;
          _errorMessage = SessionManager().isAuthenticated
              ? 'Network connection interrupted. Please try again.'
              : null;
        });
      }
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncMessage = 'Syncing health data...';
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.healthSync,
        body: {
          'provider': _connectedSources.isNotEmpty
              ? _connectedSources.first['provider']
              : 'HEALTH_CONNECT',
          'syncType': 'INCREMENTAL',
        },
        requiresAuth: true,
      );

      if (mounted) {
        if (res.success) {
          setState(() {
            _syncMessage = 'Health data updated';
            _lastUpdatedText = 'Just now';
          });
          await _loadHealthData();
        } else {
          setState(() {
            _syncMessage = 'Sync failed. Will retry automatically.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _syncMessage = 'Offline sync queued';
        });
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isSyncing = false);
        });
      }
    }
  }

  Future<void> _quickLogWater() async {
    HapticFeedback.lightImpact();
    if (!SessionManager().isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    final currentWater = _parseDouble(_healthSnapshot?['water']) ?? 0.0;
    final newWater = (currentWater + 0.25).clamp(0.0, 6.0);
    setState(() {
      if (_healthSnapshot != null) {
        _healthSnapshot!['water'] = newWater;
        final sources = _healthSnapshot!['sources'] as Map<String, dynamic>? ?? {};
        sources['water'] = 'MANUAL';
        _healthSnapshot!['sources'] = sources;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+250ml logged! Daily total: ${newWater.toStringAsFixed(2)}L 💧'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      await _api.post<dynamic>(
        ApiEndpoints.healthMetrics,
        body: {
          'metricType': 'WATER',
          'value': newWater,
          'unit': 'L',
          'recordedAt': DateTime.now().toUtc().toIso8601String(),
          'source': 'MANUAL',
        },
        requiresAuth: true,
      );
    } catch (_) {}
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF2563EB);
    if (bmi < 25.0) return const Color(0xFF059669);
    if (bmi < 30.0) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Future<void> _showLogVitalsBottomSheet() async {
    HapticFeedback.mediumImpact();
    if (!SessionManager().isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    final curWeight = _parseDouble(_healthSnapshot?['weight']) ?? 68.0;
    final curHeight = _parseDouble(_healthSnapshot?['height']) ?? 172.0;
    final curWater = _parseDouble(_healthSnapshot?['water']) ?? 1.5;
    final curSteps = _parseInt(_healthSnapshot?['steps']);
    final curHeart = _parseInt(_healthSnapshot?['heartRate']);
    final curCal = _parseInt(_healthSnapshot?['calories']);

    final weightController = TextEditingController(
      text: curWeight > 0 ? curWeight.toStringAsFixed(1) : '',
    );
    final heightController = TextEditingController(
      text: curHeight > 0 ? curHeight.toStringAsFixed(0) : '',
    );
    final waterController = TextEditingController(
      text: curWater > 0 ? curWater.toStringAsFixed(1) : '',
    );
    final stepsController = TextEditingController(
      text: curSteps != null && curSteps > 0 ? curSteps.toString() : '',
    );
    final heartController = TextEditingController(
      text: curHeart != null && curHeart > 0 ? curHeart.toString() : '',
    );
    final calController = TextEditingController(
      text: curCal != null && curCal > 0 ? curCal.toString() : '',
    );

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final double? enteredWeight =
                double.tryParse(weightController.text.trim());
            final double? enteredHeight =
                double.tryParse(heightController.text.trim());

            double? liveBmi;
            if (enteredWeight != null &&
                enteredWeight > 0 &&
                enteredHeight != null &&
                enteredHeight > 0) {
              final hM = enteredHeight / 100.0;
              liveBmi = enteredWeight / (hM * hM);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate900 : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color:
                                isDark ? AppColors.slate700 : AppColors.slate300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update Health Vitals',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.slate900,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const ProvenanceBadge(
                                      source: 'MANUAL',
                                      isCompact: true,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Recorded as manual entries',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.slate400
                                            : AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Weight & Height
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weight (kg)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: weightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 68.5',
                                    suffixText: 'kg',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Height (cm)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: heightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 172',
                                    suffixText: 'cm',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Live Dynamic BMI Display Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: liveBmi != null
                              ? _getBmiColor(liveBmi).withOpacity(0.08)
                              : (isDark
                                  ? AppColors.slate800
                                  : AppColors.slate100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: liveBmi != null
                                ? _getBmiColor(liveBmi).withOpacity(0.3)
                                : (isDark
                                    ? AppColors.slate700
                                    : AppColors.slate200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.health_and_safety_rounded,
                              color: liveBmi != null
                                  ? _getBmiColor(liveBmi)
                                  : AppColors.slate400,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    'Calculated BMI: ',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.slate300
                                          : AppColors.slate700,
                                    ),
                                  ),
                                  Text(
                                    liveBmi != null
                                        ? liveBmi.toStringAsFixed(1)
                                        : '—',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: liveBmi != null
                                          ? _getBmiColor(liveBmi)
                                          : AppColors.slate500,
                                    ),
                                  ),
                                  if (liveBmi != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getBmiColor(liveBmi),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        _getBmiCategory(liveBmi),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const ProvenanceBadge(
                              source: 'DERIVED',
                              isCompact: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hydration & Steps
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hydration (L)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: waterController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 2.5',
                                    suffixText: 'L',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Steps Today',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: stepsController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 8500',
                                    suffixText: 'steps',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Heart Rate & Calories
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Heart Rate (bpm)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: heartController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 72',
                                    suffixText: 'bpm',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Calories',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.slate300
                                        : AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: calController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 450',
                                    suffixText: 'kcal',
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.slate800
                                        : AppColors.slate50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                            : AppColors.slate200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: EbicButton(
                          label: isSaving
                              ? 'Saving Vitals...'
                              : 'Save as Manual Entry',
                          icon: Icons.check_circle_rounded,
                          isLoading: isSaving,
                          onPressed: () async {
                            final w =
                                double.tryParse(weightController.text.trim());
                            final h =
                                double.tryParse(heightController.text.trim());
                            final water =
                                double.tryParse(waterController.text.trim());
                            final steps =
                                int.tryParse(stepsController.text.trim());
                            final heart =
                                int.tryParse(heartController.text.trim());
                            final cal =
                                int.tryParse(calController.text.trim());

                            if (w == null &&
                                water == null &&
                                steps == null &&
                                heart == null &&
                                cal == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter at least one vital to save',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);
                            final nowUtc =
                                DateTime.now().toUtc().toIso8601String();

                            try {
                              if (w != null && w > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'WEIGHT',
                                    'value': w,
                                    'unit': 'kg',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              if (h != null && h > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'HEIGHT',
                                    'value': h,
                                    'unit': 'cm',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              // Auto-save calculated BMI entry
                              if (w != null && w > 0 && h != null && h > 0) {
                                final hM = h / 100.0;
                                final derivedBmi = double.parse((w / (hM * hM)).toStringAsFixed(1));
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'BMI',
                                    'value': derivedBmi,
                                    'unit': 'BMI',
                                    'source': 'DERIVED',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              if (water != null && water > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'WATER',
                                    'value': water,
                                    'unit': 'L',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              if (steps != null && steps > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'STEPS',
                                    'value': steps,
                                    'unit': 'steps',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              if (heart != null && heart > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'HEART_RATE',
                                    'value': heart,
                                    'unit': 'bpm',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }
                              if (cal != null && cal > 0) {
                                await _api.post<dynamic>(
                                  ApiEndpoints.healthMetrics,
                                  body: {
                                    'metricType': 'CALORIES',
                                    'value': cal,
                                    'unit': 'kcal',
                                    'source': 'MANUAL',
                                    'recordedAt': nowUtc,
                                  },
                                  requiresAuth: true,
                                );
                              }

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              if (mounted) {
                                setState(() {
                                  _healthSnapshot = {
                                    ...?_healthSnapshot,
                                    if (w != null && w > 0) 'weight': w,
                                    if (h != null && h > 0) 'height': h,
                                    if (w != null && w > 0 && h != null && h > 0)
                                      'bmi': double.parse((w / ((h / 100.0) * (h / 100.0))).toStringAsFixed(1)),
                                    if (water != null && water > 0) 'water': water,
                                    if (steps != null && steps > 0) 'steps': steps,
                                    if (heart != null && heart > 0) 'heartRate': heart,
                                    if (cal != null && cal > 0) 'calories': cal,
                                  };
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vitals updated successfully (Manually Added) ✨',
                                    ),
                                    backgroundColor: Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadHealthData();
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save vitals: $e'),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadHealthData(),
      _fetchAssignedDietitian(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final weightVal = _parseDouble(_healthSnapshot?['weight']);
    final heightVal = _parseDouble(_healthSnapshot?['height']);
    final rawBmi = _parseDouble(_healthSnapshot?['bmi']);
    final waterVal = _parseDouble(_healthSnapshot?['water']);
    final stepsVal = _parseInt(_healthSnapshot?['steps']);
    final sleepVal = _healthSnapshot?['sleep'];
    final heartVal = _parseInt(_healthSnapshot?['heartRate']);
    final calVal = _parseInt(_healthSnapshot?['calories']);

    double? bmiVal = rawBmi;
    if (bmiVal == null || bmiVal <= 0) {
      if (weightVal != null && heightVal != null && heightVal > 0) {
        final hM = heightVal / 100.0;
        bmiVal = weightVal / (hM * hM);
      }
    }

    final sources = _healthSnapshot?['sources'] as Map<String, dynamic>? ?? {};
    final weightSource = sources['weight']?.toString();
    final waterSource = sources['water']?.toString();
    final stepsSource = sources['steps']?.toString();
    final sleepSource = sources['sleep']?.toString();
    final heartSource = sources['heartRate']?.toString();
    final calSource = sources['calories']?.toString();

    final weightDisplay = weightVal != null
        ? '${weightVal.toStringAsFixed(1)} kg'
        : '—';
    final weightSub = bmiVal != null
        ? 'BMI ${bmiVal.toStringAsFixed(1)} • ${_getBmiCategory(bmiVal)}'
        : (weightVal != null ? 'Synced vital' : 'Tap to log');

    final waterDisplay = waterVal != null
        ? '${waterVal.toStringAsFixed(1)} L'
        : '—';
    final waterSub = waterVal != null ? 'Daily intake' : 'Tap to log';

    final stepsDisplay =
        stepsVal != null && stepsVal > 0 ? '$stepsVal' : '—';
    final stepsSub =
        stepsVal != null && stepsVal > 0 ? 'Steps today' : 'Tap to track';

    final sleepDisplay = sleepVal != null ? '$sleepVal' : '—';
    final sleepSub = sleepVal != null ? 'Rest duration' : 'Tap to log';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : AppColors.slate200;
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate700;
    final textMuted = isDark ? AppColors.slate400 : AppColors.slate500;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Dashboard',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Metabolic & Lifestyle Hub',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.devices_other_rounded,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            tooltip: 'Connected Sources',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.connectedSources,
            ).then((_) => _loadHealthData()),
          ),
          IconButton(
            icon: Icon(
              Icons.shield_outlined,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            tooltip: 'Privacy & Consent',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.privacy),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading && _healthSnapshot == null)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 2.5,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Member Selector Bar (Section 18 & 35)
                      MemberSwitcherBar(
                        onMemberChanged: () {
                          _loadHealthData();
                          _fetchAssignedDietitian();
                        },
                      ),
                const SizedBox(height: 12),

                // 2. Bento Sync & Connected Source Pulse Bar
                _buildSyncPulseBento(
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 14),

                // Offline / Server Unreachable Banner if applicable
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadHealthData,
                          child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Hero Bento: Metabolic & Body Composition (Large 2x1 Hero Card)
                _buildMetabolicHeroBento(
                  weightVal: weightVal,
                  heightVal: heightVal,
                  bmiVal: bmiVal,
                  weightSource: weightSource,
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 20),

                // 4. Bento Section: Daily Vitals & Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Vitals & Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showLogVitalsBottomSheet,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      label: Text(
                        'Log Vitals',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        backgroundColor: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bento Grid Row 1: Hydration & Steps
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHydrationBentoTile(
                        waterVal: waterVal,
                        source: waterSource,
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStepsBentoTile(
                        stepsVal: stepsVal,
                        source: stepsSource,
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bento Grid Row 2: Heart Rate & Sleep
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHeartBentoTile(
                        heartVal: heartVal,
                        source: heartSource,
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSleepBentoTile(
                        sleepVal: sleepVal,
                        source: sleepSource,
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bento Grid Row 3: Active Calories (Full Width Card)
                _buildCaloriesBentoTile(
                  calVal: calVal,
                  source: calSource,
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 24),

                // 5. Bento Section: Clinical Care & Nutrition Hub
                Text(
                  'Clinical Care & Nutrition Hub',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // 2x2 Clinical Bento Box
                _buildClinicalBentoHub(
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 16),

                // 6. Hero Dietitian Spotlight Bento
                _buildDietitianSpotlightBento(
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
);
}

  String _formatProviderDisplayName(String? provider) {
    if (provider == null || provider.isEmpty) return 'Health Connect';
    final upper = provider.toUpperCase();
    if (upper.contains('HEALTH_CONNECT') || upper.contains('GOOGLE_HEALTH')) {
      return 'Health Connect';
    }
    if (upper.contains('APPLE_HEALTH') || upper.contains('HEALTHKIT')) {
      return 'Apple Health';
    }
    if (upper.contains('SAMSUNG')) return 'Samsung Health';
    if (upper.contains('FITBIT')) return 'Fitbit';
    if (upper.contains('GARMIN')) return 'Garmin';
    return provider
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  // ───────────────────────── 1. Bento Sync & Connected Pulse Bar ─────────────────────────
  Widget _buildSyncPulseBento({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final bool hasSources = _connectedSources.isNotEmpty;
    final primaryProvider = hasSources
        ? _connectedSources.first['provider']?.toString()
        : null;

    final String providerTitle = primaryProvider != null
        ? '${_formatProviderDisplayName(primaryProvider)} Synced'
        : 'Health Connect Synced';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.connectedSources)
            .then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withOpacity(0.5)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            providerTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              height: 1.2,
                            ),
                            softWrap: true,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSyncing
                          ? (_syncMessage ?? 'Syncing health vitals...')
                          : 'Updated $_lastUpdatedText • Tap for details',
                      style: TextStyle(
                        fontSize: 11,
                        color: textMuted,
                        height: 1.2,
                      ),
                      softWrap: true,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isSyncing ? null : _triggerSync,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSyncing)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        _isSyncing ? 'Syncing' : 'Sync Now',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 2. Hero Bento: Metabolic & Body Composition ─────────────────────────
  Widget _buildMetabolicHeroBento({
    required dynamic weightVal,
    required dynamic heightVal,
    required double? bmiVal,
    required String? weightSource,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final hasWeight = weightVal != null;
    final double weightKg = _parseDouble(weightVal) ?? 0.0;
    final double heightCm = _parseDouble(heightVal) ?? 0.0;
    double? effectiveBmi = bmiVal;
    if ((effectiveBmi == null || effectiveBmi <= 0) && weightKg > 0 && heightCm > 0) {
      final hM = heightCm / 100.0;
      effectiveBmi = double.parse((weightKg / (hM * hM)).toStringAsFixed(1));
    }
    final bmiColor = effectiveBmi != null ? _getBmiColor(effectiveBmi) : AppColors.primary;
    final bmiCategory = effectiveBmi != null ? _getBmiCategory(effectiveBmi) : 'Pending';

    // Spectrum Progress: 4 distinct clinical zones (Underweight < 18.5, Normal 18.5-24.9, Overweight 25-29.9, Obese >= 30)
    double? meterProgress;
    if (effectiveBmi != null && effectiveBmi > 0) {
      if (effectiveBmi < 18.5) {
        meterProgress = ((effectiveBmi - 12.0) / (18.5 - 12.0) * 0.25).clamp(0.04, 0.23);
      } else if (effectiveBmi < 25.0) {
        meterProgress = 0.25 + ((effectiveBmi - 18.5) / (25.0 - 18.5) * 0.25).clamp(0.01, 0.23);
      } else if (effectiveBmi < 30.0) {
        meterProgress = 0.50 + ((effectiveBmi - 25.0) / (30.0 - 25.0) * 0.25).clamp(0.01, 0.23);
      } else {
        meterProgress = (0.75 + ((effectiveBmi - 30.0) / 10.0) * 0.25).clamp(0.77, 0.96);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryDark.withOpacity(0.3)
                            : AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.monitor_weight_outlined,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Body Composition',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProvenanceBadge(
                source: weightSource ?? 'MANUAL',
                isCompact: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2-Column Split: Weight on Left, BMI on Right
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Weight & Height
                Expanded(
                  child: InkWell(
                    onTap: _showLogVitalsBottomSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.slate800.withOpacity(0.5)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder.withOpacity(0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'WEIGHT',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: textMuted,
                                ),
                              ),
                              Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: textMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    hasWeight ? weightKg.toStringAsFixed(1) : '—',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.height_rounded, size: 14, color: textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  heightCm > 0 ? '${heightCm.toInt()} cm' : 'Tap to add',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Right Column: BMI with Category Pill
                Expanded(
                  child: InkWell(
                    onTap: _showLogVitalsBottomSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.slate800.withOpacity(0.5)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder.withOpacity(0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'BMI SCORE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: textMuted,
                                ),
                              ),
                              Icon(
                                Icons.info_outline_rounded,
                                size: 13,
                                color: textMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    effectiveBmi != null ? effectiveBmi.toStringAsFixed(1) : '—',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: bmiColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'kg/m²',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: bmiColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bmiCategory,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: bmiColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 16),

          // 4-Zone Spectrum Progress Meter (Underweight | Normal | Overweight | Obese)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BMI CLINICAL SPECTRUM',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                  if (effectiveBmi != null && effectiveBmi > 0)
                    Text(
                      '${effectiveBmi.toStringAsFixed(1)} • $bmiCategory',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: bmiColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Bar + Pointer Stack (Solid 8px visible bar)
              SizedBox(
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Segmented color bar (solid height: 8px)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 25,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF38BDF8), // Sky Blue (Underweight)
                                    borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  color: const Color(0xFF10B981), // Emerald (Normal)
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  color: const Color(0xFFF59E0B), // Amber (Overweight)
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444), // Rose Red (Obese)
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Active Pointer Indicator
                    if (meterProgress != null)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: meterProgress,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 6,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : AppColors.slate900,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: isDark ? AppColors.slate800 : Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),

              // Zone Labels & Thresholds
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Under (<18.5)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Normal (18.5-24.9)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Over (25-29.9)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Obese (≥30)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 3. Bento Grid: Daily Vitals ─────────────────────────

  // Tile A: Hydration Bento
  Widget _buildHydrationBentoTile({
    required dynamic waterVal,
    required String? source,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final double currentLiters = _parseDouble(waterVal) ?? 0.0;
    const double targetLiters = 3.0;
    final double ratio = (currentLiters / targetLiters).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.healthMetricDetail,
          arguments: {'type': 'hydration'},
        ).then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Color(0xFF2563EB),
                      size: 17,
                    ),
                  ),
                  ProvenanceBadge(source: source ?? 'MANUAL', isCompact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentLiters.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ ${targetLiters.toStringAsFixed(0)}L',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hydration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(height: 10),
              // Direct Quick-Add Button
              InkWell(
                onTap: _quickLogWater,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withOpacity(0.25),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '+ 250 ml',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tile B: Steps Bento
  Widget _buildStepsBentoTile({
    required dynamic stepsVal,
    required String? source,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final int steps = _parseInt(stepsVal) ?? 0;
    const int targetSteps = 10000;
    final double ratio = (steps / targetSteps).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.healthMetricDetail,
          arguments: {'type': 'activity'},
        ).then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: Color(0xFF059669),
                      size: 18,
                    ),
                  ),
                  ProvenanceBadge(source: source ?? 'MANUAL', isCompact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    steps > 0 ? '$steps' : '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'steps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Active Steps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(isDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    steps > 0 ? '${(ratio * 100).toInt()}% of daily goal' : 'Tap to sync steps',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tile C: Heart Rate Bento
  Widget _buildHeartBentoTile({
    required dynamic heartVal,
    required String? source,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final int? bpm = _parseInt(heartVal);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.healthMetricDetail,
          arguments: {'type': 'heart'},
        ).then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE11D48),
                      size: 17,
                    ),
                  ),
                  ProvenanceBadge(source: source ?? 'MANUAL', isCompact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    bpm != null ? '$bpm' : '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'bpm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Resting Pulse',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      bpm != null ? 'Normal resting range' : 'Tap to log vital',
                      style: TextStyle(fontSize: 10.5, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tile D: Sleep Bento
  Widget _buildSleepBentoTile({
    required dynamic sleepVal,
    required String? source,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final String? sleepStr = sleepVal?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.healthMetricDetail,
          arguments: {'type': 'sleep'},
        ).then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      color: Color(0xFF7C3AED),
                      size: 17,
                    ),
                  ),
                  ProvenanceBadge(source: source ?? 'MANUAL', isCompact: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                sleepStr ?? '—',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Sleep & Rest',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.nightlight_round, size: 11, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      sleepStr != null ? 'Restorative rest' : 'Tap to log hours',
                      style: TextStyle(fontSize: 10.5, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tile E: Active Calories Bento (Full Width Highlight)
  Widget _buildCaloriesBentoTile({
    required dynamic calVal,
    required String? source,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final int? cal = _parseInt(calVal);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.healthMetricDetail,
          arguments: {'type': 'activity'},
        ).then((_) => _loadHealthData()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFEA580C),
                  size: 22,
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
                            'Active Energy Burn',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ProvenanceBadge(source: source ?? 'MANUAL', isCompact: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cal != null ? '$cal kcal burned today' : 'Estimated daily energy expenditure',
                      style: TextStyle(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: textMuted.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 4. Clinical Care & Nutrition Bento Box (2x2) ─────────────────────────
  Widget _buildClinicalBentoHub({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return Column(
      children: [
        Row(
          children: [
            // Tile 1: Diet Plan
            Expanded(
              child: _buildBentoActionTile(
                title: 'Diet Plan',
                subtitle: "Today's clinical meals",
                icon: Icons.restaurant_menu_rounded,
                iconColor: const Color(0xFF0D9488),
                badgeBg: const Color(0xFF0D9488).withOpacity(0.12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 12),
            // Tile 2: Health Documents
            Expanded(
              child: _buildBentoActionTile(
                title: 'Health Vault',
                subtitle: 'Lab reports & tests',
                icon: Icons.folder_shared_outlined,
                iconColor: const Color(0xFFD97706),
                badgeBg: const Color(0xFFD97706).withOpacity(0.12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Tile 3: Consultations
            Expanded(
              child: _buildBentoActionTile(
                title: 'Consultations',
                subtitle: 'Dietitian video sessions',
                icon: Icons.video_call_outlined,
                iconColor: const Color(0xFF7C3AED),
                badgeBg: const Color(0xFF7C3AED).withOpacity(0.12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 12),
            // Tile 4: Health Profile
            Expanded(
              child: _buildBentoActionTile(
                title: 'Health Bio',
                subtitle: 'Allergies & biomarkers',
                icon: Icons.assignment_ind_outlined,
                iconColor: const Color(0xFF0284C7),
                badgeBg: const Color(0xFF0284C7).withOpacity(0.12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthProfile),
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: textMuted.withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 5. Dietitian Spotlight Hero Bento ─────────────────────────
  Widget _buildDietitianSpotlightBento({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    // If no dietitian is assigned in the backend, render clean unassigned card (no dummy data)
    if (_assignedDietitian == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryDark.withOpacity(0.3)
                        : AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                    size: 22,
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
                              'Clinical Nutrition Care',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.slate800
                                  : AppColors.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Unassigned',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dedicated Clinical Dietitian',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Book an initial consultation to be paired with an EBIC Clinical Dietitian for your personalized diet roadmap and medical nutrition therapy.',
              style: TextStyle(
                fontSize: 11.5,
                color: textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: EbicButton(
                    label: 'Book Consultation',
                    icon: Icons.calendar_month_rounded,
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.consultationBook)
                          .then((_) => _fetchAssignedDietitian());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.consultationsList)
                          .then((_) => _fetchAssignedDietitian());
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: (isDark ? AppColors.slate700 : AppColors.slate300)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
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

    final dietitian = _assignedDietitian!;
    final avatarUrl = dietitian.photoUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryDark.withOpacity(0.4)
                      : AppColors.primarySubtle,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? Image.network(
                        AppConfig.resolveMediaUrl(avatarUrl) ?? avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dietitian.name.startsWith('Dr')
                          ? dietitian.name
                          : 'Dr. ${dietitian.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Assigned RD',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dietitian.qualification ?? 'Registered Dietitian (RD)',
                            style: TextStyle(fontSize: 11, color: textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      (dietitian.rating != null && dietitian.rating! > 0)
                          ? dietitian.rating!.toStringAsFixed(1)
                          : '4.9',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dietitian.specialization != null &&
              dietitian.specialization!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              dietitian.specialization!,
              style: TextStyle(
                fontSize: 11.5,
                color: textSecondary,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: EbicButton(
                  label: 'Book Session',
                  icon: Icons.video_call_rounded,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.consultationBook)
                        .then((_) => _onRefresh());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DietitianProfileScreen(dietitian: dietitian),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: AppColors.primary),
                  label: const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

