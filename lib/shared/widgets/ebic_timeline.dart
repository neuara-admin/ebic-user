import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TimelineStep {
  final String title;
  final String? subtitle;
  final String? time;
  final bool isCompleted;
  final bool isCurrent;

  const TimelineStep({
    required this.title,
    this.subtitle,
    this.time,
    this.isCompleted = false,
    this.isCurrent = false,
  });
}

/// Step-by-step progress timeline for visit and order tracking.
/// Part of the core component suite (Section 6.2).
class EBICTimeline extends StatelessWidget {
  final List<TimelineStep> steps;

  const EBICTimeline({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        Color dotColor;
        Widget dotChild;

        if (step.isCompleted) {
          dotColor = AppColors.primary;
          dotChild = const Icon(Icons.check, size: 12, color: Colors.white);
        } else if (step.isCurrent) {
          dotColor = AppColors.accent;
          dotChild = Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );
        } else {
          dotColor = AppColors.slate300;
          dotChild = const SizedBox();
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: dotChild,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: step.isCompleted ? AppColors.primary : AppColors.slate200,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: step.isCurrent || step.isCompleted
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: step.isCurrent
                                    ? AppColors.primary
                                    : (step.isCompleted ? AppColors.slate900 : AppColors.slate500),
                              ),
                            ),
                          ),
                          if (step.time != null)
                            Text(
                              step.time!,
                              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                            ),
                        ],
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          step.subtitle!,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
