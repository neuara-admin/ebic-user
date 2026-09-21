import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum HealthPassStage {
  noPass,
  kickoffNeeded,
  consultationScheduled,
  consultationInProgress,
  mealCurationInProgress,
  mealsAssigned,
  subscriptionActive,
}

class HealthJourneyStepper extends StatelessWidget {
  final HealthPassStage currentStage;
  final String? dietitianName;
  final VoidCallback? onPrimaryAction;

  const HealthJourneyStepper({
    super.key,
    required this.currentStage,
    this.dietitianName,
    this.onPrimaryAction,
  });

  int get _activeStepIndex {
    switch (currentStage) {
      case HealthPassStage.noPass:
        return 0;
      case HealthPassStage.kickoffNeeded:
        return 1;
      case HealthPassStage.consultationScheduled:
      case HealthPassStage.consultationInProgress:
        return 2;
      case HealthPassStage.mealCurationInProgress:
        return 3;
      case HealthPassStage.mealsAssigned:
      case HealthPassStage.subscriptionActive:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentStage == HealthPassStage.noPass) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = [
      {'title': 'Kickoff', 'icon': Icons.calendar_today_rounded},
      {'title': 'Consultation', 'icon': Icons.video_call_rounded},
      {'title': 'Curating Meals', 'icon': Icons.menu_book_rounded},
      {'title': 'Chef Cooking', 'icon': Icons.soup_kitchen_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'HEALTH PASS CLINICAL JOURNEY',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Step $_activeStepIndex of 4',
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

          // Stepper Circles & Lines
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final lineStep = (i ~/ 2) + 1;
                final isDone = _activeStepIndex > lineStep;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    color: isDone ? AppColors.primary : (isDark ? AppColors.slate700 : AppColors.slate300),
                  ),
                );
              }

              final stepIdx = i ~/ 2; // 0, 1, 2, 3
              final stepNum = stepIdx + 1;
              final isDone = _activeStepIndex > stepNum;
              final isCurrent = _activeStepIndex == stepNum;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primary
                          : isCurrent
                              ? AppColors.primaryDark
                              : (isDark ? AppColors.slate800 : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : isDone
                                ? AppColors.primary
                                : (isDark ? AppColors.slate700 : AppColors.slate300),
                        width: isCurrent ? 2 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Icon(
                              steps[stepIdx]['icon'] as IconData,
                              size: 13,
                              color: isCurrent ? Colors.white : AppColors.slate400,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[stepIdx]['title'] as String,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent
                          ? (isDark ? Colors.white : AppColors.slate900)
                          : AppColors.slate500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
