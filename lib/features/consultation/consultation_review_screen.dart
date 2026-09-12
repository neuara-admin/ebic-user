import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/consultation_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../health_pass/data/health_pass_repository.dart';

/// Dedicated Consultation Review & Confirmation Screen
/// Compact, uncluttered summary of specialist, schedule, attending family members,
/// and instant 1-tap confirmation.
class ConsultationReviewScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const ConsultationReviewScreen({super.key, this.arguments});

  @override
  State<ConsultationReviewScreen> createState() => _ConsultationReviewScreenState();
}

class _ConsultationReviewScreenState extends State<ConsultationReviewScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _notesController = TextEditingController();

  late DietitianModel _dietitian;
  late DietitianSlotModel _slot;
  late List<String> _selectedMemberIds;
  late Map<String, String> _memberNamesMap;
  ActiveHealthPassModel? _activePass;

  String? _userHubId;
  String? _userHubName;
  String? _userHubCode;

  bool _isBooking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final args = widget.arguments ?? {};
    _dietitian = args['dietitian'] as DietitianModel;
    _slot = args['slot'] as DietitianSlotModel;
    _selectedMemberIds = (args['selectedMemberIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _memberNamesMap = (args['memberNamesMap'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    _activePass = args['activePass'] as ActiveHealthPassModel?;
    _userHubId = args['userHubId'] as String?;
    _userHubName = args['userHubName'] as String?;
    _userHubCode = args['userHubCode'] as String?;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    setState(() {
      _isBooking = true;
      _errorMessage = null;
    });

    try {
      final selectedNames = _selectedMemberIds.map((id) => _memberNamesMap[id] ?? id).join(', ');
      final userNotes = _notesController.text.trim();

      final payload = {
        'dietitianId': _dietitian.id,
        'healthPassMemberId': _selectedMemberIds.isNotEmpty ? _selectedMemberIds.first : null,
        'healthPassMemberIds': _selectedMemberIds,
        'memberNames': selectedNames,
        'slotId': _slot.id,
        'scheduledAt': _slot.startsAt.toIso8601String(),
        'consultationType': 'VIDEO',
        'reason': userNotes.isNotEmpty
            ? userNotes
            : (_selectedMemberIds.length > 1
                ? 'Family Clinical Nutrition Consultation'
                : 'Clinical Dietitian Consultation'),
        'hubId': _userHubId ?? _dietitian.hubId,
        'hubName': _userHubName ?? _dietitian.hubName,
        'hubCode': _userHubCode ?? _dietitian.hubCode,
      };

      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.consultations,
        body: payload,
        requiresIdempotency: true,
      );

      setState(() => _isBooking = false);

      if (res.success) {
        HealthPassRepository.notifyPassUpdated();

        ConsultationModel? createdModel;
        String? createdId;
        if (res.data != null) {
          try {
            createdModel = ConsultationModel.fromJson(res.data!);
            createdId = createdModel.id;
          } catch (_) {
            createdId = res.data!['id']?.toString();
          }
        }

        if (mounted) {
          _showBookingSuccessModal(
            selectedNames,
            createdConsultation: createdModel,
            consultationId: createdId,
          );
        }
      } else {
        setState(() {
          _errorMessage = res.message ?? 'Booking failed. This slot may have just been taken.';
        });
      }
    } catch (e) {
      setState(() {
        _isBooking = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showBookingSuccessModal(
    String attendeeNames, {
    ConsultationModel? createdConsultation,
    String? consultationId,
  }) {
    final dateFormat = DateFormat('EEEE, dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 34),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Consultation Scheduled!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confirmed with Dr. ${_dietitian.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _modalInfoRow(
                          Icons.calendar_today_rounded,
                          'Date & Time',
                          '${dateFormat.format(_slot.startsAt)}\n${timeFormat.format(_slot.startsAt)} – ${timeFormat.format(_slot.endsAt)}',
                          isDark,
                        ),
                        const Divider(height: 14),
                        _modalInfoRow(
                          Icons.groups_rounded,
                          'Attendees',
                          attendeeNames,
                          isDark,
                        ),
                        const Divider(height: 14),
                        _modalInfoRow(
                          Icons.videocam_rounded,
                          'Meeting Mode',
                          'HD Video Call (Link sent via WhatsApp & SMS)',
                          isDark,
                          highlightColor: const Color(0xFF047857),
                        ),
                        const Divider(height: 14),
                        _modalInfoRow(
                          Icons.verified_rounded,
                          'Consultation Fee',
                          '₹0 (100% Free with Health Pass)',
                          isDark,
                          highlightColor: const Color(0xFF047857),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: EbicButton(
                      label: 'View Consultation Details',
                      icon: Icons.info_outline_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Pop review screen
                        Navigator.pop(context); // Pop book screen
                        Navigator.pushNamed(
                          context,
                          AppRoutes.consultationDetail,
                          arguments: {
                            'consultation': ?createdConsultation,
                            'id': ?consultationId,
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: EbicButton(
                      label: 'View All Consultations',
                      icon: Icons.calendar_month_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Pop review screen
                        Navigator.pop(context); // Pop book screen
                        Navigator.pushNamed(context, AppRoutes.consultationsList);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: EbicButton(
                      label: 'Done',
                      variant: EbicButtonVariant.ghost,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _modalInfoRow(IconData icon, String label, String value, bool isDark, {Color? highlightColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: highlightColor ?? AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? (isDark ? Colors.white : AppColors.slate800),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateFormat = DateFormat('EEEE, dd MMMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final dateStr = dateFormat.format(_slot.startsAt);
    final timeStr = '${timeFormat.format(_slot.startsAt)} – ${timeFormat.format(_slot.endsAt)} (45 mins)';
    final attendeesList = _selectedMemberIds.map((id) => _memberNamesMap[id] ?? id).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: const Text('Review Consultation'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Unified Consultation Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Specialist Row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                backgroundImage: _dietitian.photoUrl != null
                                    ? NetworkImage(_dietitian.photoUrl!)
                                    : null,
                                child: _dietitian.photoUrl == null
                                    ? const Icon(Icons.person, color: AppColors.primary, size: 26)
                                    : null,
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
                                            'Dr. ${_dietitian.name}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, color: AppColors.primary, size: 15),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_dietitian.qualification ?? "Clinical Dietitian"} • ${_dietitian.experienceYears}y exp',
                                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),

                          // 2. Timing Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF047857)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HD Video',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),

                          // 3. Attending Members
                          Text(
                            'ATTENDING FAMILY MEMBERS (${attendeesList.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: attendeesList.map((name) {
                              return Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate800 : AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const Divider(height: 22),

                          // 4. Clean Fee Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Consultation Fee',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _activePass != null
                                        ? '${_activePass!.planName} • 100% Free'
                                        : 'Covered by Health Pass',
                                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '₹0 (FREE)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Preparation Checklist Card (What customer needs to keep ready)
                    _buildPreparationChecklistCard(isDark),
                    const SizedBox(height: 16),

                    // 6. Notes / Specific Health Concerns (Optional)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes for Doctor (Optional)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'e.g. Any health concerns, diet goals, or recent lab reports...',
                              hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
                              filled: true,
                              fillColor: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA: Confirm & Schedule
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: EbicButton(
                    label: _isBooking ? 'Scheduling Consultation...' : 'Confirm Consultation (Free)',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isBooking,
                    onPressed: _isBooking ? null : _confirmBooking,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparationChecklistCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fact_check_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Things to Keep Ready for Consultation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Help your dietitian provide the most accurate clinical recommendations',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFBFDBFE)),
          const SizedBox(height: 12),
          _checklistRow(
            Icons.monitor_weight_outlined,
            'Recent Height & Weight',
            'Take recent weight and height measurements for all attending family members.',
            isDark,
          ),
          const SizedBox(height: 10),
          _checklistRow(
            Icons.medical_services_outlined,
            'Recent Lab & Blood Reports',
            'Keep HbA1c, lipid profile, CBC, thyroid, or recent pathology tests (last 3-6 months) handy.',
            isDark,
          ),
          const SizedBox(height: 10),
          _checklistRow(
            Icons.medication_outlined,
            'Medications & Supplements',
            'Have a list of active daily prescriptions, vitamins, or diabetic medicines being taken.',
            isDark,
          ),
          const SizedBox(height: 10),
          _checklistRow(
            Icons.restaurant_outlined,
            'Diet Preferences & Allergies',
            'Note dietary restrictions (veg/non-veg/jain), known food allergies, or digestive discomforts.',
            isDark,
          ),
          const SizedBox(height: 10),
          _checklistRow(
            Icons.videocam_outlined,
            'Quiet Environment & Internet',
            'Join the call from a quiet room with stable Wi-Fi/4G connection and camera enabled.',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(IconData icon, String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
