import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_button.dart';
import 'consultation_list_screen.dart';

class ConsultationDetailScreen extends StatefulWidget {
  final ConsultationModel? initialConsultation;
  final String? consultationId;

  const ConsultationDetailScreen({
    super.key,
    this.initialConsultation,
    this.consultationId,
  });

  @override
  State<ConsultationDetailScreen> createState() => _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  final ApiClient _api = ApiClient();

  ConsultationModel? _consultation;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _consultation = widget.initialConsultation;
    if (_consultation == null && widget.consultationId != null) {
      _fetchConsultation();
    } else if (_consultation != null) {
      // Re-fetch in background to get latest dietitian notes / status updates
      _fetchConsultation(silent: true);
    }
  }

  Future<void> _fetchConsultation({bool silent = false}) async {
    final id = _consultation?.id ?? widget.consultationId;
    if (id == null || id.isEmpty) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.consultation(id));
      if (res.success && res.data != null && mounted) {
        setState(() {
          _consultation = ConsultationModel.fromJson(res.data!);
          _isLoading = false;
        });
      } else {
        if (mounted && !silent) {
          setState(() {
            _errorMessage = res.message ?? 'Failed to load consultation details.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = 'Could not load details: $e';
          _isLoading = false;
        });
      }
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
          content: Text('Only upcoming scheduled appointments can be cancelled.'),
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
              'Are you sure you want to cancel your consultation with Dr. ${c.dietitianName}?',
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
        await _fetchConsultation();
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
      await _fetchConsultation();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = _consultation;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Consultation Details'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchConsultation(),
          ),
        ],
      ),
      body: _isLoading && c == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && c == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.slate600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _fetchConsultation(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : c == null
                  ? const Center(child: Text('Consultation not found.'))
                  : RefreshIndicator(
                      onRefresh: () => _fetchConsultation(),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Status Banner Card
                                  _buildStatusBanner(c, isDark),
                                  const SizedBox(height: 14),

                                  // 2. Doctor Profile Card
                                  _buildDoctorCard(c, isDark),
                                  const SizedBox(height: 14),

                                  // 3. Consultation Timing Card (Start, End, Duration, Mode)
                                  _buildScheduleCard(c, isDark),
                                  const SizedBox(height: 14),

                                  // 4. Attending Family Members Card
                                  _buildAttendingMembersCard(c, isDark),
                                  const SizedBox(height: 14),

                                  // 5. Clinical Notes & Observations (Start, End, Notes, Recommendations)
                                  _buildClinicalNotesCard(c, isDark),
                                  const SizedBox(height: 14),

                                  // 6. Attached Medical & Clinical Documents
                                  _buildAttachedDocumentsCard(c, isDark),
                                  const SizedBox(height: 14),

                                  // 7. Diet Plan & Session Actions Card
                                  _buildDietPlanAndBookingCard(c, isDark),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                          // Sticky Bottom Action Bar
                          _buildBottomActionBar(c, isDark),
                        ],
                      ),
                    ),
    );
  }

  // 1. Status Banner
  Widget _buildStatusBanner(ConsultationModel c, bool isDark) {
    Color bg;
    Color border;
    Color iconColor;
    Color titleColor;
    IconData icon;
    String title;
    String subtitle;

    switch (c.status) {
      case 'IN_PROGRESS':
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFF59E0B);
        iconColor = const Color(0xFFB45309);
        titleColor = const Color(0xFF92400E);
        icon = Icons.hourglass_top_rounded;
        title = 'Session Concluded / In Progress';
        subtitle =
            'Your clinical dietitian is currently reviewing vitals and designing your personalized nutritional plan from the portal.';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFD1FAE5);
        border = const Color(0xFF10B981);
        iconColor = const Color(0xFF047857);
        titleColor = const Color(0xFF065F46);
        icon = Icons.verified_rounded;
        title = 'Consultation Completed & Pass Active';
        subtitle =
            'Clinical metrics recorded, dietary goals finalized, and your personalized diet plan is activated.';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        border = const Color(0xFFEF4444);
        iconColor = const Color(0xFFB91C1C);
        titleColor = const Color(0xFF7F1D1D);
        icon = Icons.cancel_outlined;
        title = 'Appointment Cancelled';
        subtitle =
            'This consultation has been cancelled. You can easily book a new slot anytime with your preferred dietitian.';
        break;
      case 'SCHEDULED':
      default:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFF3B82F6);
        iconColor = const Color(0xFF1D4ED8);
        titleColor = const Color(0xFF1E3A8A);
        icon = Icons.event_available_rounded;
        title = 'Appointment Confirmed & Scheduled';
        subtitle =
            'Your 1-on-1 HD video session is reserved. Video room opens 5 minutes before scheduled start.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: titleColor.withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Doctor Card
  Widget _buildDoctorCard(ConsultationModel c, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            backgroundImage:
                c.dietitianPhotoUrl != null ? NetworkImage(c.dietitianPhotoUrl!) : null,
            onBackgroundImageError: c.dietitianPhotoUrl != null ? (_, __) {} : null,
            child: c.dietitianPhotoUrl == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 34)
                : null,
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
                        'Dr. ${c.dietitianName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16, color: AppColors.primary),
                  ],
                ),
                if (c.dietitianQualification != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    c.dietitianQualification!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (c.dietitianSpecialization != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.dietitianSpecialization!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (c.hubName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 11, color: AppColors.slate500),
                            const SizedBox(width: 4),
                            Text(
                              c.hubName!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Assigned Nutritionist',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
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

  // 3. Consultation Timing Card (Start Time, End Time, Duration, Mode)
  Widget _buildScheduleCard(ConsultationModel c, bool isDark) {
    final endsAt = c.endsAt ?? c.scheduledAt.add(const Duration(minutes: 45));
    final durationMins = endsAt.difference(c.scheduledAt).inMinutes;

    final dateStr = DateFormat('dd MMM yyyy (EEE)').format(c.scheduledAt);
    final startTimeStr = DateFormat('hh:mm a').format(c.scheduledAt);
    final endTimeStr = DateFormat('hh:mm a').format(endsAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CONSULTATION TIMING & SCHEDULE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 11, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      c.status == 'COMPLETED' ? 'COMPLETED' : 'SCHEDULED',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2-Column Start and End Times with Visual Connecting Line
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dateStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$durationMins mins duration',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 13, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'START TIME',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate400,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            startTimeStr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 34, color: isDark ? AppColors.slate700 : AppColors.slate200),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.stop_circle_rounded, size: 13, color: Color(0xFFEF4444)),
                              SizedBox(width: 4),
                              Text(
                                'END TIME',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate400,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            endTimeStr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Mode & Hub badges
          Row(
            children: [
              Expanded(
                child: _specTile(
                  icon: Icons.videocam_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFF5F3FF),
                  title: 'MODE',
                  mainValue: c.consultationType,
                  subtitle: '1-on-1 Encrypted',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _specTile(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  title: 'BENEFIT',
                  mainValue: '₹0 (Included)',
                  mainValueColor: const Color(0xFF047857),
                  subtitle: 'Health Pass Entitlement',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String mainValue,
    required String subtitle,
    required bool isDark,
    Color? mainValueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withOpacity(0.2) : iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate400,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: mainValueColor ?? (isDark ? Colors.white : AppColors.slate800),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Attending Family Members
  Widget _buildAttendingMembersCard(ConsultationModel c, bool isDark) {
    final attendees = c.attendingMembers.isNotEmpty ? c.attendingMembers : [c.memberName];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ATTENDING FAMILY MEMBERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${attendees.length} Covered',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attendees.map((name) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 64,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 5. Clinical Notes & Observations Card (Notes, Assessment, Recommendations)
  Widget _buildClinicalNotesCard(ConsultationModel c, bool isDark) {
    final hasNotes = c.notes != null && c.notes!.trim().isNotEmpty;
    final hasAssessment = c.assessment != null && c.assessment!.trim().isNotEmpty;
    final hasRecommendations = c.recommendations != null && c.recommendations!.trim().isNotEmpty;
    final hasGoals = c.goals != null && c.goals!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLINICAL NOTES & OBSERVATIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Doctor findings, nutritional targets & clinical remarks',
                      style: TextStyle(fontSize: 10.5, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Clinical Notes
          if (hasNotes) ...[
            _noteBlock(
              title: 'Doctor Notes / Consultation Focus',
              content: c.notes!,
              icon: Icons.notes_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Clinical Assessment
          if (hasAssessment) ...[
            _noteBlock(
              title: 'Dietitian Clinical Assessment',
              content: c.assessment!,
              icon: Icons.medical_services_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Recommendations & Targets
          if (hasRecommendations) ...[
            _noteBlock(
              title: 'Recommendations & Nutritional Plan Targets',
              content: c.recommendations!,
              icon: Icons.tips_and_updates_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Goals
          if (hasGoals) ...[
            _noteBlock(
              title: 'Family Health & Dietary Goals',
              content: c.goals!,
              icon: Icons.track_changes_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Empty state if consultation upcoming
          if (!hasNotes && !hasAssessment && !hasRecommendations && !hasGoals) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clinical notes, nutritional observations, and diet targets will be documented by Dr. ${c.dietitianName} during the call.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                        height: 1.35,
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

  Widget _noteBlock({
    required String title,
    required String content,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : AppColors.slate800,
            ),
          ),
        ],
      ),
    );
  }

  // 6. Attached Medical & Clinical Documents Card
  Widget _buildAttachedDocumentsCard(ConsultationModel c, bool isDark) {
    final docs = c.documents;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      child: const Icon(Icons.description_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLINICAL DOCUMENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate500,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${docs.length} document${docs.length == 1 ? '' : 's'} linked',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.slate400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.healthDocumentUpload);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (docs.isNotEmpty) ...[
            ...docs.map((doc) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc.documentType ?? 'Medical Record',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.healthDocuments);
                      },
                      child: const Text('View', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 24, color: AppColors.slate400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No clinical records attached yet. Upload lab panels or past prescriptions for doctor review.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                        height: 1.35,
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

  // 7. Diet Plan & Session Actions Card (View Diet Plan, Book Session)
  Widget _buildDietPlanAndBookingCard(ConsultationModel c, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIET PLAN & APPOINTMENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                  label: const Text(
                    'View Diet Plan',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : AppColors.slate800,
                    side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Book Session',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 8. Sticky Bottom Actions Bar
  Widget _buildBottomActionBar(ConsultationModel c, bool isDark) {
    final isUpcoming = c.status == 'SCHEDULED' || c.status == 'PENDING';
    final isInProgress = c.status == 'IN_PROGRESS';
    final isCompleted = c.status == 'COMPLETED';
    final canModify = _canModify(c);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'Join Video Call',
                  icon: Icons.videocam_rounded,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.consultationVideo,
                      arguments: {'consultation': c},
                    ).then((_) => _fetchConsultation(silent: true));
                  },
                ),
              ),
              if (canModify) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.slate800,
                          side: BorderSide(color: isDark ? AppColors.slate700 : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 15, color: AppColors.primary),
                        label: const Text('Reschedule', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.danger),
                        label: const Text('Cancel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                    flex: 5,
                    child: EbicButton(
                      label: 'Re-join Video Call',
                      icon: Icons.videocam_rounded,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.consultationVideo,
                          arguments: {'consultation': c},
                        ).then((_) => _fetchConsultation(silent: true));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: EbicButton(
                      label: 'Refresh',
                      icon: Icons.refresh_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: () => _fetchConsultation(),
                    ),
                  ),
                ],
              ),
            ] else if (isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: EbicButton(
                      label: 'View Diet Plan',
                      icon: Icons.restaurant_menu_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: EbicButton(
                      label: 'Book Session',
                      icon: Icons.add_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: EbicButton(
                  label: 'Book New Consultation',
                  icon: Icons.add_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
