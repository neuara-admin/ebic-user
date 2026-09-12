import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_card.dart';

/// Module 3 — Sections 25–28: Household & Family Members Screen
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final ApiClient _api = ApiClient();
  final MemberContext _memberContext = MemberContext();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMembers());
  }

  Future<void> _fetchMembers() async {
    await _memberContext.loadMembers(forceRefresh: true);
  }

  Future<void> _navigateToAddOrEditMember([HouseholdMemberModel? member]) async {
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.memberForm,
      arguments: member,
    );
    if (updated == true && mounted) {
      _fetchMembers();
    }
  }

  Future<void> _removeMember(HouseholdMemberModel member) async {
    if (member.isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account owner profile cannot be removed from household.')),
      );
      return;
    }

    // Section 25: Confirmation showing consequences
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Household Member?'),
        content: Text(
          'Are you sure you want to remove ${member.name}? Historical diet plans and unlinked consultations will be disconnected from active selection.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _api.delete<Map<String, dynamic>>(
        ApiEndpoints.householdMemberDetail(member.id),
      );

      if (res.success) {
        await _fetchMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.name} removed from household.')),
          );
        }
      } else {
        // Section 27: Member Removal Conflict handling
        final msg = res.message ?? 'Removal failed';
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Cannot Remove Member', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Text(
                msg.contains('active services')
                    ? 'This member currently has active services (such as a Health Pass or active chef visit) and cannot be removed.'
                    : msg,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Household & Members'),
      ),
      body: AnimatedBuilder(
        animation: _memberContext,
        builder: (context, _) {
          final members = _memberContext.members;
          final isLoading = _memberContext.isLoading;
          final selectedId = _memberContext.selectedMemberId;

          if (isLoading && members.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Section 79: Empty States
          if (members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.slate100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No household members yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add a household member to manage their EBIC services and health profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.slate500, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToAddOrEditMember(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Member'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _fetchMembers,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, idx) {
                final m = members[idx];
                final isSelected = m.id == selectedId;
                return _buildMemberCard(m, isSelected);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Add Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _navigateToAddOrEditMember(),
      ),
    );
  }

  Widget _buildMemberCard(HouseholdMemberModel m, bool isSelected) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    m.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.white : AppColors.primaryDark,
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
                        Flexible(
                          child: Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySubtle : AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            m.relationship.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primaryDark : AppColors.slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${m.gender} • ${m.age} years old',
                      style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Edit Member Button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate600),
                tooltip: 'Edit Member',
                onPressed: () => _navigateToAddOrEditMember(m),
              ),
              // Delete Member (only for non-self)
              if (!m.isSelf)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.slate400, size: 20),
                  tooltip: 'Remove Member',
                  onPressed: () => _removeMember(m),
                ),
            ],
          ),
          const Divider(height: 20),
          // Health Pass Status & Active Member Selector Row (Section 23 & 28)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: m.isHealthPassCovered ? AppColors.primary : AppColors.slate400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    m.isHealthPassCovered ? 'Health Pass Covered' : 'Standard Coverage',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: m.isHealthPassCovered ? AppColors.primaryDark : AppColors.slate600,
                    ),
                  ),
                ],
              ),
              // Active switch toggle/pill
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emerald700.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, size: 12, color: AppColors.emerald700),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE MEMBER',
                        style: TextStyle(color: AppColors.emerald700, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () => _memberContext.selectMember(m.id),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Select as Active',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
