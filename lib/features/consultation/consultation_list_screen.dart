import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/widgets/ebic_button.dart';

class ConsultationListScreen extends StatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  State<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends State<ConsultationListScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<ConsultationModel> _consultations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchConsultations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchConsultations() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.consultations);
      if (res.success && res.data != null && mounted) {
        setState(() {
          _consultations = res.data!
              .map((json) => ConsultationModel.fromJson(json as Map<String, dynamic>))
              .toList();
          // Sort newest first
          _consultations.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _consultations = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

    // Past contains COMPLETED, CANCELLED, NO_SHOW
    final past = _consultations.where((c) {
      return c.status == 'COMPLETED' || c.status == 'CANCELLED' || c.status == 'NO_SHOW';
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dietitian Consultations'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Upcoming'),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${upcoming.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Past Consultations'),
                  if (past.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${past.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConsultations,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(upcoming, isUpcoming: true, isDark: isDark),
                  _buildList(past, isUpcoming: false, isDark: isDark),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Book Consultation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.consultationBook).then((_) => _fetchConsultations()),
      ),
    );
  }

  Widget _buildList(List<ConsultationModel> items, {required bool isUpcoming, required bool isDark}) {
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        final c = items[idx];
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
                // Top Row: Status Badge & Regional Hub / Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusChip(c.status),
                    Row(
                      children: [
                        if (c.hubName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 11, color: AppColors.slate500),
                                const SizedBox(width: 4),
                                Text(
                                  c.hubName!,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          c.consultationType == 'VIDEO' ? 'HD Video' : c.consultationType,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
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
                      backgroundImage: c.dietitianPhotoUrl != null ? NetworkImage(c.dietitianPhotoUrl!) : null,
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

                // Action Buttons
                if (isUpcoming && !isInProgress) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
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
                        flex: 3,
                        child: EbicButton(
                          label: 'Details',
                          icon: Icons.info_outline_rounded,
                          variant: EbicButtonVariant.outline,
                          onPressed: () => _showConsultationDetailsModal(c),
                        ),
                      ),
                    ],
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
                          label: 'Re-join Video Call',
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
      case 'IN_PROGRESS':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'IN PROGRESS';
        icon = Icons.hourglass_top_rounded;
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
