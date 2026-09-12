import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Form field time picker button for EBIC User App.
/// Part of the core component suite (Section 6.2).
class EBICTimePicker extends StatelessWidget {
  final String? label;
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay> onTimeSelected;
  final String hint;

  const EBICTimePicker({
    super.key,
    this.label,
    required this.selectedTime,
    required this.onTimeSelected,
    this.hint = 'Select Time',
  });

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.slate900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onTimeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormatted = selectedTime != null ? selectedTime!.format(context) : hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate200 : AppColors.slate800,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXS),
        ],
        InkWell(
          borderRadius: DesignTokens.borderRadiusMD,
          onTap: () => _pickTime(context),
          child: Container(
            height: DesignTokens.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: DesignTokens.borderRadiusMD,
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    timeFormatted,
                    style: TextStyle(
                      fontSize: 15,
                      color: selectedTime != null
                          ? (isDark ? Colors.white : AppColors.slate900)
                          : AppColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
