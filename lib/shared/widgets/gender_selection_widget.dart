import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A modern, tactile, and responsive Gender Selection component
/// presenting cards with tailored icons, radio badges, and smooth active feedback.
class GenderSelectionWidget extends StatelessWidget {
  final String selectedGender;
  final ValueChanged<String> onGenderChanged;
  final List<String> genders;
  final String label;

  const GenderSelectionWidget({
    super.key,
    required this.selectedGender,
    required this.onGenderChanged,
    this.genders = const ['Male', 'Female', 'Other', 'Prefer not to say'],
    this.label = 'Gender / Biological Sex',
  });

  IconData _getGenderIcon(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Icons.male_rounded;
      case 'female':
        return Icons.female_rounded;
      case 'other':
        return Icons.transgender_rounded;
      case 'prefer not to say':
      default:
        return Icons.privacy_tip_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with label and current active badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wc_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            if (selectedGender.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getGenderIcon(selectedGender),
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedGender,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 2x2 Responsive Card Grid
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    final pair1 = genders.take(2).toList();
    final pair2 = genders.skip(2).take(2).toList();

    return Column(
      children: [
        Row(
          children: [
            if (pair1.isNotEmpty)
              Expanded(child: _buildGenderCard(pair1[0])),
            if (pair1.length > 1) ...[
              const SizedBox(width: 10),
              Expanded(child: _buildGenderCard(pair1[1])),
            ],
          ],
        ),
        if (pair2.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildGenderCard(pair2[0])),
              if (pair2.length > 1) ...[
                const SizedBox(width: 10),
                Expanded(child: _buildGenderCard(pair2[1])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGenderCard(String gender) {
    final isSelected = selectedGender.toLowerCase() == gender.toLowerCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onGenderChanged(gender),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.slate200,
              width: isSelected ? 1.8 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Circular Icon Container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getGenderIcon(gender),
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.slate600,
                ),
              ),
              const SizedBox(width: 8),

              // Title Label
              Expanded(
                child: Text(
                  gender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF065F46) : AppColors.slate700,
                  ),
                ),
              ),

              // Selection Radio Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.slate300,
                    width: isSelected ? 1.8 : 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
