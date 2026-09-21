import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/models/address_model.dart';
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

  // Multi-Member State
  List<HouseholdMemberModel> _members = [];
  final Set<String> _selectedMemberIds = {};

  // Multi-Occasion State
  // Values: 'BREAKFAST', 'LUNCH', 'DINNER', 'BREAKFAST_LUNCH', 'LUNCH_DINNER', 'ALL_DAY'
  String _selectedOccasion = 'LUNCH';

  // Addresses State
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  bool _isLoadingAddresses = false;

  // Per-member diet plan map: memberId -> raw plan response
  final Map<String, Map<String, dynamic>> _memberDietPlans = {};
  bool _isLoadingPlans = false;

  // Selected dishes state: key is "${memberId}_${dishId}"
  final Map<String, bool> _selectedDishes = {};
  final Map<String, int> _dishServings = {};

  // Health Pass context
  Map<String, dynamic>? _hpEligibility;
  Map<String, dynamic>? _hpEntitlements;
  bool _isHpChecking = false;

  // Curated fallback dishes in case a member has no diet plan assigned yet
  final List<Map<String, dynamic>> _fallbackDishes = [
    {
      'dishId': 'dish-grilled-chicken',
      'name': 'Herb Grilled Chicken Breast',
      'portion': '150g • 34g Protein',
      'cookTimeMin': 25,
      'calories': 285,
      'proteinG': 34,
      'carbsG': 2,
      'fatG': 6,
      'tags': ['High Protein', 'Gluten-Free'],
      'occasion': 'LUNCH',
    },
    {
      'dishId': 'dish-lentil-veg',
      'name': 'Slow-Cooked Lentil & Veg Bowl',
      'portion': '200g • High Fibre',
      'cookTimeMin': 20,
      'calories': 240,
      'proteinG': 14,
      'carbsG': 36,
      'fatG': 3,
      'tags': ['Vegetarian', 'High Fibre'],
      'occasion': 'LUNCH',
    },
    {
      'dishId': 'dish-balanced-thali',
      'name': 'Balanced Home Thali (Paneer & Rice)',
      'portion': 'Paneer + Basmati Rice',
      'cookTimeMin': 35,
      'calories': 480,
      'proteinG': 22,
      'carbsG': 58,
      'fatG': 14,
      'tags': ['Vegetarian', 'Balanced'],
      'occasion': 'DINNER',
    },
    {
      'dishId': 'dish-scrambled-eggs',
      'name': 'Herbed Egg White Scramble & Toast',
      'portion': '3 Eggs • 20g Protein',
      'cookTimeMin': 15,
      'calories': 220,
      'proteinG': 20,
      'carbsG': 18,
      'fatG': 5,
      'tags': ['High Protein', 'Breakfast'],
      'occasion': 'BREAKFAST',
    },
  ];

  static const List<Map<String, dynamic>> _occasionOptions = [
    {
      'id': 'BREAKFAST',
      'code': 'B',
      'label': 'Breakfast',
      'time': '7:00 AM – 10:00 AM',
      'icon': Icons.wb_twilight_rounded,
      'color': Color(0xFFD97706),
    },
    {
      'id': 'LUNCH',
      'code': 'L',
      'label': 'Lunch',
      'time': '12:00 PM – 3:00 PM',
      'icon': Icons.wb_sunny_rounded,
      'color': Color(0xFF0F766E),
    },
    {
      'id': 'DINNER',
      'code': 'D',
      'label': 'Dinner',
      'time': '7:00 PM – 10:00 PM',
      'icon': Icons.nightlight_round,
      'color': Color(0xFF4338CA),
    },
    {
      'id': 'BREAKFAST_LUNCH',
      'code': 'BL',
      'label': 'Breakfast & Lunch',
      'time': 'Morning prep for 2 meals',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFF059669),
      'isCombo': true,
    },
    {
      'id': 'LUNCH_DINNER',
      'code': 'LD',
      'label': 'Lunch & Dinner',
      'time': 'Afternoon prep for 2 meals',
      'icon': Icons.dinner_dining_rounded,
      'color': Color(0xFF0284C7),
      'isCombo': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Household members
      final membersRes = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (membersRes.success && membersRes.data != null) {
        _members = membersRes.data!
            .map((m) => HouseholdMemberModel.fromJson(m as Map<String, dynamic>))
            .toList();
        if (_members.isNotEmpty) {
          // Default: select the primary self member
          final selfMember = _members.firstWhere((m) => m.isSelf, orElse: () => _members.first);
          _selectedMemberIds.add(selfMember.id);
        }
      }

      // 2. Fetch Saved addresses
      await _fetchAddressesInternal();

      // 3. Fetch diet plans for initially selected members
      await _refreshPlansForSelectedMembers();

      // 4. Check Health Pass eligibility for primary member
      if (_selectedMemberIds.isNotEmpty) {
        await _checkHealthPassEligibility(_selectedMemberIds.first);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAddressesInternal() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final addrRes = await _api.get<List<dynamic>>(ApiEndpoints.customerAddresses);
      if (addrRes.success && addrRes.data != null) {
        _addresses = addrRes.data!
            .map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
            .toList();

        if (_addresses.isNotEmpty) {
          if (_selectedAddress == null || !_addresses.any((a) => a.id == _selectedAddress!.id)) {
            _selectedAddress = _addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => _addresses.first,
            );
          }
        } else {
          _selectedAddress = null;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _refreshPlansForSelectedMembers() async {
    setState(() => _isLoadingPlans = true);

    for (final memberId in _selectedMemberIds) {
      if (!_memberDietPlans.containsKey(memberId)) {
        try {
          final res = await _api.get<Map<String, dynamic>>(
            ApiEndpoints.todayDietPlan,
            queryParameters: {'memberId': memberId},
          );
          if (res.success && res.data != null) {
            _memberDietPlans[memberId] = res.data!;
            _autoSelectDishesForPlan(memberId, res.data!);
          }
        } catch (_) {}
      } else {
        _autoSelectDishesForPlan(memberId, _memberDietPlans[memberId]!);
      }
    }

    if (mounted) {
      setState(() => _isLoadingPlans = false);
    }
  }

  void _autoSelectDishesForPlan(String memberId, Map<String, dynamic> plan) {
    final todayMeals = (plan['todayMeals'] as List<dynamic>?) ?? [];
    for (final meal in todayMeals) {
      final occasion = meal['occasion']?.toString().toUpperCase() ?? '';
      if (_isMealMatchingOccasion(occasion)) {
        final dishes = (meal['dishes'] as List<dynamic>?) ?? [];
        for (final d in dishes) {
          final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
          final key = '${memberId}_$dishId';
          if (!_selectedDishes.containsKey(key)) {
            _selectedDishes[key] = true;
            _dishServings[key] = (d['servings'] as num?)?.toInt() ?? 1;
          }
        }
      }
    }
  }

  bool _isMealMatchingOccasion(String mealOccasion) {
    switch (_selectedOccasion) {
      case 'BREAKFAST':
        return mealOccasion.contains('BREAKFAST') || mealOccasion.contains('MORNING');
      case 'LUNCH':
        return mealOccasion.contains('LUNCH') || mealOccasion.contains('MID_DAY');
      case 'DINNER':
        return mealOccasion.contains('DINNER') || mealOccasion.contains('EVENING');
      case 'BREAKFAST_LUNCH':
        return mealOccasion.contains('BREAKFAST') ||
            mealOccasion.contains('LUNCH') ||
            mealOccasion.contains('MORNING');
      case 'LUNCH_DINNER':
        return mealOccasion.contains('LUNCH') ||
            mealOccasion.contains('DINNER') ||
            mealOccasion.contains('EVENING');
      case 'ALL_DAY':
        return true;
      default:
        return true;
    }
  }

  String _getBookingOptionCode() {
    switch (_selectedOccasion) {
      case 'BREAKFAST':
        return 'B';
      case 'LUNCH':
        return 'L';
      case 'DINNER':
        return 'D';
      case 'BREAKFAST_LUNCH':
        return 'BL';
      case 'LUNCH_DINNER':
        return 'LD';
      case 'ALL_DAY':
        return 'BL';
      default:
        return 'L';
    }
  }

  Future<void> _checkHealthPassEligibility(String memberId) async {
    setState(() => _isHpChecking = true);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final mealCode = _getBookingOptionCode();

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

  void _showAddressPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Service Kitchen',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.slate500),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chefs prepare meals in your clean home kitchen.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const Divider(height: 24),
                  if (_isLoadingAddresses)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_addresses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.location_off_outlined, size: 36, color: AppColors.slate400),
                          const SizedBox(height: 10),
                          const Text(
                            'No saved kitchens found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add your delivery kitchen address to proceed with booking.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _addresses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final addr = _addresses[idx];
                          final isSelected = _selectedAddress?.id == addr.id;

                          return InkWell(
                            onTap: () {
                              setState(() => _selectedAddress = addr);
                              Navigator.pop(modalCtx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primarySubtle : AppColors.slate50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.slate200,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    addr.kitchenIcon,
                                    color: isSelected ? AppColors.primary : AppColors.slate600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              addr.kitchenLabelDisplayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isSelected ? AppColors.primaryDark : AppColors.slate900,
                                              ),
                                            ),
                                            if (addr.isDefault) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PRIMARY',
                                                  style: TextStyle(
                                                    color: AppColors.emerald700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          addr.formattedAddress,
                                          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSelected ? AppColors.primary : AppColors.slate400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(modalCtx);
                        final added = await Navigator.pushNamed(context, AppRoutes.addressForm);
                        if (added == true) {
                          await _fetchAddressesInternal();
                        }
                      },
                      icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                      label: const Text(
                        'Add New Kitchen Address',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _collectSelectedDishesForBooking() {
    final List<Map<String, dynamic>> result = [];

    // First collect from assigned diet plans
    for (final memberId in _selectedMemberIds) {
      final plan = _memberDietPlans[memberId];
      if (plan != null) {
        final todayMeals = (plan['todayMeals'] as List<dynamic>?) ?? [];
        for (final meal in todayMeals) {
          final occasion = meal['occasion']?.toString().toUpperCase() ?? '';
          if (_isMealMatchingOccasion(occasion)) {
            final dishes = (meal['dishes'] as List<dynamic>?) ?? [];
            for (final d in dishes) {
              final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
              final key = '${memberId}_$dishId';
              final isChecked = _selectedDishes[key] ?? true;
              if (isChecked) {
                result.add({
                  'dishId': dishId,
                  'name': d['name'] ?? 'Dietitian Assigned Dish',
                  'servings': _dishServings[key] ?? 1,
                  'baseCookTimeMin': 20,
                  'memberId': memberId,
                });
              }
            }
          }
        }
      }
    }

    // If no dishes were added from diet plans (or member has no plan), add selected fallback dishes
    if (result.isEmpty) {
      for (final f in _fallbackDishes) {
        if (_isMealMatchingOccasion(f['occasion'])) {
          result.add({
            'dishId': f['dishId'],
            'name': f['name'],
            'servings': 1,
            'baseCookTimeMin': f['cookTimeMin'],
          });
        }
      }
      // Guarantee at least 1 dish
      if (result.isEmpty && _fallbackDishes.isNotEmpty) {
        result.add({
          'dishId': _fallbackDishes[0]['dishId'],
          'name': _fallbackDishes[0]['name'],
          'servings': 1,
          'baseCookTimeMin': _fallbackDishes[0]['cookTimeMin'],
        });
      }
    }

    return result;
  }

  void _proceedToQuote() {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one household member.')),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a service kitchen address.')),
      );
      return;
    }

    final dishesToCook = _collectSelectedDishesForBooking();
    if (dishesToCook.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one meal dish to prepare.')),
      );
      return;
    }

    final selectedMembers = _members.where((m) => _selectedMemberIds.contains(m.id)).toList();
    final primaryMember = selectedMembers.isNotEmpty ? selectedMembers.first : null;
    final memberNames = selectedMembers.map((m) => m.name).join(', ');
    final bookingOptionCode = _getBookingOptionCode();

    Navigator.pushNamed(
      context,
      AppRoutes.bookChefQuote,
      arguments: {
        'mode': 'ASSIGNED_MEAL',
        'memberIds': _selectedMemberIds.toList(),
        'memberId': primaryMember?.id,
        'memberName': memberNames,
        'addressId': _selectedAddress!.id,
        'addressLine': _selectedAddress!.formattedAddress,
        'occasion': _selectedOccasion,
        'bookingOption': bookingOptionCode,
        'serviceDate': DateTime.now().toIso8601String().split('T')[0],
        'hpEligibility': _hpEligibility,
        'hpEntitlements': _hpEntitlements,
        'dishes': dishesToCook,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(message: 'Loading assigned diet meal & family profiles...'),
      );
    }

    final selectedDishesCount = _collectSelectedDishesForBooking().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Assigned Meal'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.medical_information_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select covered family members and choose meals from their clinical diet plans.',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Step 1: Multiple Household Member Selection
              _buildStepHeader(
                '1',
                'Select Covered Household Members',
                'Choose one or multiple family members participating in this meal.',
              ),
              const SizedBox(height: 12),
              _buildMultiMemberSelector(),
              const SizedBox(height: 24),

              // Step 2: Multi-Occasion Selector
              _buildStepHeader(
                '2',
                'Select Meal Occasion & Time',
                'Choose single occasion or multi-meal cooking (Breakfast & Lunch / Lunch & Dinner).',
              ),
              const SizedBox(height: 12),
              _buildOccasionSelector(),
              const SizedBox(height: 24),

              // Step 3: Assigned Diet Plan Dishes
              _buildStepHeader(
                '3',
                'Select Assigned Meal Dishes',
                'Dishes calibrated to macro targets. Toggle dishes or customize servings.',
              ),
              const SizedBox(height: 12),
              _buildAssignedDishesList(),
              const SizedBox(height: 24),

              // Step 4: Service Address Selection
              _buildStepHeader(
                '4',
                'Service Kitchen Address',
                'Certified chef visits this address to sanitize kitchen and prepare your food.',
              ),
              const SizedBox(height: 12),
              _buildAddressCard(),
              const SizedBox(height: 32),

              // Bottom CTA
              EbicButton(
                label: 'Calculate Cooking Time & Review ($selectedDishesCount Dishes)',
                icon: Icons.calculate_outlined,
                onPressed: _proceedToQuote,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String stepNum, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNum,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiMemberSelector() {
    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200),
        ),
        child: const Text('No household members found. Self will be selected.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedMemberIds.length} of ${_members.length} Selected',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedMemberIds.length == _members.length) {
                    _selectedMemberIds.clear();
                    if (_members.isNotEmpty) _selectedMemberIds.add(_members.first.id);
                  } else {
                    _selectedMemberIds.addAll(_members.map((m) => m.id));
                  }
                });
                _refreshPlansForSelectedMembers();
              },
              child: Text(
                _selectedMemberIds.length == _members.length ? 'Reset to Self' : 'Select All Members',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final member = _members[idx];
              final isSelected = _selectedMemberIds.contains(member.id);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      if (_selectedMemberIds.length > 1) {
                        _selectedMemberIds.remove(member.id);
                      }
                    } else {
                      _selectedMemberIds.add(member.id);
                    }
                  });
                  _refreshPlansForSelectedMembers();
                  _checkHealthPassEligibility(member.id);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySubtle : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.slate200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected ? AppColors.primary : AppColors.slate200,
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.slate700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 6,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.check_circle, size: 12, color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              member.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? AppColors.primaryDark : AppColors.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              member.relationship.toLowerCase(),
                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                            if (member.isCoveredByHealthPass)
                              const Text(
                                'Health Pass',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOccasionSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _occasionOptions.map((occ) {
            final isSelected = _selectedOccasion == occ['id'];
            final color = occ['color'] as Color;
            final isCombo = occ['isCombo'] == true;

            return InkWell(
              onTap: () {
                setState(() => _selectedOccasion = occ['id']);
                _refreshPlansForSelectedMembers();
                if (_selectedMemberIds.isNotEmpty) {
                  _checkHealthPassEligibility(_selectedMemberIds.first);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: (constraints.maxWidth - 10) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : AppColors.slate200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(occ['icon'] as IconData, size: 18, color: color),
                        ),
                        if (isCombo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '2 MEALS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Text(
                            occ['code'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      occ['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      occ['time'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAssignedDishesList() {
    if (_isLoadingPlans) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Fetching clinical diet meals...', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
            ],
          ),
        ),
      );
    }

    final selectedMembers = _members.where((m) => _selectedMemberIds.contains(m.id)).toList();

    return Column(
      children: selectedMembers.map((member) {
        final plan = _memberDietPlans[member.id];
        final todayMeals = (plan?['todayMeals'] as List<dynamic>?) ?? [];
        final matchingMeals = todayMeals.where((m) {
          final occ = m['occasion']?.toString().toUpperCase() ?? '';
          return _isMealMatchingOccasion(occ);
        }).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member header badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primarySubtle,
                        child: Text(
                          member.name[0],
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: plan != null ? AppColors.emerald50 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isHpChecking
                          ? 'CHECKING...'
                          : (plan != null ? 'DIETITIAN APPROVED' : 'RECOMMENDED DISHES'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: plan != null ? AppColors.emerald700 : AppColors.slate600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (matchingMeals.isNotEmpty) ...[
                ...matchingMeals.map((meal) {
                  final mealTitle = meal['title']?.toString() ?? 'Assigned Meal';
                  final calories = meal['plannedNutrition']?['calories']?.toString() ?? '450';
                  final protein = meal['plannedNutrition']?['proteinG']?.toString() ?? '28';
                  final carbs = meal['plannedNutrition']?['carbsG']?.toString() ?? '45';
                  final dishes = (meal['dishes'] as List<dynamic>?) ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              mealTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800),
                            ),
                          ),
                          Text(
                            '$calories kcal • ${protein}g P • ${carbs}g C',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...dishes.map((d) {
                        final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
                        final key = '${member.id}_$dishId';
                        final isChecked = _selectedDishes[key] ?? true;
                        final servings = _dishServings[key] ?? 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isChecked ? AppColors.slate50 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChecked ? AppColors.primary.withOpacity(0.3) : AppColors.slate200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _selectedDishes[key] = val ?? false);
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['name']?.toString() ?? 'Assigned Dish',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isChecked ? AppColors.slate900 : AppColors.slate400,
                                        decoration: isChecked ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Text(
                                      '${d['servingQuantity'] ?? 1} ${d['servingUnit'] ?? "serving"} • 20 mins',
                                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              if (isChecked) ...[
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.slate600),
                                      onPressed: () {
                                        if (servings > 1) {
                                          setState(() => _dishServings[key] = servings - 1);
                                        }
                                      },
                                    ),
                                    Text(
                                      '$servings',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                                      onPressed: () {
                                        setState(() => _dishServings[key] = servings + 1);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ] else ...[
                // Fallback curated meals when member doesn't have an active plan for this occasion
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No specific plan scheduled for ${member.name} for $_selectedOccasion.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'We have loaded chef-recommended balanced healthy dishes below:',
                        style: TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 8),
                      ..._fallbackDishes
                          .where((f) => _isMealMatchingOccasion(f['occasion']))
                          .map((f) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${f['name']} (${f['portion']})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate800),
                                ),
                              ),
                              Text(
                                '${f['cookTimeMin']}m',
                                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddressCard() {
    if (_selectedAddress == null) {
      return InkWell(
        onTap: _showAddressPickerSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Service Kitchen Address',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                    ),
                    Text(
                      'Tap to choose saved kitchen or add new address',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    final addr = _selectedAddress!;

    return InkWell(
      onTap: _showAddressPickerSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(addr.kitchenIcon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addr.kitchenLabelDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: addr.isServiceable ? AppColors.emerald50 : AppColors.rose50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          addr.isServiceable ? 'SERVICEABLE' : 'CHECKING',
                          style: TextStyle(
                            color: addr.isServiceable ? AppColors.emerald700 : AppColors.danger,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addr.formattedAddress,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showAddressPickerSheet,
              child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
