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

  // Module 12: Health Pass Chef Booking Context & State
  Map<String, dynamic>? _hpEligibility;
  Map<String, dynamic>? _hpEntitlements;
  bool _isHpChecking = false;

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

      // 3. Today's diet plan & Health Pass Chef Booking verification
      if (_selectedMember != null) {
        await Future.wait([
          _fetchDietPlanForMember(_selectedMember!.id),
          _checkHealthPassEligibility(_selectedMember!.id),
        ]);
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
    } else {
      _assignedDietPlan = null;
    }
  }

  Future<void> _checkHealthPassEligibility(String memberId) async {
    setState(() => _isHpChecking = true);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final mealCode = _selectedOccasion == 'BREAKFAST'
        ? 'B'
        : _selectedOccasion == 'LUNCH'
            ? 'L'
            : 'D';

    try {
      final eligRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.healthPassChefEligibility,
        body: {
          'member_id': memberId,
          'service_date': todayStr,
          'meal_type': mealCode,
        },
      );
      if (eligRes.success && eligRes.data != null) {
        _hpEligibility = eligRes.data;
      } else {
        _hpEligibility = null;
      }

      final entRes = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.healthPassChefEntitlements,
        queryParameters: {'member_id': memberId},
      );
      if (entRes.success && entRes.data != null) {
        _hpEntitlements = entRes.data;
      } else {
        _hpEntitlements = null;
      }
    } catch (_) {
      _hpEligibility = null;
      _hpEntitlements = null;
    }

    if (mounted) {
      setState(() => _isHpChecking = false);
    }
  }

  void _proceedToQuote() {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a delivery address.')),
      );
      return;
    }

    final mealCode = _selectedOccasion == 'BREAKFAST'
        ? 'B'
        : _selectedOccasion == 'LUNCH'
            ? 'L'
            : 'D';

    // Pass configuration to cooking time & quote calculation (Section 54)
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
        'bookingOption': mealCode,
        'serviceDate': DateTime.now().toIso8601String().split('T')[0],
        'hpEligibility': _hpEligibility,
        'hpEntitlements': _hpEntitlements,
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
                _checkHealthPassEligibility(member.id);
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
              onTap: () {
                setState(() => _selectedOccasion = occ);
                if (_selectedMember != null) {
                  _checkHealthPassEligibility(_selectedMember!.id);
                }
              },
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
    // Section 64 Empty State: No assigned meal
    if (_assignedDietPlan == null) {
      return EbicCard(
        border: Border.all(color: AppColors.slate200),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu_outlined, size: 44, color: AppColors.slate400),
              const SizedBox(height: 12),
              const Text(
                'No meal has been assigned for this meal/date.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can choose items directly from our healthy kitchen catalogue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.bookChefCatalogue);
                },
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Browse Meals From Catalogue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Health Pass benefit entitlement banner calculation
    final isEligible = _hpEligibility?['eligible'] == true;
    final hasEntitlement = _hpEligibility?['entitlement_available'] == true;
    final availableVisits = (_hpEntitlements?['entitlements'] as List<dynamic>?)
            ?.firstWhere((e) => e['type'] == 'CHEF_VISIT', orElse: () => null)?['available'] ??
        (_hpEligibility?['entitlement_available'] == true ? 1 : 0);

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

          // Section 63 & 64: Benefit and Empty State Indicators
          if (_isHpChecking)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Checking Health Pass entitlement...', style: TextStyle(fontSize: 12, color: AppColors.slate600)),
                ],
              ),
            )
          else if (isEligible && hasEntitlement)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Health Pass benefit eligible: $availableVisits Chef Visit${availableVisits == 1 ? "" : "s"} remaining this period.',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (isEligible && !hasEntitlement)
            // Section 64 Empty State: No entitlement
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your included chef visits are currently unavailable. Paid booking available.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            // Section 64 Empty State: Health Pass expired / inactive
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.card_membership_outlined, color: AppColors.slate500, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Health Pass is not active for this service date. Standard visit rates apply.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate600),
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
