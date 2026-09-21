import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/household_member_model.dart';
import 'data/datasources/health_remote_datasource.dart';
import 'data/models/health_profile_model.dart';
import 'data/models/health_completion_model.dart';
import 'presentation/widgets/health_completion_card.dart';
import 'presentation/widgets/bmi_meter_widget.dart';
import 'presentation/widgets/provenance_badge.dart';
import 'presentation/screens/health_profile_edit_screen.dart';
import 'presentation/screens/health_goals_screen.dart';
import 'presentation/screens/dietary_preferences_screen.dart';
import 'presentation/screens/allergies_screen.dart';
import 'presentation/screens/lifestyle_screen.dart';
import 'presentation/screens/health_metrics_screen.dart';
import 'presentation/screens/health_data_permissions_screen.dart';
import 'presentation/screens/body_measurements_screen.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final ApiClient _api = ApiClient();
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();

  List<HouseholdMemberModel> _householdMembers = [];
  String? _selectedMemberId;
  HealthProfileModel? _profile;
  HealthCompletionModel? _completion;
  bool _isLoadingMembers = true;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchHouseholdMembers();
  }

  Future<void> _fetchHouseholdMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _householdMembers = list;
            _isLoadingMembers = false;
            if (list.isNotEmpty) {
              _selectedMemberId = list.first.id;
              _loadProfileForMember(list.first.id);
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadProfileForMember(String memberId) async {
    setState(() => _isLoadingProfile = true);
    try {
      final profileFuture = _dataSource.getProfile(memberId);
      final completionFuture = _dataSource.getProfileCompletion(memberId);

      final results = await Future.wait([profileFuture, completionFuture]);

      if (mounted) {
        setState(() {
          _profile = results[0] as HealthProfileModel?;
          _completion = results[1] as HealthCompletionModel?;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _onMemberSelected(String memberId) {
    if (_selectedMemberId == memberId) return;
    setState(() => _selectedMemberId = memberId);
    _loadProfileForMember(memberId);
  }

  Future<void> _openEditScreen() async {
    if (_selectedMemberId == null || _profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthProfileEditScreen(
          memberId: _selectedMemberId!,
          initialProfile: _profile!,
        ),
      ),
    );
    _loadProfileForMember(_selectedMemberId!);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMember = _householdMembers.firstWhere(
      (m) => m.id == _selectedMemberId,
      orElse: () => HouseholdMemberModel(id: '', name: 'Member', relationship: 'SELF'),
    );

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Health Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              '${selectedMember.name} • ${selectedMember.relationship}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Profile',
              onPressed: _openEditScreen,
            ),
        ],
      ),
      body: _isLoadingMembers
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (_selectedMemberId != null) {
                  await _loadProfileForMember(_selectedMemberId!);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 91: Household Member Selector
                    if (_householdMembers.isNotEmpty) ...[
                      _buildMemberSelector(),
                      const SizedBox(height: 16),
                    ],

                    if (_isLoadingProfile)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_profile == null)
                      _buildEmptyState()
                    else ...[
                      // Section 92: Backend Profile Completion
                      HealthCompletionCard(
                        completion: _completion,
                        onEditPressed: _openEditScreen,
                      ),
                      const SizedBox(height: 16),

                      // Section 93 & 29: Body Measurements & Backend-derived BMI
                      _buildBodyMeasurementsSection(),
                      const SizedBox(height: 16),

                      // Section 94: Health Goals Card
                      _buildGoalsSection(),
                      const SizedBox(height: 16),

                      // Section 95: Dietary Preferences & Allergies Card
                      _buildDietaryAndAllergiesSection(),
                      const SizedBox(height: 16),

                      // Section 96: Lifestyle & Routine Card
                      _buildLifestyleSection(),
                      const SizedBox(height: 16),

                      // Section 97: Health Metrics Summary Card
                      _buildMetricsQuickCard(),
                      const SizedBox(height: 16),

                      // Section 98: Privacy & Permissions Card
                      _buildPrivacySection(),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ────────────────────────── Component Builders ──────────────────────────

  Widget _buildMemberSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.slate700,
              ),
            ),
            Text(
              'Independent Profiles',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _householdMembers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final member = _householdMembers[index];
              final isSelected = member.id == _selectedMemberId;

              return ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: isSelected ? AppColors.primaryLight : AppColors.slate200,
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.slate700,
                    ),
                  ),
                ),
                label: Text(member.name),
                selected: isSelected,
                onSelected: (_) => _onMemberSelected(member.id),
                selectedColor: AppColors.primarySubtle,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.slate200,
                  ),
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryDark : AppColors.slate800,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBodyMeasurementsSection() {
    return Column(
      children: [
        BmiMeterWidget(
          bmi: _profile!.bmi,
          heightCm: _profile!.heightCm,
          weightKg: _profile!.currentWeightKg,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BodyMeasurementsScreen(
                        memberId: _selectedMemberId!,
                        profile: _profile!,
                      ),
                    ),
                  );
                  _loadProfileForMember(_selectedMemberId!);
                },
                icon: const Icon(Icons.scale_rounded, size: 16),
                label: const Text('Update Weight / Height'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.slate700,
                  side: const BorderSide(color: AppColors.slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalsSection() {
    final goals = _profile!.goals;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flag_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Health Goals',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthGoalsScreen(memberId: _selectedMemberId!),
                    ),
                  );
                  _loadProfileForMember(_selectedMemberId!);
                },
                child: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (goals.isEmpty)
            Text(
              _profile!.healthGoalsText != null && _profile!.healthGoalsText!.isNotEmpty
                  ? _profile!.healthGoalsText!
                  : 'No active goals specified. Tap Manage to add goals for your dietitian.',
              style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.3),
            )
          else
            Column(
              children: goals.take(3).map((g) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800),
                        ),
                      ),
                      if (g.targetValue != null)
                        Text(
                          '${g.targetValue} ${g.targetUnit ?? ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDietaryAndAllergiesSection() {
    final restrictions = _profile!.dietaryRestrictions;
    final allergies = _profile!.allergies;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Dietary & Allergies',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DietaryPreferencesScreen(
                        memberId: _selectedMemberId!,
                        profile: _profile!,
                      ),
                    ),
                  );
                  _loadProfileForMember(_selectedMemberId!);
                },
                child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dietary tags chips
          if (restrictions.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: restrictions.map((r) {
                return Chip(
                  label: Text(r.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primarySubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Allergies list with safety badge
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Allergens / Safety Constraints:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AllergiesScreen(memberId: _selectedMemberId!)),
                  );
                  _loadProfileForMember(_selectedMemberId!);
                },
                child: const Text('Safety List →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (allergies.isEmpty)
            const Text(
              'No selected allergens. Dishes will be cooked according to standard guidelines.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allergies.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded, size: 12, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        a.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(width: 4),
                      ProvenanceBadge(source: a.source, isCompact: true),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLifestyleSection() {
    final ls = _profile!.lifestyle;
    final breakfast = ls['typicalBreakfast']?.toString() ?? '8:00 AM';
    final lunch = ls['typicalLunch']?.toString() ?? '1:30 PM';
    final dinner = ls['typicalDinner']?.toString() ?? '8:30 PM';
    final sleep = ls['typicalSleep']?.toString() ?? '11:00 PM';
    final wake = ls['typicalWake']?.toString() ?? '7:00 AM';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time_rounded, color: Color(0xFF7E22CE), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lifestyle & Routine',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LifestyleScreen(
                        memberId: _selectedMemberId!,
                        profile: _profile!,
                      ),
                    ),
                  );
                  _loadProfileForMember(_selectedMemberId!);
                },
                child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildRoutinePill('Activity', _profile!.formattedActivityLevel, Icons.directions_run_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoutinePill('Sleep Window', '$sleep - $wake', Icons.bedtime_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRoutinePill('Meal Times', 'B: $breakfast • L: $lunch • D: $dinner', Icons.restaurant_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinePill(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsQuickCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Health Metrics',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthMetricsScreen(memberId: _selectedMemberId!),
                    ),
                  );
                },
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Track time-series trends for weight, steps, sleep, and hydration.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Data Privacy & Permissions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You decide which health metrics your assigned dietitian and cooking chefs can access.',
            style: TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HealthDataPermissionsScreen(memberId: _selectedMemberId!),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: AppColors.slate300),
              ),
              child: const Text('Manage Access Permissions', style: TextStyle(color: AppColors.slate800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.health_and_safety_outlined, size: 56, color: AppColors.slate400),
            const SizedBox(height: 16),
            const Text(
              'No Health Profile Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start your health profile to enable dietitian consultations and personalized diet plans.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openEditScreen,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Initialize Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
