import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/loading_view.dart';

class AssignedMealScreen extends StatefulWidget {
  const AssignedMealScreen({super.key});

  @override
  State<AssignedMealScreen> createState() => _AssignedMealScreenState();
}

class _AssignedMealScreenState extends State<AssignedMealScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;

  List<HouseholdMemberModel> _members = [];
  HouseholdMemberModel? _selectedMember;
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;

  String _selectedOccasion = 'LUNCH'; // BREAKFAST, LUNCH, DINNER
  Map<String, dynamic>? _assignedDietPlan;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Household members
      final membersRes = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (membersRes.success && membersRes.data != null) {
        _members = membersRes.data!
            .map((m) => HouseholdMemberModel.fromJson(m as Map<String, dynamic>))
            .toList();
        if (_members.isNotEmpty) {
          _selectedMember = _members.first;
        }
      }

      // 2. Saved addresses
      final addrRes = await _api.get<List<dynamic>>(ApiEndpoints.addresses);
      if (addrRes.success && addrRes.data != null) {
        _addresses = addrRes.data!
            .map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
            .toList();
        if (_addresses.isNotEmpty) {
          _selectedAddress = _addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => _addresses.first,
          );
        }
      }

      // 3. Today's diet plan
      if (_selectedMember != null) {
        await _fetchDietPlanForMember(_selectedMember!.id);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDietPlanForMember(String memberId) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.todayDietPlan,
      queryParameters: {'memberId': memberId},
    );
    if (res.success && res.data != null) {
      _assignedDietPlan = res.data;
    }
  }

  void _proceedToQuote() {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a delivery address.')),
      );
      return;
    }

    // Pass configuration to cooking time & quote calculation
    Navigator.pushNamed(
      context,
      AppRoutes.bookChefQuote,
      arguments: {
        'mode': 'ASSIGNED_MEAL',
        'memberId': _selectedMember?.id,
        'memberName': _selectedMember?.name ?? 'Self',
        'addressId': _selectedAddress?.id,
        'addressLine': _selectedAddress?.line1,
        'occasion': _selectedOccasion,
        'bookingOption': _selectedOccasion == 'BREAKFAST'
            ? 'B'
            : _selectedOccasion == 'LUNCH'
                ? 'L'
                : 'D',
        'dishes': [
          {'dishId': 'herb-chicken-dish-id', 'name': 'Herb Roasted Chicken', 'servings': 1, 'baseCookTimeMin': 25},
          {'dishId': 'brown-rice-dish-id', 'name': 'Brown Basmati Rice', 'servings': 1, 'baseCookTimeMin': 15},
          {'dishId': 'broccoli-dish-id', 'name': 'Steamed Garlic Broccoli', 'servings': 1, 'baseCookTimeMin': 10},
        ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView(message: 'Loading assigned diet meal...'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Meal'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 1: Select Household Member (Section 30)
              const Text('1. Select Covered Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildMemberSelector(),
              const SizedBox(height: 24),

              // Step 2: Meal Occasion
              const Text('2. Select Meal Occasion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildOccasionSelector(),
              const SizedBox(height: 24),

              // Step 3: Assigned Meal Review (Section 30)
              const Text('3. Review Dietitian Meal Specification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Dishes are locked to your approved clinical nutrition plan.',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildAssignedMealCard(),
              const SizedBox(height: 24),

              // Step 4: Address selection
              const Text('4. Service Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildAddressSelector(),
              const SizedBox(height: 32),

              EbicButton(
                label: 'Calculate Cooking Time & Quote',
                icon: Icons.calculate_outlined,
                onPressed: _proceedToQuote,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSelector() {
    if (_members.isEmpty) {
      return EbicCard(
        child: const Text('No household members found. Self will be used.'),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final member = _members[index];
          final isSelected = _selectedMember?.id == member.id;

          return ChoiceChip(
            label: Text(member.name),
            selected: isSelected,
            selectedColor: AppColors.primarySubtle,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.slate200,
            ),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.slate700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedMember = member);
                _fetchDietPlanForMember(member.id);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildOccasionSelector() {
    final occasions = ['BREAKFAST', 'LUNCH', 'DINNER'];

    return Row(
      children: occasions.map((occ) {
        final isSelected = _selectedOccasion == occ;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedOccasion = occ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySubtle : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.slate200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    occ,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.slate700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssignedMealCard() {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _assignedDietPlan?['planName']?.toString() ?? 'Clinical Diet Plan V2',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                '520 kcal',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDishItem('Herb Roasted Chicken Breast', '150g • 34g Protein', '25 mins'),
          const SizedBox(height: 10),
          _buildDishItem('Brown Basmati Rice', '1 cup • 45g Carbs', '15 mins'),
          const SizedBox(height: 10),
          _buildDishItem('Steamed Garlic Broccoli', '100g • High Fibre', '10 mins'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Health Pass benefit eligible: 1 Chef Visit free allowance available.',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishItem(String name, String macros, String cookTime) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(macros, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
          ],
        ),
        Text(cookTime, style: const TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildAddressSelector() {
    if (_addresses.isEmpty) {
      return EbicCard(
        onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
        child: Row(
          children: const [
            Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('No saved address. Tap to add address.', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return EbicCard(
      child: Row(
        children: [
          Icon(_selectedAddress?.kitchenIcon ?? Icons.countertops_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAddress?.kitchenLabelDisplayName ?? 'Home Kitchen',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _selectedAddress?.line1 ?? '',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addresses).then((_) => _loadInitialData());
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
