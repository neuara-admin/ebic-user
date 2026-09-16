import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/health_completion_model.dart';

class HealthCompletionCard extends StatelessWidget {
  final HealthCompletionModel? completion;
  final VoidCallback onEditPressed;

  const HealthCompletionCard({
    super.key,
    required this.completion,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = completion?.completionPercentage ?? 0;
    final isComplete = percentage >= 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete
              ? [const Color(0xFF047857), const Color(0xFF065F46)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: percentage / 100.0,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? AppColors.accentLight : AppColors.emerald400,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isComplete ? 'Profile Complete' : 'Profile Completion',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (isComplete) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppColors.accentLight, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'Your dietitian has comprehensive data for optimal meal personalization.'
                          : 'Complete all sections to help your dietitian design your exact plan.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Sections checklist (Section 92)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildCheckItem('Basic Info', completion?.isSectionComplete('basic') ?? false),
              _buildCheckItem('Body', completion?.isSectionComplete('body') ?? false),
              _buildCheckItem('Goals', completion?.isSectionComplete('goals') ?? false),
              _buildCheckItem('Dietary', completion?.isSectionComplete('dietary') ?? false),
              _buildCheckItem('Allergies', completion?.isSectionComplete('allergies') ?? false),
              _buildCheckItem('Lifestyle', completion?.isSectionComplete('lifestyle') ?? false),
              _buildCheckItem('Metrics', completion?.isSectionComplete('metrics') ?? false),
            ],
          ),

          if (!isComplete) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEditPressed,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Complete Missing Sections'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: isDone ? AppColors.emerald400 : Colors.white54,
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
            color: isDone ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }
}
