import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Standard dropdown selection field for EBIC User App.
/// Part of the core component suite (Section 6.2).
class EBICDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final Widget? prefixIcon;

  const EBICDropdown({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: isDark ? AppColors.slate800 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMD,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
