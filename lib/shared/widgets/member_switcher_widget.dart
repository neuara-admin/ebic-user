import 'package:flutter/material.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../models/household_member_model.dart';
import 'ebic_card.dart';

/// Module 3 — Section 35: Sleek Member Switcher Bar
class MemberSwitcherBar extends StatelessWidget {
  final VoidCallback? onMemberChanged;

  const MemberSwitcherBar({super.key, this.onMemberChanged});

  @override
  Widget build(BuildContext context) {
    final memberContext = MemberContext();

    return AnimatedBuilder(
      animation: memberContext,
      builder: (context, _) {
        final current = memberContext.selectedMember;

        return EbicCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => showMemberSwitcherSheet(context, onSelected: onMemberChanged),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    current?.initials ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Member Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ACTIVE HOUSEHOLD MEMBER',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            current?.name ?? 'Select Member',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (current != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              current.relationship.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Switch Action Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Switch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.slate700),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Module 3 — Section 35: Member Switcher Modal Bottom Sheet
Future<HouseholdMemberModel?> showMemberSwitcherSheet(
  BuildContext context, {
  VoidCallback? onSelected,
}) async {
  final memberContext = MemberContext();

  return showModalBottomSheet<HouseholdMemberModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: AnimatedBuilder(
          animation: memberContext,
          builder: (ctx, _) {
            final members = memberContext.members;
            final selectedId = memberContext.selectedMemberId;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Switch Active Member',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Health profile, diet plans & meal bookings apply to selected member',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.group_outlined, size: 40, color: AppColors.slate400),
                          const SizedBox(height: 8),
                          const Text(
                            'No household members found.',
                            style: TextStyle(color: AppColors.slate600, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(context, AppRoutes.household);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Family Member'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final m = members[idx];
                      final isSelected = m.id == selectedId;

                      return InkWell(
                        onTap: () async {
                          await memberContext.selectMember(m.id);
                          if (ctx.mounted) {
                            Navigator.pop(ctx, m);
                          }
                          onSelected?.call();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySubtle.withOpacity(0.5) : AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.slate200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.slate200,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    m.initials,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.slate700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.slate900,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary : AppColors.slate200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            m.relationship.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : AppColors.slate700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m.gender} • ${m.age} yrs • Health Pass: ${m.isHealthPassCovered ? "ACTIVE" : "NOT COVERED"}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              else
                                const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.slate400, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                // Manage Household shortcut
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.household);
                    },
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Manage Household Members'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
