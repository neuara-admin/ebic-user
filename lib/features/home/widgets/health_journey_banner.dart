import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';

enum HealthPassStage {
  noPass,
  kickoffNeeded,
  consultationScheduled,
  consultationInProgress,
  /// Video call done; the dietitian is finalizing notes (VIDEO_COMPLETED).
  consultationAwaitingNotes,
  /// The member missed the call (NO_SHOW) and can reschedule it.
  consultationMissed,
  /// The dietitian never started the call; it was cancelled and not counted.
  consultationDietitianMissed,
  mealCurationInProgress,
  mealsAssigned,
  subscriptionActive,
}

class HealthJourneyStepper extends StatefulWidget {
  final HealthPassStage currentStage;
  final String? dietitianName;
  final String? memberName;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onUploadDocuments;

  const HealthJourneyStepper({
    super.key,
    required this.currentStage,
    this.dietitianName,
    this.memberName,
    this.onPrimaryAction,
    this.onUploadDocuments,
  });

  @override
  State<HealthJourneyStepper> createState() => _HealthJourneyStepperState();
}

class _HealthJourneyStepperState extends State<HealthJourneyStepper> {
  int? _inspectedStep;

  int get _activeStepIndex {
    switch (widget.currentStage) {
      case HealthPassStage.noPass:
        return 0;
      case HealthPassStage.kickoffNeeded:
      case HealthPassStage.consultationMissed:
      case HealthPassStage.consultationDietitianMissed:
        return 1;
      case HealthPassStage.consultationScheduled:
      case HealthPassStage.consultationInProgress:
      case HealthPassStage.consultationAwaitingNotes:
        return 2;
      case HealthPassStage.mealCurationInProgress:
        return 3;
      case HealthPassStage.mealsAssigned:
      case HealthPassStage.subscriptionActive:
        return 4;
    }
  }

  int get _displayedStep => _inspectedStep ?? _activeStepIndex;

  String get _cleanDoctorName {
    final dr = widget.dietitianName;
    if (dr != null && dr.trim().isNotEmpty) {
      return dr.startsWith('Dr.') ? dr : 'Dr. $dr';
    }
    return 'Dietitian';
  }

  Map<String, dynamic> _getStepData(int stepNum) {
    final active = _activeStepIndex;
    final isDone = active > stepNum;
    final isCurrent = active == stepNum;

    switch (stepNum) {
      case 1:
        String badge = 'Step 1 • Action Needed';
        Color badgeColor = const Color(0xFFD97706);
        Color badgeBg = const Color(0xFFFEF3C7);
        if (isDone) {
          badge = 'Step 1 • Completed';
          badgeColor = const Color(0xFF059669);
          badgeBg = const Color(0xFFD1FAE5);
        } else if (widget.currentStage == HealthPassStage.consultationMissed) {
          badge = 'Step 1 • Missed Call';
          badgeColor = AppColors.danger;
          badgeBg = const Color(0xFFFEE2E2);
        }

        return {
          'title': isDone ? 'Kickoff Call Finished' : 'Schedule Kickoff Call',
          'subtitle': isDone
              ? 'Health records uploaded and kickoff completed with $_cleanDoctorName.'
              : 'Book your 1-on-1 assessment to analyze vitals and activate your meal plan countdown.',
          'badge': badge,
          'badgeColor': badgeColor,
          'badgeBg': badgeBg,
          'icon': Icons.calendar_month_rounded,
          'cta': isDone ? 'View Consultation' : 'Schedule Call',
          'route': AppRoutes.consultationBook,
          'showUpload': !isDone,
        };

      case 2:
        String badge = isDone ? 'Step 2 • Completed' : (isCurrent ? 'Step 2 • Active' : 'Step 2 • Upcoming');
        Color badgeColor = isDone
            ? const Color(0xFF059669)
            : (isCurrent ? const Color(0xFF4F46E5) : AppColors.slate600);
        Color badgeBg = isDone
            ? const Color(0xFFD1FAE5)
            : (isCurrent ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9));
        IconData icon = Icons.video_call_rounded;
        String title = 'Clinical Video Consultation';
        String subtitle = '1-on-1 session with $_cleanDoctorName to evaluate metabolic targets & allergies.';
        String cta = 'View Call';
        String route = AppRoutes.consultationBook;

        if (widget.currentStage == HealthPassStage.consultationInProgress) {
          badge = 'LIVE NOW';
          badgeColor = const Color(0xFF059669);
          badgeBg = const Color(0xFFD1FAE5);
          title = 'Consultation In Progress';
          subtitle = '$_cleanDoctorName is waiting in your secure clinical video room.';
          cta = 'Join Video Call';
          icon = Icons.videocam_rounded;
        } else if (widget.currentStage == HealthPassStage.consultationAwaitingNotes) {
          badge = 'Step 2 • Finalizing Notes';
          badgeColor = const Color(0xFF0D9488);
          badgeBg = const Color(0xFFCCFBF1);
          title = 'Dietitian Writing Clinical Directives';
          subtitle = '$_cleanDoctorName is finalizing your medical diet guidelines and macro targets.';
          cta = 'Chat with Doctor';
          route = AppRoutes.dietitianChat;
          icon = Icons.chat_bubble_outline_rounded;
        } else if (widget.currentStage == HealthPassStage.consultationScheduled) {
          badge = 'Step 2 • Confirmed';
          badgeColor = const Color(0xFF4F46E5);
          badgeBg = const Color(0xFFEEF2FF);
          title = 'Consultation Confirmed';
          subtitle = 'Video call with $_cleanDoctorName is confirmed. Ensure lab reports are uploaded.';
          cta = 'View Details';
        }

        return {
          'title': title,
          'subtitle': subtitle,
          'badge': badge,
          'badgeColor': badgeColor,
          'badgeBg': badgeBg,
          'icon': icon,
          'cta': cta,
          'route': route,
          'showUpload': false,
        };

      case 3:
        String badge = isDone ? 'Step 3 • Completed' : (isCurrent ? 'Step 3 • In Progress' : 'Step 3 • Upcoming');
        Color badgeColor = isDone
            ? const Color(0xFF059669)
            : (isCurrent ? const Color(0xFF0D9488) : AppColors.slate600);
        Color badgeBg = isDone
            ? const Color(0xFFD1FAE5)
            : (isCurrent ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9));

        return {
          'title': isDone ? 'Diet Plan Prescribed' : 'Crafting Your Medical Diet',
          'subtitle': isDone
              ? 'Doctor-approved recipes and kitchen prep instructions are live.'
              : '$_cleanDoctorName is formulating your recipes, macros, and chef cooking rules.',
          'badge': badge,
          'badgeColor': badgeColor,
          'badgeBg': badgeBg,
          'icon': Icons.chat_bubble_outline_rounded,
          'cta': 'Chat with Doctor',
          'route': AppRoutes.dietitianChat,
          'showUpload': false,
        };

      case 4:
      default:
        String badge = isCurrent ? 'Step 4 • Active' : (isDone ? 'Step 4 • Completed' : 'Step 4 • Upcoming');
        Color badgeColor = isCurrent ? const Color(0xFF059669) : AppColors.slate600;
        Color badgeBg = isCurrent ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9);

        return {
          'title': 'Cook Prescribed Meals',
          'subtitle': isCurrent
              ? 'Doctor-prescribed recipes are active. Book your executive chef with 0 visit fee.'
              : 'Certified executive chefs prepare tailored meals at home with fresh produce and zero cleanup.',
          'badge': badge,
          'badgeColor': badgeColor,
          'badgeBg': badgeBg,
          'icon': Icons.soup_kitchen_rounded,
          'cta': 'Book Chef for Diet Plan',
          'route': AppRoutes.bookChefAssigned,
          'showUpload': false,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentStage == HealthPassStage.noPass) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stepData = _getStepData(_displayedStep);
    final isInspectingOther = _inspectedStep != null && _inspectedStep != _activeStepIndex;

    const stepTitles = ['Kickoff', 'Consult', 'Diet Plan', 'Chef'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Header Bar: Clinical Badge, Member Label & Progress Pill ───
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'CLINICAL JOURNEY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (widget.memberName != null && widget.memberName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${widget.memberName}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Step $_activeStepIndex/4',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ─── 2. Segmented Milestone Bar (Unbreakable, 100% Responsive) ───
          Row(
            children: List.generate(4, (index) {
              final stepNum = index + 1;
              final isDone = _activeStepIndex > stepNum;
              final isCurrent = _activeStepIndex == stepNum;
              final isInspected = _displayedStep == stepNum;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 3,
                    right: index == 3 ? 0 : 3,
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _inspectedStep = (_inspectedStep == stepNum) ? null : stepNum;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segment bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: isInspected ? 5 : 4,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.primary
                                : (isCurrent
                                    ? AppColors.primaryDark
                                    : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0))),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Step label
                        Row(
                          children: [
                            if (isDone) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 10,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Expanded(
                              child: Text(
                                stepTitles[index],
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: (isCurrent || isInspected)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isInspected
                                      ? AppColors.primary
                                      : (isCurrent
                                          ? (isDark ? Colors.white : AppColors.slate900)
                                          : (isDone
                                              ? AppColors.primary
                                              : AppColors.slate400)),
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
              );
            }),
          ),

          const SizedBox(height: 12),

          // ─── 3. Clean, Glanceable Milestone Card (Minimal Text) ───
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status pill + Reset link
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: stepData['badgeBg'] as Color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stepData['badge'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: stepData['badgeColor'] as Color,
                        ),
                      ),
                    ),
                    if (isInspectingOther) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _inspectedStep = null;
                          });
                        },
                        child: const Text(
                          'Reset to active step',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Punchy Title
                Text(
                  stepData['title'] as String,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // 1-line Subtitle
                Text(
                  stepData['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Actions: Primary CTA + Optional Compact Upload Button
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: Icon(stepData['icon'] as IconData, size: 14),
                          label: Text(
                            stepData['cta'] as String,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (widget.onPrimaryAction != null && !isInspectingOther) {
                              widget.onPrimaryAction!();
                            } else if (stepData['route'] != null) {
                              Navigator.pushNamed(context, stepData['route'] as String);
                            }
                          },
                        ),
                      ),
                    ),
                    if (stepData['showUpload'] == true) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: const Text(
                            'Upload Labs',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (widget.onUploadDocuments != null) {
                              widget.onUploadDocuments!();
                            } else {
                              Navigator.pushNamed(context, AppRoutes.healthDocuments);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
