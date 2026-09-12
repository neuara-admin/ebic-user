import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import 'ebic_avatar.dart';

class HouseholdMemberOption {
  final String id;
  final String name;
  final String relationship;
  final bool isAccountOwner;
  final bool hasActiveHealthPass;

  const HouseholdMemberOption({
    required this.id,
    required this.name,
    required this.relationship,
    this.isAccountOwner = false,
    this.hasActiveHealthPass = false,
  });
}

/// Horizontal selector to switch between Account Owner and Covered Household Members.
/// Adheres to Section 3.3 and Section 6.2.
class EBICMemberSelector extends StatelessWidget {
  final List<HouseholdMemberOption> members;
  final String? selectedMemberId;
  final ValueChanged<HouseholdMemberOption> onMemberSelected;

  const EBICMemberSelector({
    super.key,
    required this.members,
    required this.selectedMemberId,
    required this.onMemberSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final member = members[index];
          final isSelected = member.id == selectedMemberId;

          return InkWell(
            borderRadius: DesignTokens.borderRadiusMD,
            onTap: () => onMemberSelected(member),
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : (isDark ? AppColors.slate800 : Colors.white),
                borderRadius: DesignTokens.borderRadiusMD,
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.slate700 : AppColors.slate200),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      EBICAvatar(name: member.name, radius: 18),
                      if (member.hasActiveHealthPass)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star, size: 8, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white : AppColors.slate900),
                        ),
                      ),
                      Text(
                        member.isAccountOwner ? 'Account Owner' : member.relationship,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColors.primary : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
