import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/models/address_model.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_dish_image.dart';
import '../../shared/widgets/loading_view.dart';
import '../catalogue/dish_detail_screen.dart';

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

  // Set when opened from a specific diet-plan meal ("Book Chef for this
  // Meal"): only that meal's dishes start selected.
  String? _focusMealId;
  bool _didReadArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _focusMealId = args['dietPlanMealId']?.toString();
      final occasion = _bookingOccasionFor(args['occasion']?.toString());
      if (occasion != null) _selectedOccasion = occasion;
    }
    // Deferred: _loadInitialData calls setState, which isn't allowed mid-build.
    Future.microtask(_loadInitialData);
  }

  /// Diet-plan occasions (incl. snacks) → the chef visit slot that cooks them.
  static String? _bookingOccasionFor(String? planOccasion) {
    switch (planOccasion?.toUpperCase()) {
      case 'BREAKFAST':
      case 'MID_MORNING':
        return 'BREAKFAST';
      case 'LUNCH':
        return 'LUNCH';
      case 'EVENING_SNACK':
      case 'DINNER':
      case 'BEDTIME':
        return 'DINNER';
      default:
        return null;
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Household members
      final membersRes = await _api.get<List<dynamic>>(
        ApiEndpoints.householdMembers,
      );
      if (membersRes.success && membersRes.data != null) {
        _members = membersRes.data!
            .map(
              (m) => HouseholdMemberModel.fromJson(m as Map<String, dynamic>),
            )
            .toList();
        if (_members.isNotEmpty) {
          // Default: select the primary self member
          final selfMember = _members.firstWhere(
            (m) => m.isSelf,
            orElse: () => _members.first,
          );
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
      final addrRes = await _api.get<List<dynamic>>(
        ApiEndpoints.customerAddresses,
      );
      if (addrRes.success && addrRes.data != null) {
        _addresses = addrRes.data!
            .map((a) => AddressModel.fromJson(a as Map<String, dynamic>))
            .toList();

        if (_addresses.isNotEmpty) {
          if (_selectedAddress == null ||
              !_addresses.any((a) => a.id == _selectedAddress!.id)) {
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
        final isFocused =
            _focusMealId == null || meal['id']?.toString() == _focusMealId;
        final dishes = (meal['dishes'] as List<dynamic>?) ?? [];
        for (final d in dishes) {
          final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
          final key = '${memberId}_$dishId';
          if (!_selectedDishes.containsKey(key)) {
            _selectedDishes[key] = isFocused;
            _dishServings[key] = (d['servings'] as num?)?.toInt() ?? 1;
          }
        }
      }
    }
  }

  bool _isMealMatchingOccasion(String mealOccasion) {
    switch (_selectedOccasion) {
      case 'BREAKFAST':
        return mealOccasion.contains('BREAKFAST') ||
            mealOccasion.contains('MORNING');
      case 'LUNCH':
        return mealOccasion.contains('LUNCH') ||
            mealOccasion.contains('MID_DAY');
      case 'DINNER':
        return mealOccasion.contains('DINNER') ||
            mealOccasion.contains('EVENING');
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.slate500,
                        ),
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
                          const Icon(
                            Icons.location_off_outlined,
                            size: 36,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No saved kitchens found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.slate800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add your delivery kitchen address to proceed with booking.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
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
                                color: isSelected
                                    ? AppColors.primarySubtle
                                    : AppColors.slate50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.slate200,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    addr.kitchenIcon,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.slate600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              addr.kitchenLabelDisplayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isSelected
                                                    ? AppColors.primaryDark
                                                    : AppColors.slate900,
                                              ),
                                            ),
                                            if (addr.isDefault) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.slate600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.slate400,
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
                        final added = await Navigator.pushNamed(
                          context,
                          AppRoutes.addressForm,
                        );
                        if (added == true) {
                          await _fetchAddressesInternal();
                        }
                      },
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'Add New Kitchen Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                final memberObj = _members.where((m) => m.id == memberId).firstOrNull;
                final rawImg = d['imageUrl']?.toString() ??
                    d['dish']?['imageUrl']?.toString() ??
                    d['image']?.toString();
                final tags = (d['dietaryTags'] as List<dynamic>?)
                        ?.map((t) => t.toString())
                        .toList() ??
                    [];
                final isVeg = tags.any((t) =>
                        t.toLowerCase() == 'vegetarian' ||
                        t.toLowerCase() == 'vegan') ||
                    (d['isVegetarian'] == true);

                result.add({
                  'dishId': dishId,
                  'name': d['name'] ?? 'Dietitian Assigned Dish',
                  'servings': _dishServings[key] ?? 1,
                  'baseCookTimeMin': 20,
                  'memberId': memberId,
                  'memberName': memberObj?.name ?? 'Family Member',
                  'imageUrl': rawImg,
                  'isVegetarian': isVeg,
                  'dietaryTags': tags,
                  'description': d['description']?.toString(),
                });
              }
            }
          }
        }
      }
    }

    return result;
  }

  Future<void> _proceedToQuote() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one household member.'),
        ),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a service kitchen address.'),
        ),
      );
      return;
    }

    final dishesToCook = _collectSelectedDishesForBooking();
    if (dishesToCook.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one meal dish to prepare.'),
        ),
      );
      return;
    }

    final selectedMembers = _members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();
    final primaryMember = selectedMembers.isNotEmpty
        ? selectedMembers.first
        : null;
    final memberNames = selectedMembers.map((m) => m.name).join(', ');
    final bookingOptionCode = _getBookingOptionCode();

    final result = await Navigator.pushNamed(
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

    if (result == true || result == 'confirmed') {
      if (mounted) {
        setState(() {
          _selectedDishes.clear();
          _dishServings.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(
          message: 'Loading assigned diet meal & family profiles...',
        ),
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
                    Icon(
                      Icons.medical_information_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select covered family members and choose meals from their clinical diet plans.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
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
                label:
                    'Calculate Cooking Time & Review ($selectedDishesCount Dishes)',
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.slate900,
              ),
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

    final maxFamilyMembers = _hpEligibility?['max_covered_members'] ?? 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.family_restroom_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Health Pass Family Allowance: Up to $maxFamilyMembers family members can be added for free chef booking (${_members.length} added).',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedMemberIds.length} of ${_members.length} Selected',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedMemberIds.length == _members.length) {
                    _selectedMemberIds.clear();
                    if (_members.isNotEmpty) {
                      _selectedMemberIds.add(_members.first.id);
                    }
                  } else {
                    _selectedMemberIds.addAll(_members.map((m) => m.id));
                  }
                });
                _refreshPlansForSelectedMembers();
              },
              child: Text(
                _selectedMemberIds.length == _members.length
                    ? 'Reset to Self'
                    : 'Select All Members',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySubtle : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.slate200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? AppColors.primary
                                : AppColors.slate200,
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : 'M',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.slate700,
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
                                child: Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
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
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : AppColors.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              member.relationship.toLowerCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate500,
                              ),
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
    final selectedOcc = _occasionOptions.firstWhere(
      (o) => o['id'] == _selectedOccasion,
      orElse: () => _occasionOptions[1],
    );
    final isSelectedCombo = selectedOcc['isCombo'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
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
                    setState(() {
                      _selectedOccasion = occ['id'];
                      // A new slot means the whole plan for it, not one meal.
                      if (_focusMealId != null) {
                        _focusMealId = null;
                        _selectedDishes.removeWhere((_, selected) => !selected);
                      }
                    });
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
                              child: Icon(
                                occ['icon'] as IconData,
                                size: 18,
                                color: color,
                              ),
                            ),
                            if (isCombo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.slate700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'STANDARD FEE',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 10,
                                      color: AppColors.successDark,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'FREE WITH PASS',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.successDark,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isCombo) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Extended prep duration',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelectedCombo
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelectedCombo
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelectedCombo
                    ? Icons.schedule_rounded
                    : Icons.verified_rounded,
                size: 18,
                color: isSelectedCombo
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSelectedCombo
                      ? 'Combo preps (Breakfast & Lunch / Lunch & Dinner) require longer cooking duration and are charged standard chef fees. Free Health Pass visits cover single meal sessions (B, L, D).'
                      : 'Eligible for 100% Free Health Pass Chef Booking! Single meal sessions (Breakfast, Lunch, Dinner) use 1 free visit from your monthly pass quota.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSelectedCombo
                        ? const Color(0xFF92400E)
                        : const Color(0xFF166534),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedDishesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingPlans) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fetching clinical diet meals & macro targets...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedMembers = _members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();

    // Calculate selection statistics across all active members in this occasion
    int totalAvailableDishes = 0;
    int totalSelectedDishes = 0;
    for (final member in selectedMembers) {
      final plan = _memberDietPlans[member.id];
      final todayMeals = (plan?['todayMeals'] as List<dynamic>?) ?? [];
      for (final meal in todayMeals) {
        final occ = meal['occasion']?.toString().toUpperCase() ?? '';
        if (_isMealMatchingOccasion(occ)) {
          final dishes = (meal['dishes'] as List<dynamic>?) ?? [];
          for (final d in dishes) {
            totalAvailableDishes++;
            final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
            final key = '${member.id}_$dishId';
            if (_selectedDishes[key] == true) {
              totalSelectedDishes++;
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Action & Status Bar
        if (totalAvailableDishes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF06281E) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF047857).withOpacity(0.4) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$totalSelectedDishes of $totalAvailableDishes dishes selected',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF166534),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    final selectAll = totalSelectedDishes < totalAvailableDishes;
                    setState(() {
                      for (final member in selectedMembers) {
                        final plan = _memberDietPlans[member.id];
                        final todayMeals = (plan?['todayMeals'] as List<dynamic>?) ?? [];
                        for (final meal in todayMeals) {
                          final occ = meal['occasion']?.toString().toUpperCase() ?? '';
                          if (_isMealMatchingOccasion(occ)) {
                            final dishes = (meal['dishes'] as List<dynamic>?) ?? [];
                            for (final d in dishes) {
                              final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
                              final key = '${member.id}_$dishId';
                              _selectedDishes[key] = selectAll;
                            }
                          }
                        }
                      }
                    });
                  },
                  child: Text(
                    totalSelectedDishes < totalAvailableDishes ? 'Select All' : 'Clear All',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

        ...selectedMembers.map((member) {
          final plan = _memberDietPlans[member.id];
          final todayMeals = (plan?['todayMeals'] as List<dynamic>?) ?? [];
          final matchingMeals = todayMeals.where((m) {
            final occ = m['occasion']?.toString().toUpperCase() ?? '';
            return _isMealMatchingOccasion(occ);
          }).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.slate800 : AppColors.slate200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                            Text(
                              member.isSelf ? 'Primary Member' : member.relationship.toLowerCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: plan != null
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                            : (isDark ? AppColors.slate800 : AppColors.slate100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            plan != null ? Icons.verified_rounded : Icons.pending_outlined,
                            size: 11,
                            color: plan != null
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                : AppColors.slate500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isHpChecking
                                ? 'CHECKING...'
                                : (plan != null ? 'DIETITIAN APPROVED' : 'RECOMMENDED'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: plan != null
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                  : AppColors.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),

                if (matchingMeals.isNotEmpty) ...[
                  ...matchingMeals.map((meal) {
                    final mealTitle = meal['title']?.toString() ?? 'Assigned Meal';
                    final calories =
                        meal['plannedNutrition']?['calories']?.toString() ?? '450';
                    final protein =
                        meal['plannedNutrition']?['proteinG']?.toString() ?? '28';
                    final carbs =
                        meal['plannedNutrition']?['carbsG']?.toString() ?? '45';
                    final dishes = (meal['dishes'] as List<dynamic>?) ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal Occasion Banner & Target Macros
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mealTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white : AppColors.slate800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$calories kcal • ${protein}g P • ${carbs}g C',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Dishes in Meal
                        ...dishes.map((d) {
                          final dishId = d['dishId'] ?? d['id']?.toString() ?? '';
                          final key = '${member.id}_$dishId';
                          final isChecked = _selectedDishes[key] ?? true;
                          final servings = _dishServings[key] ?? 1;
                          final dishName = d['name']?.toString() ?? 'Assigned Dish';
                          final rawImg = d['imageUrl']?.toString() ?? d['dish']?['imageUrl']?.toString();
                          final dietaryTags = (d['dietaryTags'] as List<dynamic>?)
                                  ?.map((t) => t.toString())
                                  .toList() ??
                              [];
                          final isVeg = dietaryTags.any((t) =>
                                  t.toLowerCase() == 'vegetarian' ||
                                  t.toLowerCase() == 'vegan') ||
                              (d['isVegetarian'] == true);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? (isDark ? const Color(0xFF06281E).withOpacity(0.6) : const Color(0xFFF0FDF4))
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isChecked
                                    ? AppColors.primary.withOpacity(0.5)
                                    : (isDark ? AppColors.slate800 : AppColors.slate200),
                                width: isChecked ? 1.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Checkbox
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () {
                                          setState(() {
                                            _selectedDishes[key] = !isChecked;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: isChecked,
                                              activeColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedDishes[key] =
                                                      val ?? false;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Dish Content Area (Clicking anywhere navigates to dish details)
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () {
                                            final dishModel = DishModel(
                                              id: dishId,
                                              name: dishName,
                                              category: 'BALANCED',
                                              imageUrl: rawImg,
                                              baseCookTimeMin: 20,
                                              description:
                                                  d['description']?.toString(),
                                              dietaryTags: dietaryTags,
                                            );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    DishDetailScreen(
                                                        dish: dishModel),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            child: Row(
                                              children: [
                                                EBICDishImage(
                                                  imageUrl: rawImg,
                                                  width: 58,
                                                  height: 58,
                                                  borderRadius: 12,
                                                  isVegetarian: isVeg,
                                                  showVegIndicator: true,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        dishName,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isChecked
                                                              ? (isDark
                                                                  ? Colors.white
                                                                  : AppColors
                                                                      .slate900)
                                                              : (isDark
                                                                  ? AppColors
                                                                      .slate500
                                                                  : AppColors
                                                                      .slate400),
                                                          decoration: isChecked
                                                              ? null
                                                              : TextDecoration
                                                                  .lineThrough,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '${d['servingQuantity'] ?? 1} ${d['servingUnit'] ?? "serving"} • ⏱️ 20 mins',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? AppColors
                                                                  .slate400
                                                              : AppColors
                                                                  .slate500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: const [
                                                          Text(
                                                            'View Details',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .primary,
                                                            ),
                                                          ),
                                                          SizedBox(width: 2),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_ios_rounded,
                                                            size: 9,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Prescribed portions — fixed by the dietitian's plan.
                                      if (isChecked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark ? AppColors.slate700 : AppColors.slate200,
                                            ),
                                          ),
                                          child: Text(
                                            '$servings ${servings == 1 ? 'portion' : 'portions'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white : AppColors.slate700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 6),
                      ],
                    );
                  }),
                ] else ...[
                  // Member has no active diet plan for this occasion
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No diet meal scheduled for ${member.name} for $_selectedOccasion',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.slate800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your clinical dietitian has not published a meal plan for this slot yet. You can pick dishes from the Chef\'s Menu catalogue instead.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.slate400 : AppColors.slate600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.bookChefCatalogue);
                          },
                          icon: const Icon(Icons.menu_book_rounded, size: 14),
                          label: const Text("Browse Chef's Menu", style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
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
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.add_location_alt_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Service Kitchen Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      'Tap to choose saved kitchen or add new address',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.primary,
              ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: addr.isServiceable
                              ? AppColors.emerald50
                              : AppColors.rose50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          addr.isServiceable ? 'SERVICEABLE' : 'CHECKING',
                          style: TextStyle(
                            color: addr.isServiceable
                                ? AppColors.emerald700
                                : AppColors.danger,
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showAddressPickerSheet,
              child: const Text(
                'Change',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
