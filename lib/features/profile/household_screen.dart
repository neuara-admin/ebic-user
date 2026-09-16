import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/bmi_health_widget.dart';
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

          final coveredCount = members.where((m) => m.isHealthPassCovered).length;

          return RefreshIndicator(
            onRefresh: _fetchMembers,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: members.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == 0) {
                  return _buildHouseholdHeader(members.length, coveredCount);
                }
                final m = members[idx - 1];
                final isSelected = m.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildMemberCard(m, isSelected),
                );
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

  Widget _buildHouseholdHeader(int totalMembers, int coveredMembers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Health Hub',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Centralized management for profiles & diet plans',
                      style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildHeaderStatPill(
                icon: Icons.people_outline_rounded,
                label: '$totalMembers ${totalMembers == 1 ? "Member" : "Members"}',
              ),
              const SizedBox(width: 8),
              _buildHeaderStatPill(
                icon: Icons.shield_outlined,
                label: '$coveredMembers Health Pass Covered',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatPill({required IconData icon, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(HouseholdMemberModel m, bool isSelected) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Member Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                    ? Image.network(
                        AppConfig.resolveMediaUrl(m.avatarUrl) ?? m.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildInitials(m, isSelected),
                      )
                    : _buildInitials(m, isSelected),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: m.isSelf ? AppColors.emerald50 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: m.isSelf
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : AppColors.slate300,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            m.isSelf ? 'SELF (OWNER)' : m.relationship.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: m.isSelf ? AppColors.primaryDark : AppColors.slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${m.gender} • ${m.age} yrs${m.dateOfBirth != null ? ' (DOB: ${m.formattedDob})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.slate500, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate600),
                tooltip: 'Edit Member & Health Vitals',
                onPressed: () => _navigateToAddOrEditMember(m),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              if (!m.isSelf) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                  tooltip: 'Remove Member',
                  onPressed: () => _removeMember(m),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // 2. Health Vitals & BMI Summary (100% Overflow-Free)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDF4) : AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.slate200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Height & Weight Side-by-Side with separate Expanded columns
                Row(
                  children: [
                    // Height
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.height_rounded, size: 14, color: AppColors.slate600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HEIGHT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  m.heightDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      height: 26,
                      width: 1,
                      color: AppColors.slate200,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),

                    // Weight
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.scale_rounded, size: 14, color: AppColors.slate600),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'WEIGHT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  m.weightDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // BMI Row (comfortably positioned below with zero horizontal squeeze)
                if (m.bmi != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: AppColors.slate200),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          const Text(
                            'BMI:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.slate600),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${m.bmiFormatted} kg/m²',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate900),
                          ),
                        ],
                      ),
                      BmiHealthWidget.badge(bmi: m.bmi),
                    ],
                  ),
                ] else if (m.heightCm == null || m.weightKg == null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _navigateToAddOrEditMember(m),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Add Vitals to Calculate BMI',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Dietary Preferences, Allergies & Medical Conditions Chips
          if (m.dietaryPreferences.isNotEmpty || m.allergies.isNotEmpty || m.medicalConditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...m.dietaryPreferences.map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.eco_rounded, size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            d,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    )),
                ...m.allergies.map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 11, color: Color(0xFFBE123C)),
                          const SizedBox(width: 4),
                          Text(
                            a,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                        ],
                      ),
                    )),
                ...m.medicalConditions.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.medical_services_outlined, size: 11, color: Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            c,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ],

          // 4. Clinical Notes snippet
          if (m.clinicalNotes != null && m.clinicalNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.slate100.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.slate500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.clinicalNotes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 20),

          // 5. Health Pass Status & Active Member Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: m.isHealthPassCovered ? AppColors.primary : AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m.isHealthPassCovered ? 'Health Pass Covered' : 'Standard Coverage',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: m.isHealthPassCovered ? AppColors.primaryDark : AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Active switch toggle/pill
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE MEMBER',
                        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 10),
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
                      border: Border.all(color: AppColors.slate200),
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

  Widget _buildInitials(HouseholdMemberModel m, bool isSelected) {
    return Center(
      child: Text(
        m.initials,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isSelected ? Colors.white : AppColors.primaryDark,
        ),
      ),
    );
  }
}
