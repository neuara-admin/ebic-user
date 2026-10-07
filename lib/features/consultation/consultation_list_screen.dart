import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../dietitian/dietitian_profile_screen.dart';
import '../health_pass/data/health_pass_repository.dart';

class ConsultationListScreen extends StatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  State<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends State<ConsultationListScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<ConsultationModel> _consultations = [];
  ActiveHealthPassModel? _activePass;
  DietitianModel? _assignedDietitian;
  bool _isLoading = true;
  StreamSubscription<StandardSocketEnvelope>? _realtimeSub;
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        final isUpcoming = _tabController.index == 0;
        if (isUpcoming && (_selectedStatusFilter == 'COMPLETED' || _selectedStatusFilter == 'CANCELLED')) {
          _selectedStatusFilter = 'ALL';
        } else if (!isUpcoming && _selectedStatusFilter == 'SCHEDULED') {
          _selectedStatusFilter = 'ALL';
        }
        setState(() {});
      }
    });
    _fetchConsultations();
    _realtimeSub = RealtimeService().consultationUpdates.listen((_) => _fetchConsultations(silent: true));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchConsultations({bool silent = false}) async {
    if (!mounted) return;
    if (!silent && _consultations.isEmpty) setState(() => _isLoading = true);

    try {
      final consultRes = await _api.get<List<dynamic>>(ApiEndpoints.consultations);
      ActiveHealthPassModel? pass;
      try {
        pass = await HealthPassRepository().fetchCurrentPass();
      } catch (_) {}

      if (mounted) {
        List<ConsultationModel> parsedConsultations = [];
        if (consultRes.success && consultRes.data != null) {
          parsedConsultations = consultRes.data!
              .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
              .toList();
          // Sort newest first
          parsedConsultations.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
        }

        // Synchronously pre-resolve assigned dietitian to avoid UI layout shift / flicker
        DietitianModel? preResolvedDietitian = _assignedDietitian;
        if (pass?.assignedDietitian != null) {
          final d = pass!.assignedDietitian!;
          preResolvedDietitian = DietitianModel(
            id: d.id,
            name: d.name.startsWith('Dr') ? d.name : 'Dr. ${d.name}',
            qualification: d.qualification ?? 'Clinical Nutritionist (RD)',
            specialization: d.specializations.isNotEmpty ? d.specializations.join(', ') : null,
            photoUrl: d.photoUrl,
            experienceYears: (d.experienceYears != null && d.experienceYears! > 0) ? d.experienceYears : 5,
            rating: (d.rating != null && d.rating! > 0) ? d.rating : 4.9,
            bio: d.bio,
            languages: d.languages,
          );
        } else if (parsedConsultations.isNotEmpty) {
          final firstWithDietitian = parsedConsultations.firstWhere(
            (c) => c.dietitianName.isNotEmpty,
            orElse: () => parsedConsultations.first,
          );
          if (firstWithDietitian.dietitianId.isNotEmpty) {
            final dName = firstWithDietitian.dietitianName;
            preResolvedDietitian = DietitianModel(
              id: firstWithDietitian.dietitianId,
              name: dName.startsWith('Dr') ? dName : 'Dr. $dName',
              qualification: firstWithDietitian.dietitianQualification ?? 'Clinical Nutritionist (RD)',
              specialization: firstWithDietitian.dietitianSpecialization,
              photoUrl: firstWithDietitian.dietitianPhotoUrl,
              experienceYears: 5,
              rating: 4.9,
            );
          }
        }

        setState(() {
          _activePass = pass;
          _consultations = parsedConsultations;
          if (preResolvedDietitian != null) {
            _assignedDietitian = preResolvedDietitian;
          }
          _isLoading = false;
        });

        _resolveAssignedDietitian(pass, parsedConsultations);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveAssignedDietitian(ActiveHealthPassModel? pass, List<ConsultationModel> consultations) async {
    try {
      final assignedRes = await _api.get<dynamic>(
        ApiEndpoints.assignedDietitian,
        requiresAuth: true,
      );
      if (assignedRes.success && assignedRes.data != null && mounted) {
        final data = assignedRes.data is Map<String, dynamic>
            ? assignedRes.data as Map<String, dynamic>
            : (assignedRes.data is Map ? Map<String, dynamic>.from(assignedRes.data as Map) : null);
        if (data != null && data['id'] != null) {
          final d = DietitianModel.fromJson(data);
          setState(() {
            _assignedDietitian = DietitianModel(
              id: d.id,
              name: d.name.startsWith('Dr') ? d.name : 'Dr. ${d.name}',
              qualification: d.qualification,
              specialization: d.specialization,
              photoUrl: d.photoUrl,
              experienceYears: (d.experienceYears != null && d.experienceYears! > 0) ? d.experienceYears : 5,
              rating: (d.rating != null && d.rating! > 0) ? d.rating : 4.9,
              bio: d.bio,
              languages: d.languages,
            );
          });
          return;
        }
      }
    } catch (_) {}

    if (pass?.assignedDietitian != null) {
      final d = pass!.assignedDietitian!;
      try {
        final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.dietitian(d.id));
        if (res.success && res.data != null && mounted) {
          final serverD = DietitianModel.fromJson(res.data!);
          setState(() {
            _assignedDietitian = DietitianModel(
              id: serverD.id,
              name: serverD.name.startsWith('Dr') ? serverD.name : 'Dr. ${serverD.name}',
              qualification: serverD.qualification ?? d.qualification ?? 'Clinical Nutritionist (RD)',
              specialization: serverD.specialization ?? (d.specializations.isNotEmpty ? d.specializations.join(', ') : null),
              photoUrl: serverD.photoUrl ?? d.photoUrl,
              experienceYears: (serverD.experienceYears != null && serverD.experienceYears! > 0)
                  ? serverD.experienceYears
                  : (d.experienceYears ?? 5),
              rating: (serverD.rating != null && serverD.rating! > 0) ? serverD.rating : 4.9,
              bio: serverD.bio ?? d.bio,
              languages: (serverD.languages != null && serverD.languages!.isNotEmpty) ? serverD.languages : d.languages,
            );
          });
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _assignedDietitian = DietitianModel(
            id: d.id,
            name: d.name.startsWith('Dr') ? d.name : 'Dr. ${d.name}',
            qualification: d.qualification ?? 'Clinical Nutritionist (RD)',
            specialization: d.specializations.isNotEmpty ? d.specializations.join(', ') : null,
            photoUrl: d.photoUrl,
            experienceYears: (d.experienceYears != null && d.experienceYears! > 0) ? d.experienceYears : 5,
            rating: (d.rating != null && d.rating! > 0) ? d.rating : 4.9,
            bio: d.bio,
            languages: d.languages,
          );
        });
        return;
      }
    }

    if (consultations.isNotEmpty) {
      final firstWithDietitian = consultations.firstWhere(
        (c) => c.dietitianName.isNotEmpty,
        orElse: () => consultations.first,
      );
      if (firstWithDietitian.dietitianId.isNotEmpty) {
        try {
          final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.dietitian(firstWithDietitian.dietitianId));
          if (res.success && res.data != null && mounted) {
            final serverD = DietitianModel.fromJson(res.data!);
            setState(() {
              _assignedDietitian = DietitianModel(
                id: serverD.id,
                name: serverD.name.startsWith('Dr') ? serverD.name : 'Dr. ${serverD.name}',
                qualification: serverD.qualification ?? firstWithDietitian.dietitianQualification ?? 'Clinical Nutritionist (RD)',
                specialization: serverD.specialization ?? firstWithDietitian.dietitianSpecialization,
                photoUrl: serverD.photoUrl ?? firstWithDietitian.dietitianPhotoUrl,
                experienceYears: (serverD.experienceYears != null && serverD.experienceYears! > 0) ? serverD.experienceYears : 5,
                rating: (serverD.rating != null && serverD.rating! > 0) ? serverD.rating : 4.9,
                bio: serverD.bio,
                languages: serverD.languages,
              );
            });
            return;
          }
        } catch (_) {}
        if (mounted) {
          final dName = firstWithDietitian.dietitianName;
          setState(() {
            _assignedDietitian = DietitianModel(
              id: firstWithDietitian.dietitianId,
              name: dName.startsWith('Dr') ? dName : 'Dr. $dName',
              qualification: firstWithDietitian.dietitianQualification ?? 'Clinical Nutritionist (RD)',
              specialization: firstWithDietitian.dietitianSpecialization,
              photoUrl: firstWithDietitian.dietitianPhotoUrl,
              experienceYears: 5,
              rating: 4.9,
            );
          });
          return;
        }
      }
    }

    if (mounted && _assignedDietitian == null) {
      setState(() {
        _assignedDietitian = null;
      });
    }
  }

  bool _canModify(ConsultationModel c) {
    return (c.status == 'SCHEDULED' || c.status == 'PENDING') &&
        c.scheduledAt.isAfter(DateTime.now());
  }

  Future<void> _cancelConsultation(ConsultationModel c) async {
    if (!_canModify(c)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only upcoming scheduled consultations can be cancelled.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text('Cancel Consultation?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel your appointment with Dr. ${c.dietitianName}?',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Text(
                'Note: If this is your subscription kickoff consultation, cancelling will pause your Health Pass activation until rescheduled.',
                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Appointment', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Consultation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultationCancel(c.id),
        body: {'reason': 'Customer requested cancellation via mobile app'},
      );
      if (res.success) {
        _fetchConsultations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consultation cancelled successfully.'),
              backgroundColor: AppColors.slate800,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'Failed to cancel consultation.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showRescheduleSheet(ConsultationModel c) async {
    if (!_canModify(c)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only upcoming scheduled consultations can be rescheduled.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RescheduleBottomSheet(consultation: c),
    );

    if (result == true) {
      _fetchConsultations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation rescheduled successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _showConsultationDetailsModal(ConsultationModel c) {
    Navigator.pushNamed(
      context,
      AppRoutes.consultationDetail,
      arguments: {'consultation': c},
    ).then((_) {
      if (mounted) _fetchConsultations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Upcoming contains SCHEDULED and IN_PROGRESS
    final upcoming = _consultations.where((c) {
      return c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING';
    }).toList();

    // Past contains VIDEO_COMPLETED (call done, notes pending), COMPLETED, CANCELLED, NO_SHOW
    final past = _consultations.where((c) {
      return c.status == 'VIDEO_COMPLETED' ||
          c.status == 'COMPLETED' ||
          c.status == 'CANCELLED' ||
          c.status == 'NO_SHOW';
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Consultations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Clinical Nutrition & Care',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.normal,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _fetchConsultations()),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
              label: const Text(
                'Book New',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConsultations,
              child: Column(
                children: [
                  _buildCareSpecialistCard(isDark, upcoming.length, past.length),
                  _buildSegmentedTabSelector(isDark, upcoming.length, past.length),
                  _buildFilterChipsRow(isDark, upcoming: upcoming, past: past),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(upcoming, isUpcoming: true, isDark: isDark),
                        _buildList(past, isUpcoming: false, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCareSpecialistCard(bool isDark, int upcomingCount, int pastCount) {
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBorder = isDark ? AppColors.slate800 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate400 : AppColors.slate600;
    final hasPass = _activePass != null && _activePass!.isActive;
    final remainingSessions = _activePass?.consultationsRemaining ?? 0;

    if (_assignedDietitian == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 22),
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
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : AppColors.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Unassigned',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dedicated Clinical Dietitian',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _fetchConsultations()),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        SizedBox(width: 2),
                        Icon(Icons.add_rounded, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: cardBorder),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: hasPass ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    hasPass ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: hasPass ? const Color(0xFF059669) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPass
                        ? '${_activePass!.planName} • $remainingSessions Session${remainingSessions == 1 ? '' : 's'} Remaining'
                        : 'Book your first session to be paired with a clinical specialist',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasPass ? const Color(0xFF059669) : textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
          // Row 1: Doctor info + Avatar + View Profile Button
          Row(
            children: [
              // Avatar with verified badge ring
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primaryDark.withOpacity(0.4) : AppColors.primarySubtle,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(
                            AppConfig.resolveMediaUrl(avatarUrl) ?? avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Dietitian Name & Title
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            style: TextStyle(fontSize: 11, color: textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // View Profile Action Button
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DietitianProfileScreen(
                        dietitian: dietitian,
                        initialPass: _activePass,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Divider
          Divider(height: 1, color: cardBorder),
          const SizedBox(height: 10),
          // Row 2: Care status & metrics summary
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: hasPass
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        hasPass ? Icons.verified_user_rounded : Icons.medical_information_rounded,
                        size: 14,
                        color: hasPass ? const Color(0xFF059669) : const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasPass
                            ? '${_activePass!.planName} • $remainingSessions Session${remainingSessions == 1 ? '' : 's'} Left'
                            : '1-on-1 Confidential HD Video Care',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasPass ? const Color(0xFF059669) : textSecondary,
                        ),
                        maxLines: 1,
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
                  color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      (dietitian.rating != null && dietitian.rating! > 0)
                          ? dietitian.rating!.toStringAsFixed(1)
                          : '4.9',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate800,
                      ),
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

  Widget _buildSegmentedTabSelector(bool isDark, int upcomingCount, int pastCount) {
    final isUpcomingActive = _tabController.index == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_available_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Upcoming'),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUpcomingActive
                        ? Colors.white.withOpacity(0.25)
                        : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$upcomingCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isUpcomingActive
                          ? Colors.white
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_edu_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Past History'),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: !isUpcomingActive
                        ? Colors.white.withOpacity(0.25)
                        : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pastCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: !isUpcomingActive
                          ? Colors.white
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
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

  Widget _buildFilterChipsRow(
    bool isDark, {
    required List<ConsultationModel> upcoming,
    required List<ConsultationModel> past,
  }) {
    final isUpcomingTab = _tabController.index == 0;
    final currentList = isUpcomingTab ? upcoming : past;

    final scheduledCount = upcoming.where((c) =>
        (c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING') &&
        !c.isRescheduled).length;
    final rescheduledUpcomingCount = upcoming.where((c) => c.isRescheduled).length;
    final rescheduledPastCount = past.where((c) => c.isRescheduled).length;
    final completedCount = past.where((c) => c.status == 'COMPLETED' || c.status == 'VIDEO_COMPLETED').length;
    final cancelledCount = past.where((c) =>
        c.status == 'CANCELLED' || c.status == 'NO_SHOW' || c.status == 'DIETITIAN_NO_SHOW').length;

    final filterOptions = [
      _FilterOption(
        id: 'ALL',
        label: 'All',
        count: currentList.length,
        icon: Icons.grid_view_rounded,
        activeColor: AppColors.primary,
        targetTab: null,
      ),
      _FilterOption(
        id: 'SCHEDULED',
        label: 'Scheduled',
        count: scheduledCount,
        icon: Icons.event_available_rounded,
        activeColor: const Color(0xFF2563EB),
        targetTab: 0,
      ),
      _FilterOption(
        id: 'RESCHEDULED',
        label: 'Rescheduled',
        count: isUpcomingTab ? rescheduledUpcomingCount : rescheduledPastCount,
        icon: Icons.update_rounded,
        activeColor: const Color(0xFFD97706),
        targetTab: null,
      ),
      _FilterOption(
        id: 'COMPLETED',
        label: 'Completed',
        count: completedCount,
        icon: Icons.check_circle_outline_rounded,
        activeColor: const Color(0xFF059669),
        targetTab: 1,
      ),
      _FilterOption(
        id: 'CANCELLED',
        label: 'Cancelled',
        count: cancelledCount,
        icon: Icons.cancel_outlined,
        activeColor: const Color(0xFFDC2626),
        targetTab: 1,
      ),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final opt = filterOptions[idx];
          final isSelected = _selectedStatusFilter == opt.id;

          return InkWell(
            onTap: () => _handleFilterTap(opt),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? opt.activeColor.withOpacity(isDark ? 0.22 : 0.12)
                    : (isDark ? AppColors.slate900 : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? opt.activeColor
                      : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: opt.activeColor.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 13,
                    color: isSelected
                        ? opt.activeColor
                        : (isDark ? AppColors.slate400 : AppColors.slate600),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? opt.activeColor
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? opt.activeColor.withOpacity(0.2)
                          : (isDark ? AppColors.slate800 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${opt.count}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? opt.activeColor
                            : (isDark ? AppColors.slate400 : AppColors.slate500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleFilterTap(_FilterOption opt) {
    setState(() {
      if (_selectedStatusFilter == opt.id && opt.id != 'ALL') {
        _selectedStatusFilter = 'ALL';
      } else {
        _selectedStatusFilter = opt.id;
        if (opt.targetTab != null && _tabController.index != opt.targetTab) {
          _tabController.animateTo(opt.targetTab!);
        } else if (opt.id == 'RESCHEDULED') {
          final isUpcoming = _tabController.index == 0;
          final upcomingRescheduled = _consultations.where((c) =>
              (c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING') && c.isRescheduled).length;
          final pastRescheduled = _consultations.where((c) =>
              (c.status == 'VIDEO_COMPLETED' || c.status == 'COMPLETED' || c.status == 'CANCELLED' || c.status == 'NO_SHOW') && c.isRescheduled).length;
          if (isUpcoming && upcomingRescheduled == 0 && pastRescheduled > 0) {
            _tabController.animateTo(1);
          } else if (!isUpcoming && pastRescheduled == 0 && upcomingRescheduled > 0) {
            _tabController.animateTo(0);
          }
        }
      }
    });
  }

  String _getFilterLabel(String filterId) {
    switch (filterId) {
      case 'SCHEDULED':
        return 'Scheduled';
      case 'RESCHEDULED':
        return 'Rescheduled';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return '';
    }
  }

  Widget _buildContextualBanner({required bool isUpcoming, required bool isDark}) {
    if (isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.22)),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF0284C7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Video calls unlock 10 mins before your scheduled slot. Join on time to review your metabolic metrics & weekly diet plan.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.22)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Clinical session records, dietitian dietary notes, prescribed caloric targets, and follow-up consultation history.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildList(List<ConsultationModel> items, {required bool isUpcoming, required bool isDark}) {
    List<ConsultationModel> displayItems = items;
    if (_selectedStatusFilter != 'ALL') {
      displayItems = items.where((c) {
        switch (_selectedStatusFilter) {
          case 'SCHEDULED':
            return (c.status == 'SCHEDULED' || c.status == 'IN_PROGRESS' || c.status == 'PENDING') && !c.isRescheduled;
          case 'RESCHEDULED':
            return c.isRescheduled;
          case 'COMPLETED':
            return c.status == 'COMPLETED' || c.status == 'VIDEO_COMPLETED';
          case 'CANCELLED':
            return c.status == 'CANCELLED' || c.status == 'NO_SHOW' || c.status == 'DIETITIAN_NO_SHOW';
          default:
            return true;
        }
      }).toList();
    }

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUpcoming ? Icons.event_available_rounded : Icons.history_edu_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isUpcoming ? 'No Upcoming Consultations' : 'No Past Consultations Found',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isUpcoming
                    ? 'Schedule a comprehensive 1-on-1 or family video session with your clinical dietitian.'
                    : 'Your completed consultation assessments, dietary goals, and clinical records will appear here.',
                style: const TextStyle(color: AppColors.slate500, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              if (isUpcoming) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: 220,
                  child: EbicButton(
                    label: 'Book Consultation',
                    icon: Icons.video_call_rounded,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _fetchConsultations()),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (displayItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_list_off_rounded,
                  size: 30,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No ${_getFilterLabel(_selectedStatusFilter)} Consultations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'There are no ${isUpcoming ? 'upcoming' : 'past'} consultations matching this status.',
                style: const TextStyle(color: AppColors.slate500, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedStatusFilter = 'ALL';
                  });
                },
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Show All Consultations'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
      itemCount: displayItems.length + 1,
      separatorBuilder: (_, idx) => SizedBox(height: idx == 0 ? 10 : 14),
      itemBuilder: (ctx, idx) {
        if (idx == 0) {
          return _buildContextualBanner(isUpcoming: isUpcoming, isDark: isDark);
        }
        final c = displayItems[idx - 1];
        return _buildConsultationCard(c, isUpcoming: isUpcoming, isDark: isDark);
      },
    );
  }

  Widget _buildConsultationCard(ConsultationModel c, {required bool isUpcoming, required bool isDark}) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final canCancelOrReschedule = _canModify(c);
    final isInProgress = c.status == 'IN_PROGRESS';
    final isCompleted = c.status == 'COMPLETED';
    final isCancelled = c.status == 'CANCELLED';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress
              ? const Color(0xFFF59E0B).withOpacity(0.5)
              : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
          width: isInProgress ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showConsultationDetailsModal(c),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Status Badge & Consultation Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(
                      c.isDietitianNoShow
                          ? 'DIETITIAN_NO_SHOW'
                          : (c.isRescheduled && (c.status == 'SCHEDULED' || c.status == 'RESCHEDULED')
                              ? 'RESCHEDULED'
                              : c.status),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${c.kindLabel} • ${c.consultationType == 'VIDEO' ? 'HD Video' : c.consultationType}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Doctor Information Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      backgroundImage: c.dietitianPhotoUrl != null && AppConfig.resolveMediaUrl(c.dietitianPhotoUrl) != null
                          ? NetworkImage(AppConfig.resolveMediaUrl(c.dietitianPhotoUrl)!)
                          : null,
                      onBackgroundImageError: c.dietitianPhotoUrl != null ? (_, __) {} : null,
                      child: c.dietitianPhotoUrl == null
                          ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${c.dietitianName}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          if (c.dietitianQualification != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              c.dietitianQualification!,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Attending Members Pill
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 13, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  c.attendingMembers.isNotEmpty
                                      ? 'For: ${c.attendingMembers.join(', ')}'
                                      : 'For: ${c.memberName}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.slate400 : AppColors.slate600,
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
                  ],
                ),
                const SizedBox(height: 12),

                // Date & Time Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800.withOpacity(0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(c.scheduledAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Text(
                            timeFormat.format(c.scheduledAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Clarification Callout
                if (isInProgress) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.pending_actions_rounded, size: 15, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Session Concluded • Dietitian is currently finalizing clinical metrics and nutrition goals from the clinic portal.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (c.isRescheduled && (c.status == 'SCHEDULED' || c.status == 'RESCHEDULED')) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.update_rounded, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.reason != null && c.reason!.isNotEmpty
                                ? 'Rescheduled: ${c.reason}'
                                : 'Session has been rescheduled to a new time slot.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF047857)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Clinical consultation finalized & diet plan activated.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Action Buttons — the customer can only ever JOIN a video
                // call, never start one: the dietitian initiates it, which
                // is what flips status to IN_PROGRESS. Showing a "Join"
                // button before that would let the customer sit in an empty
                // call on their own.
                if (isUpcoming && !isInProgress) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 16, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your dietitian will start the video call at the scheduled time — you\'ll be able to join from here.',
                            style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.slate400 : AppColors.slate600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: EbicButton(
                      label: 'Details',
                      icon: Icons.info_outline_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: () => _showConsultationDetailsModal(c),
                    ),
                  ),
                  if (canCancelOrReschedule) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.slate700,
                              side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.edit_calendar_rounded, size: 15, color: AppColors.primary),
                            label: const Text('Reschedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () => _showRescheduleSheet(c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: BorderSide(color: AppColors.danger.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.danger),
                            label: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onPressed: () => _cancelConsultation(c),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else if (isInProgress) ...[
                  Row(
                    children: [
                      Expanded(
                        child: EbicButton(
                          label: 'Join Video Call',
                          icon: Icons.videocam_rounded,
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.consultationVideo,
                              arguments: {'consultation': c},
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: EbicButton(
                          label: 'View Details',
                          variant: EbicButtonVariant.outline,
                          onPressed: () => _showConsultationDetailsModal(c),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Past actions (Completed, Cancelled)
                  Row(
                    children: [
                      Expanded(
                        child: EbicButton(
                          label: 'View Details',
                          variant: EbicButtonVariant.ghost,
                          icon: Icons.info_outline_rounded,
                          onPressed: () => _showConsultationDetailsModal(c),
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: EbicButton(
                            label: 'View Diet Plan',
                            icon: Icons.restaurant_menu_rounded,
                            variant: EbicButtonVariant.primary,
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                          ),
                        ),
                      ] else if (c.status == 'NO_SHOW') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: EbicButton(
                            label: 'Reschedule',
                            icon: Icons.event_repeat_rounded,
                            variant: EbicButtonVariant.primary,
                            onPressed: () async {
                              final done = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => RescheduleBottomSheet(consultation: c),
                              );
                              if (done == true) _fetchConsultations(silent: true);
                            },
                          ),
                        ),
                      ] else if (isCancelled) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: EbicButton(
                            label: 'Book New',
                            icon: Icons.add_rounded,
                            variant: EbicButtonVariant.outline,
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _fetchConsultations()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'SCHEDULED':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = 'CONFIRMED';
        icon = Icons.calendar_today_rounded;
        break;
      case 'RESCHEDULED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'RESCHEDULED';
        icon = Icons.update_rounded;
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'IN PROGRESS';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'VIDEO_COMPLETED':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'NOTES PENDING';
        icon = Icons.pending_actions_rounded;
        break;
      case 'COMPLETED':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = 'COMPLETED';
        icon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'CANCELLED';
        icon = Icons.cancel_outlined;
        break;
      case 'NO_SHOW':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = 'MISSED';
        icon = Icons.event_busy_rounded;
        break;
      case 'DIETITIAN_NO_SHOW':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        label = 'DIETITIAN DIDN\'T JOIN';
        icon = Icons.event_busy_rounded;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class RescheduleBottomSheet extends StatefulWidget {
  final ConsultationModel consultation;

  const RescheduleBottomSheet({super.key, required this.consultation});

  @override
  State<RescheduleBottomSheet> createState() => _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState extends State<RescheduleBottomSheet> {
  final ApiClient _api = ApiClient();
  final TextEditingController _reasonController = TextEditingController();

  bool _isLoadingSlots = true;
  bool _isSubmitting = false;
  List<DietitianSlotModel> _allSlots = [];
  late DateTime _selectedDate;
  DietitianSlotModel? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _fetchSlots();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final res = await _api.get<List<dynamic>>(
        ApiEndpoints.dietitianAvailability(widget.consultation.dietitianId),
      );
      if (res.success && res.data != null && mounted) {
        final parsed = res.data!
            .map((e) => DietitianSlotModel.fromJson(e as Map<String, dynamic>))
            .where((s) => s.startsAt.isAfter(DateTime.now()))
            .toList();

        parsed.sort((a, b) => a.startsAt.compareTo(b.startsAt));

        setState(() {
          _allSlots = parsed;
          _isLoadingSlots = false;
          if (_allSlots.isNotEmpty) {
            final firstAvailable = _allSlots.firstWhere(
              (s) => !s.isBooked,
              orElse: () => _allSlots.first,
            );
            _selectedDate = firstAvailable.startsAt;
            _selectedSlot = firstAvailable.isBooked ? null : firstAvailable;
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _allSlots = [];
            _isLoadingSlots = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _submitReschedule() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available time slot.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultationReschedule(widget.consultation.id),
        body: {
          'slotId': _selectedSlot!.id,
          'scheduledAt': _selectedSlot!.startsAt.toIso8601String(),
          'reason': _reasonController.text.trim().isNotEmpty
              ? _reasonController.text.trim()
              : 'Customer requested reschedule',
        },
      );

      if (res.success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'Failed to reschedule consultation.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSlotLegendItem(Color dotColor, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableDates = <DateTime>[];
    final now = DateTime.now();
    for (int i = 1; i <= 14; i++) {
      availableDates.add(DateTime(now.year, now.month, now.day + i));
    }

    final slotsForDate = _allSlots.where((s) {
      return s.startsAt.year == _selectedDate.year &&
          s.startsAt.month == _selectedDate.month &&
          s.startsAt.day == _selectedDate.day;
    }).toList();

    final timeFormat = DateFormat('hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reschedule Consultation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'With Dr. ${widget.consultation.dietitianName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.slate800 : AppColors.slate200),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select New Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableDates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final d = availableDates[idx];
                        final isSelected = d.year == _selectedDate.year &&
                            d.month == _selectedDate.month &&
                            d.day == _selectedDate.day;

                        final dateSlots = _allSlots.where((s) =>
                          s.startsAt.year == d.year &&
                          s.startsAt.month == d.month &&
                          s.startsAt.day == d.day
                        ).toList();
                        final openSlotsCount = dateSlots.where((s) => !s.isBooked).length;

                        String dayLabel = DateFormat('EEE').format(d).toUpperCase();
                        if (idx == 0) dayLabel = 'TOMORROW';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = d;
                              final firstAvailable = dateSlots.where((s) => !s.isBooked).firstOrNull;
                              _selectedSlot = firstAvailable;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 76,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.slate800 : AppColors.slate50),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.slate700 : AppColors.slate200),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1,
                                    color: isSelected ? Colors.white70 : AppColors.slate500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('d').format(d),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.slate900),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (openSlotsCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.25)
                                          : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$openSlotsCount open',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF047857),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.2)
                                          : (isDark ? AppColors.slate700 : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Full',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white70 : AppColors.slate400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Time Slot',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                      Row(
                        children: [
                          _buildSlotLegendItem(const Color(0xFF10B981), 'Available', isDark),
                          const SizedBox(width: 8),
                          _buildSlotLegendItem(AppColors.slate400, 'Not Available', isDark),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLoadingSlots)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (slotsForDate.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                      ),
                      child: const Text(
                        'No slots scheduled on this date. Please pick another date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slotsForDate.map((slot) {
                        final isSelected = _selectedSlot?.id == slot.id;
                        final isBooked = slot.isBooked;
                        final isCurrentSlot = slot.startsAt.isAtSameMomentAs(widget.consultation.scheduledAt);

                        if (isBooked && !isCurrentSlot) {
                          // NOT AVAILABLE / BOOKED
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800.withOpacity(0.5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block_rounded, size: 12, color: AppColors.slate400),
                                const SizedBox(width: 5),
                                Text(
                                  timeFormat.format(slot.startsAt),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Booked',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (isCurrentSlot) {
                          // CURRENT CONSULTATION SLOT
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 12, color: Color(0xFFB45309)),
                                const SizedBox(width: 5),
                                Text(
                                  timeFormat.format(slot.startsAt),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE68A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Current',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // AVAILABLE SLOT (Selectable)
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedSlot = slot);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primarySubtle
                                  : (isDark ? AppColors.slate800 : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.slate700 : const Color(0xFF10B981)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.access_time_rounded,
                                  size: 13,
                                  color: isSelected ? AppColors.primaryDark : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  timeFormat.format(slot.startsAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : (isDark ? Colors.white : AppColors.slate800),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.15)
                                        : const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isSelected ? 'Selected' : 'Available',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.primaryDark : const Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Reason for Rescheduling (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.slate900, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Work schedule conflict, travel, etc.',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pinned Bottom Actions
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  12,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
              border: Border(
                top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: _isSubmitting
                        ? 'Rescheduling...'
                        : (_selectedSlot == null
                            ? 'Select an Available Slot'
                            : 'Confirm Reschedule (${DateFormat('dd MMM, hh:mm a').format(_selectedSlot!.startsAt)})'),
                    icon: Icons.check_circle_rounded,
                    isLoading: _isSubmitting,
                    onPressed: (_isSubmitting || _selectedSlot == null)
                        ? null
                        : _submitReschedule,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Keep Current Appointment',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
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
}

class _FilterOption {
  final String id;
  final String label;
  final int count;
  final IconData icon;
  final Color activeColor;
  final int? targetTab;

  const _FilterOption({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.activeColor,
    this.targetTab,
  });
}
