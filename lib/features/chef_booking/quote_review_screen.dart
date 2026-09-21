import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/address_model.dart';
import '../../shared/models/quote_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/status_badge.dart';

class QuoteReviewScreen extends StatefulWidget {
  final Map<String, dynamic> bookingConfig;

  const QuoteReviewScreen({super.key, required this.bookingConfig});

  @override
  State<QuoteReviewScreen> createState() => _QuoteReviewScreenState();
}

class _QuoteReviewScreenState extends State<QuoteReviewScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _chefNotesController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  QuoteModel? _quote;
  Map<String, dynamic>? _cookingTimeData;
  String? _appliedCoupon;
  double _couponDiscount = 0.0;

  // Kitchen Service Address State
  String _currentAddressLine = '';
  AddressModel? _selectedAddress;

  // Selected Member State (safely initialized to prevent LateInitializationError on hot reload)
  String _currentMemberId = '';
  String _currentMemberName = 'Self';
  String _currentMemberRelation = 'SELF';
  List<String> _currentMemberDietary = [];
  List<String> _currentMemberAllergies = [];
  bool _currentIsHealthPassCovered = false;
  bool _hasFreeChefEntitlement = false;

  bool get _isFreeChefBooking {
    if (_quote != null && _quote!.total <= 0.0) return true;
    if (_hasFreeChefEntitlement && (_quote?.itemCharges ?? 0.0) <= 0.0) return true;
    if (_currentIsHealthPassCovered && (_quote?.itemCharges ?? 0.0) <= 0.0) return true;
    final isAssigned = widget.bookingConfig['mode'] == 'ASSIGNED_MEAL' ||
        widget.bookingConfig['bookingFlow'] == 'ASSIGNED_MEAL';
    if (isAssigned && (_quote?.itemCharges ?? 0.0) <= 0.0 && (_quote?.total ?? 0.0) <= 0.0) return true;
    return false;
  }

  // Available Promotional Offers (Loaded dynamically from backend)
  final List<Map<String, dynamic>> _availableOffers = [];

  static const List<String> _quickCookingNotes = [
    'Mild spice only',
    'Less oil',
    'No onion / garlic',
    'Low sodium',
    'Extra crispy',
  ];

  String _selectedChefId = 'auto';
  String _selectedChefName = 'Auto-Assign Nearest Certified Chef';
  Map<String, dynamic>? _selectedChefData;

  // Available Verified Home Chefs
  final List<Map<String, dynamic>> _availableChefs = [
    {
      'id': 'auto',
      'name': 'Auto-Assign Nearest Certified Chef',
      'title': 'Fastest Dispatch • AI Algorithm Match',
      'rating': 4.9,
      'reviews': 340,
      'experienceYears': 7,
      'specialties': ['Multi-Cuisine', 'Diet Compliance', 'Speed Cooking'],
      'distanceKm': 1.2,
      'etaMins': 25,
      'badge': 'RECOMMENDED',
      'isAuto': true,
    },
    {
      'id': 'chef-1',
      'name': 'Chef Rajesh Sharma',
      'title': 'Executive Nutrition Chef',
      'rating': 4.9,
      'reviews': 128,
      'experienceYears': 8,
      'specialties': ['North Indian', 'Balanced Diabetic Meals', 'Low Sodium'],
      'distanceKm': 1.5,
      'etaMins': 28,
      'badge': 'HYGIENE CERTIFIED',
      'isAuto': false,
    },
    {
      'id': 'chef-2',
      'name': 'Chef Anita Kulkarni',
      'title': 'Clinical Diet Specialist',
      'rating': 4.8,
      'reviews': 94,
      'experienceYears': 6,
      'specialties': ['South Indian', 'Low GI Diets', 'High Fibre'],
      'distanceKm': 2.1,
      'etaMins': 32,
      'badge': 'NUTRITION PRO',
      'isAuto': false,
    },
    {
      'id': 'chef-3',
      'name': 'Chef Sameer Verma',
      'title': 'Gourmet Fitness Chef',
      'rating': 4.9,
      'reviews': 156,
      'experienceYears': 10,
      'specialties': ['Continental', 'High-Protein', 'Clean Keto'],
      'distanceKm': 2.8,
      'etaMins': 35,
      'badge': 'TOP RATED',
      'isAuto': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initMemberState();
    _loadSavedAddress();
    _loadAvailablePromotions();
    _fetchDynamicCookingTimeAndQuote();
  }

  @override
  void didUpdateWidget(QuoteReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingConfig != widget.bookingConfig) {
      _initMemberState();
      _loadSavedAddress();
      _fetchDynamicCookingTimeAndQuote();
    }
  }

  void _initMemberState() {
    _currentMemberId = widget.bookingConfig['memberId']?.toString() ?? '';
    _currentMemberName = widget.bookingConfig['memberName']?.toString() ?? 'Self';
    _currentMemberRelation = widget.bookingConfig['memberRelation']?.toString() ?? 'SELF';
    _currentIsHealthPassCovered = widget.bookingConfig['isHealthPassCovered'] == true;

    final rawAddress = widget.bookingConfig['addressLine']?.toString() ??
        widget.bookingConfig['address']?['addressLine']?.toString() ??
        '';
    if (rawAddress.isNotEmpty && rawAddress != 'Default Residence Kitchen') {
      _currentAddressLine = rawAddress;
    }

    final rawDiet = widget.bookingConfig['memberDietary'];
    if (rawDiet is List) {
      _currentMemberDietary = rawDiet.map((e) => e.toString()).toList();
    } else {
      _currentMemberDietary = [];
    }

    final rawAllergies = widget.bookingConfig['memberAllergies'];
    if (rawAllergies is List) {
      _currentMemberAllergies = rawAllergies.map((e) => e.toString()).toList();
    } else {
      _currentMemberAllergies = [];
    }
  }

  Future<void> _loadSavedAddress() async {
    if (_currentAddressLine.isNotEmpty && _currentAddressLine != 'Default Residence Kitchen') return;
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.addresses);
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final addresses = res.data!.map((item) => AddressModel.fromJson(item as Map<String, dynamic>)).toList();
        final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        if (mounted) {
          setState(() {
            _selectedAddress = defaultAddr;
            _currentAddressLine = defaultAddr.formattedAddress;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAvailablePromotions() async {
    try {
      final res = await _api.get<dynamic>(
        ApiEndpoints.promotionsAvailable,
        queryParameters: {'serviceType': 'CHEF_VISIT'},
      );
      if (res.success && res.data != null) {
        final raw = res.data;
        List<Map<String, dynamic>> list = [];
        if (raw is List) {
          list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (raw is Map && raw['items'] is List) {
          list = (raw['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (list.isNotEmpty && mounted) {
          setState(() {
            _availableOffers.clear();
            for (final p in list) {
              final val = (p['discountValue'] as num?)?.toDouble() ?? 50.0;
              _availableOffers.add({
                'code': p['code']?.toString() ?? 'OFFER',
                'title': p['title']?.toString() ?? p['name']?.toString() ?? 'Special Offer',
                'desc': p['desc']?.toString() ?? p['description']?.toString() ?? p['terms']?.toString() ?? '',
                'discount': val,
                'badge': p['formattedDiscount']?.toString() ?? 'OFFER',
              });
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectOrChangeAddress() async {
    final selected = await Navigator.pushNamed(
      context,
      AppRoutes.addresses,
      arguments: {'isPicker': true},
    );
    if (selected is AddressModel) {
      setState(() {
        _selectedAddress = selected;
        _currentAddressLine = selected.formattedAddress;
      });
    }
  }

  void _updateDishQuantity(Map<String, dynamic> dish, int newQty) {
    final dishes = (widget.bookingConfig['dishes'] as List<dynamic>?) ?? [];

    final targetId = dish['dishId'] ?? dish['recipeId'] ?? dish['id'] ?? dish['name'];
    final targetMember = dish['memberId'] ?? dish['memberName'];

    dynamic targetEntry;
    for (final item in dishes) {
      if (identical(item, dish)) {
        targetEntry = item;
        break;
      }
      if (item is Map) {
        final itemId = item['dishId'] ?? item['recipeId'] ?? item['id'] ?? item['name'];
        final itemMember = item['memberId'] ?? item['memberName'];
        final idMatches = (itemId != null && targetId != null && itemId.toString() == targetId.toString()) ||
            (item['name'] != null && dish['name'] != null && item['name'].toString() == dish['name'].toString());
        final memberMatches = targetMember == null || itemMember == null || itemMember.toString() == targetMember.toString();
        if (idMatches && memberMatches) {
          targetEntry = item;
          break;
        }
      }
    }

    if (newQty <= 0) {
      if (dishes.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one dish must remain in your booking.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      setState(() {
        if (targetEntry != null) {
          dishes.remove(targetEntry);
        } else {
          dishes.remove(dish);
        }
        dish['servings'] = 0;
        dish['quantity'] = 0;
      });
    } else {
      setState(() {
        if (targetEntry is Map) {
          targetEntry['servings'] = newQty;
          targetEntry['quantity'] = newQty;
        }
        dish['servings'] = newQty;
        dish['quantity'] = newQty;
      });
    }

    _fetchDynamicCookingTimeAndQuote();
  }

  void _showAddMoreDishesOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildAddMoreDishesSheet(),
    );
  }

  Widget _buildAddMoreDishesSheet() {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add More Dishes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate900),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select extra recipes to add to this home cooking session.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          // Option 1: Quick Return to Catalogue
          InkWell(
            onTap: () {
              Navigator.pop(context); // close sheet
              Navigator.pop(context); // return to catalogue
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Browse Chef's Menu",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Explore 50+ diet-tailored recipes and customize portions',
                          style: TextStyle(fontSize: 11, color: AppColors.slate600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDishQuantitySheet(Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Dish';
    int currentServings = (d['servings'] as num?)?.toInt() ?? 1;
    final unitPrice = (d['unitPrice'] as num?)?.toDouble() ?? 120.0;
    final isAssigned = widget.bookingConfig['bookingFlow'] == 'ASSIGNED_MEAL';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final lineTotal = currentServings * (isAssigned ? 0.0 : unitPrice);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAssigned ? 'Covered by Plan' : '₹${unitPrice.toStringAsFixed(0)} per portion',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Number of Portions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.slate300),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (currentServings > 1) {
                                  setSheetState(() => currentServings--);
                                }
                              },
                            ),
                            Text(
                              '$currentServings',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () {
                                setSheetState(() => currentServings++);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total for this dish:', style: TextStyle(fontSize: 13, color: AppColors.slate600)),
                      Text(
                        lineTotal > 0 ? '₹${lineTotal.toStringAsFixed(0)}' : 'Covered',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateDishQuantity(d, currentServings);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Update Portions ($currentServings)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateDishQuantity(d, 0);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.danger),
                      label: const Text(
                        'Remove Dish from Booking',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger, width: 1.1),
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

  @override
  void dispose() {
    _couponController.dispose();
    _chefNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchDynamicCookingTimeAndQuote() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dishes = (widget.bookingConfig['dishes'] as List<dynamic>?) ?? [];

    try {
      // 1. Calculate Authoritative Dynamic Cooking Time from backend (Section 34)
      final cookingTimePayload = {
        'dishes': dishes.map((d) {
          return {
            'dishId': d['dishId'] ?? d['id'],
            'servings': (d['servings'] as num?)?.toInt() ?? 1,
          };
        }).toList(),
      };

      final cookRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.ordersCookingTime,
        body: cookingTimePayload,
      );

      if (cookRes.success && cookRes.data != null) {
        _cookingTimeData = cookRes.data;
      }

      final estimatedCookMinutes = (_cookingTimeData?['totalMinutes'] as num?)?.toInt() ?? 35;

      // 2. Fetch authoritative Health Pass Quote Context (Section 50 & 54)
      Map<String, dynamic>? hpQuoteContext;
      final serviceDate = (widget.bookingConfig['serviceDate'] as String?) ??
          DateTime.now().toIso8601String().split('T')[0];
      final mealType = (widget.bookingConfig['bookingOption'] as String?) ?? 'L';

      if (_currentMemberId.isNotEmpty) {
        final hpCtxRes = await _api.get<Map<String, dynamic>>(
          ApiEndpoints.healthPassChefQuoteContext,
          queryParameters: {
            'memberId': _currentMemberId,
            'member_id': _currentMemberId,
            'serviceDate': serviceDate,
            'service_date': serviceDate,
            'mealType': mealType,
            'meal_type': mealType,
          },
        );
        if (hpCtxRes.success && hpCtxRes.data != null) {
          hpQuoteContext = hpCtxRes.data;
        }
      }

      // 3. Build Authoritative Dynamic Quote (Section 35 & 36, Module 12)
      final isAssigned = widget.bookingConfig['mode'] == 'ASSIGNED_MEAL';
      final quoteItems = dishes.map((d) {
        return {
          'itemType': 'DISH',
          'referenceId': d['dishId'] ?? d['id'],
          'description': d['name'] ?? 'Dish Portion',
          'quantity': (d['servings'] as num?)?.toInt() ?? 1,
          'unitPrice': isAssigned ? 0.0 : ((d['unitPrice'] as num?)?.toDouble() ?? 120.0),
        };
      }).toList();

      // Add Chef visit item
      quoteItems.insert(0, {
        'itemType': 'CHEF_VISIT',
        'description': 'Certified Home Chef Service Fee',
        'quantity': 1,
        'unitPrice': 249.0,
      });

      final quotePayload = {
        'serviceType': 'CHEF_VISIT',
        'items': quoteItems,
        'couponCode': _appliedCoupon,
        'currency': 'INR',
        'memberId': _currentMemberId,
        'serviceDate': serviceDate,
        'healthPassId': hpQuoteContext?['health_pass_id'],
        'entitlementId': hpQuoteContext?['entitlement_id'],
      };

      final quoteRes = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.calculateQuote,
        body: quotePayload,
      );

      final hasFreeVisitEntitlement = hpQuoteContext?['entitlement_available'] == true ||
          (isAssigned && widget.bookingConfig['hpEligibility']?['entitlement_available'] == true) ||
          _currentIsHealthPassCovered;
      _hasFreeChefEntitlement = hasFreeVisitEntitlement;

      final calculatedDishCharge = isAssigned
          ? 0.0
          : dishes.fold<double>(
              0.0,
              (sum, d) =>
                  sum +
                  (((d['servings'] as num?)?.toInt() ?? 1) *
                      ((d['unitPrice'] as num?)?.toDouble() ?? 120.0)),
            );

      if (quoteRes.success && quoteRes.data != null) {
        final rawQuote = quoteRes.data!;
        final hpBenefit = (rawQuote['healthPassBenefit'] as num?)?.toDouble() ??
            (hasFreeVisitEntitlement ? 249.0 : 0.0);
        final chefCharge = (rawQuote['chefServiceCharge'] as num?)?.toDouble() ?? 249.0;
        final rawItemCharge = (rawQuote['itemCharges'] as num?)?.toDouble();
        final itemCharge = (rawItemCharge != null && rawItemCharge > 0)
            ? rawItemCharge
            : calculatedDishCharge;
        final rawDiscount = (rawQuote['discount'] as num?)?.toDouble() ?? 0.0;
        final disc = rawDiscount > 0 ? rawDiscount : _couponDiscount;
        final promo = (rawQuote['promotion'] as num?)?.toDouble() ?? 0.0;
        final subtotal = (rawQuote['subtotal'] as num?)?.toDouble() ?? (chefCharge + itemCharge);
        final taxable = (subtotal - hpBenefit - disc - promo).clamp(0.0, 999999.0);
        final tax = (rawQuote['tax'] as num?)?.toDouble() ?? (taxable * 0.05);
        final rawTotal = (rawQuote['total'] as num?)?.toDouble();
        final total = (disc > 0 && rawDiscount == 0.0 && rawTotal != null)
            ? (rawTotal - disc).clamp(0.0, 999999.0)
            : (rawTotal ?? (taxable + tax));

        _quote = QuoteModel(
          quoteId: rawQuote['quoteId']?.toString() ?? 'quote_${DateTime.now().millisecondsSinceEpoch}',
          cookingTimeMinutes: estimatedCookMinutes,
          chefServiceCharge: chefCharge,
          itemCharges: itemCharge,
          healthPassBenefit: hpBenefit,
          discount: disc,
          promotion: promo,
          tax: tax,
          subtotal: subtotal,
          total: total,
          currency: 'INR',
        );
      } else {
        // Fallback commercial calculation adhering to Section 29 & 36
        final dishCharge = calculatedDishCharge;
        const chefFee = 249.0;
        final subtotal = chefFee + dishCharge;
        final discount = _couponDiscount;
        final hpBenefit = hasFreeVisitEntitlement ? chefFee : 0.0;
        final taxable = (subtotal - discount - hpBenefit).clamp(0.0, 99999.0);
        final gst = taxable * 0.05;
        final total = taxable + gst;

        _quote = QuoteModel(
          quoteId: 'quote_${DateTime.now().millisecondsSinceEpoch}',
          cookingTimeMinutes: estimatedCookMinutes,
          chefServiceCharge: chefFee,
          itemCharges: dishCharge,
          healthPassBenefit: hpBenefit,
          discount: discount,
          promotion: 0.0,
          tax: gst,
          subtotal: subtotal,
          total: total,
          currency: 'INR',
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      final dishes = (widget.bookingConfig['dishes'] as List<dynamic>?) ?? [];
      final isAssigned = widget.bookingConfig['bookingFlow'] == 'ASSIGNED_MEAL' ||
          widget.bookingConfig['mode'] == 'ASSIGNED_MEAL';
      final dishCharge = isAssigned
          ? 0.0
          : dishes.fold<double>(
              0.0,
              (sum, d) =>
                  sum +
                  (((d['servings'] as num?)?.toInt() ?? 1) *
                      ((d['unitPrice'] as num?)?.toDouble() ?? 120.0)),
            );
      const chefFee = 249.0;
      final hpBenefit = (_currentIsHealthPassCovered || isAssigned) ? chefFee : 0.0;
      final subtotal = chefFee + dishCharge;
      final taxable = (subtotal - _couponDiscount - hpBenefit).clamp(0.0, 99999.0);
      final gst = taxable * 0.05;
      final total = taxable + gst;

      _quote ??= QuoteModel(
        quoteId: 'quote_${DateTime.now().millisecondsSinceEpoch}',
        cookingTimeMinutes: 35,
        chefServiceCharge: chefFee,
        itemCharges: dishCharge,
        healthPassBenefit: hpBenefit,
        discount: _couponDiscount,
        promotion: 0.0,
        tax: gst,
        subtotal: subtotal,
        total: total,
        currency: 'INR',
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyCouponCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.promotionsValidate,
        body: {
          'couponCode': cleanCode,
          'orderTotal': _quote?.total ?? 300.0,
          'serviceType': 'CHEF_VISIT',
        },
      );

      if (res.success && res.data != null && res.data!['valid'] == true) {
        final serverDiscount = (res.data!['discountAmount'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          _appliedCoupon = cleanCode;
          _couponDiscount = serverDiscount;
        });

        await _fetchDynamicCookingTimeAndQuote();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data!['message']?.toString() ?? 'Coupon "$cleanCode" applied! Saved ₹${serverDiscount.toInt()}.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        final errMsg = res.data?['message']?.toString() ?? res.message ?? 'Invalid or expired coupon code.';
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply coupon: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _couponController.clear();
    });
    _fetchDynamicCookingTimeAndQuote();
  }

  void _addQuickNote(String note) {
    final current = _chefNotesController.text.trim();
    if (current.isEmpty) {
      _chefNotesController.text = note;
    } else if (!current.toLowerCase().contains(note.toLowerCase())) {
      _chefNotesController.text = '$current, $note';
    }
    setState(() {});
  }

  void _showOffersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.22),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Offers & Coupons',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.slate900),
                          ),
                          Text(
                            'Tap apply to claim your discount',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.slate600),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_availableOffers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No promotional offers currently available.',
                      style: TextStyle(color: AppColors.slate500, fontSize: 13),
                    ),
                  ),
                )
              else
                ..._availableOffers.map((offer) {
                  final isApplied = _appliedCoupon == offer['code'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isApplied ? AppColors.primarySubtle : AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isApplied ? AppColors.primary : AppColors.slate200,
                        width: isApplied ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isApplied ? AppColors.primary : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.confirmation_number_rounded,
                            color: isApplied ? Colors.white : const Color(0xFFD97706),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      offer['code'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      offer['badge'] as String,
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                offer['title'] as String,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate800),
                              ),
                              Text(
                                offer['desc'] as String,
                                style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        isApplied
                            ? TextButton(
                                onPressed: () {
                                  _removeCoupon();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('REMOVE', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11)),
                              )
                            : ElevatedButton(
                                onPressed: () {
                                  _applyCouponCode(offer['code'] as String);
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                ),
                                child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showMemberSelectionSheet(List<dynamic> allMembers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Update Covered Family Member',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.slate900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select who this chef session & health pass is active for',
                          style: TextStyle(fontSize: 11, color: AppColors.slate500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.slate600),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Member List
              Expanded(
                child: allMembers.isEmpty
                    ? const Center(
                        child: Text(
                          'No registered household members found.',
                          style: TextStyle(color: AppColors.slate500, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: allMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final raw = allMembers[index];
                          final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                          final id = m['id']?.toString() ?? '';
                          final name = m['name']?.toString() ?? 'Member';
                          final relation = m['relationship']?.toString() ?? 'FAMILY';
                          final isCovered = m['isCoveredByHealthPass'] == true;
                          final diet = (m['dietaryPreferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                          final allergies = (m['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                          final isSelected = (id.isNotEmpty && id == _currentMemberId) ||
                              (id.isEmpty && name.toLowerCase() == _currentMemberName.toLowerCase());

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _currentMemberId = id;
                                _currentMemberName = name;
                                _currentMemberRelation = relation;
                                _currentIsHealthPassCovered = isCovered;
                                _currentMemberDietary = diet;
                                _currentMemberAllergies = allergies;
                              });
                              Navigator.pop(ctx);
                              _fetchDynamicCookingTimeAndQuote();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Covered member updated to $name ($relation)'),
                                  backgroundColor: AppColors.primary,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primarySubtle : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.slate200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isSelected ? AppColors.primary : AppColors.slate100,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.5,
                                                  color: AppColors.slate900,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.slate300),
                                              ),
                                              child: Text(
                                                relation.toUpperCase(),
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate600),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (isCovered)
                                              StatusBadge.success('COVERED')
                                            else
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.slate200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('FAMILY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (diet.isNotEmpty)
                                          Text(
                                            'Diet: ${diet.join(", ")}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          allergies.isEmpty ? 'No documented allergies' : '⚠️ Allergies: ${allergies.join(", ")}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: allergies.isEmpty ? AppColors.slate500 : AppColors.danger,
                                            fontWeight: allergies.isEmpty ? FontWeight.normal : FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? AppColors.primary : AppColors.slate400,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChefSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Select Certified Home Chef',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.slate900),
                            ),
                            Text(
                              'Verified for Hygiene, Nutrition & Culinary Excellence',
                              style: TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.slate600),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Chef List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _availableChefs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final chef = _availableChefs[index];
                        final isSelected = _selectedChefId == chef['id'];
                        final isAuto = chef['isAuto'] == true;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setModalState(() {
                              _selectedChefId = chef['id'] as String;
                              _selectedChefName = chef['name'] as String;
                              _selectedChefData = chef;
                            });
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primarySubtle : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.slate300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isAuto ? AppColors.primary : AppColors.slate100,
                                  child: Icon(
                                    isAuto ? Icons.bolt_rounded : Icons.person_rounded,
                                    color: isAuto ? Colors.white : AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              chef['name'] as String,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.slate900),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAuto ? AppColors.primary : AppColors.accentSubtle,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              chef['badge'] as String,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isAuto ? Colors.white : AppColors.amber700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        chef['title'] as String,
                                        style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${chef["rating"]} (${chef["reviews"]})',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                          ),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.location_on_rounded, color: AppColors.slate500, size: 14),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${chef["distanceKm"]} km • ETA ${chef["etaMins"]}m',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.slate600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        children: (chef['specialties'] as List<dynamic>).map((s) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.slate100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.toString(),
                                              style: const TextStyle(fontSize: 10, color: AppColors.slate700),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: chef['id'] as String,
                                  groupValue: _selectedChefId,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        _selectedChefId = chef['id'] as String;
                                        _selectedChefName = chef['name'] as String;
                                        _selectedChefData = chef;
                                      });
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Proceed Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.slate200)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _proceedToPayment();
                        },
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: Text(
                          _quote == null
                              ? 'Proceed to Payment'
                              : _quote!.total == 0.0
                                  ? 'Confirm Chef Visit (Covered)'
                                  : 'Confirm Chef & Pay ₹${_quote!.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _proceedToPayment() {
    if (_quote == null) return;

    final notes = _chefNotesController.text.trim();
    final dishes = (widget.bookingConfig['dishes'] as List<dynamic>?) ?? [];
    final memberIds = dishes
        .map((d) => d['memberId']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .toList();

    Navigator.pushNamed(
      context,
      AppRoutes.bookChefPayment,
      arguments: {
        ...widget.bookingConfig,
        'addressId': _selectedAddress?.id ?? widget.bookingConfig['addressId'] ?? widget.bookingConfig['address']?['id'],
        'memberId': _currentMemberId,
        'memberName': _currentMemberName,
        'memberIds': memberIds.isNotEmpty ? memberIds : (_currentMemberId.isNotEmpty ? [_currentMemberId] : []),
        'quote': _quote,
        'quoteId': _quote!.quoteId,
        'cookingTime': _quote!.cookingTimeMinutes,
        'finalAmount': _quote!.total,
        'chefNotes': notes.isNotEmpty ? notes : null,
        'selectedChefId': _selectedChefId,
        'chefName': _selectedChefName,
        'selectedChef': _selectedChefData ?? _availableChefs.first,
        'addressLine': _currentAddressLine,
        'address': _selectedAddress?.toJson(),
        'dishes': dishes,
        'bookingOption': widget.bookingConfig['bookingOption'] ?? widget.bookingConfig['mealType'] ?? 'L',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.slate50,
        body: LoadingView(message: 'Calculating quote & chef schedule...'),
      );
    }

    final quote = _quote;
    final dishes = (widget.bookingConfig['dishes'] as List<dynamic>?) ?? [];
    final allMembers = (widget.bookingConfig['allMembers'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        iconTheme: const IconThemeData(color: AppColors.slate900),
        title: const Text(
          'Review Booking',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null && quote == null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Covered Household Members & Clinical Profile Card
                  _buildMemberProfileCard(allMembers, dishes),
                  const SizedBox(height: 16),

                  // Service Logistics (Address, Occasion, Arrival Window)
                  _buildLogisticsCard(),
                  const SizedBox(height: 16),

                  // Assigned Certified Chef Card
                  _buildAssignedChefCard(),
                  const SizedBox(height: 16),

                  // Selected Menu & Portions Summary with interactive steppers
                  _buildSelectedDishesCard(dishes),
                  const SizedBox(height: 16),

                  // Chef Cooking Notes & Kitchen Instructions
                  _buildChefNotesCard(),
                  const SizedBox(height: 16),

                  // Promotions List & Offer Application
                  if (!_isFreeChefBooking) ...[
                    _buildPromotionsListCard(),
                    const SizedBox(height: 16),
                  ],

                  // Itemized Bill Details & Taxes
                  if (quote != null) _buildPriceBreakdownCard(quote, dishes),
                  const SizedBox(height: 16),

                  // Safety & Hygiene Trust Strip
                  _buildTrustSafetyStrip(),
                  const SizedBox(height: 16),

                  // Terms & Conditions for Chef Booking
                  _buildTermsAndConditionsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Floating Sticky Checkout Bar (Primary Action Controller)
            if (quote != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _buildStickyBottomCheckout(quote, dishes),
              ),
          ],
        ),
      ),
    );
  }



  Widget _buildMemberProfileCard(List<dynamic> allMembers, List<dynamic> dishes) {
    // Collect unique household members participating in this session
    final participatingMemberNames = dishes
        .map((d) => d['memberName']?.toString() ?? 'Self')
        .toSet();

    final List<Map<String, dynamic>> activeMembers = [];
    for (final name in participatingMemberNames) {
      final match = allMembers.firstWhere(
        (m) => (m['name']?.toString().toLowerCase() == name.toLowerCase()),
        orElse: () => {
          'name': name,
          'relationship': name.toLowerCase() == 'self' ? 'SELF' : 'FAMILY',
          'isCoveredByHealthPass': _currentIsHealthPassCovered,
          'dietaryPreferences': _currentMemberDietary,
          'allergies': _currentMemberAllergies,
        },
      );
      activeMembers.add(Map<String, dynamic>.from(match));
    }

    if (activeMembers.isEmpty) {
      activeMembers.add({
        'name': _currentMemberName,
        'relationship': _currentMemberRelation,
        'isCoveredByHealthPass': _currentIsHealthPassCovered,
        'dietaryPreferences': _currentMemberDietary,
        'allergies': _currentMemberAllergies,
      });
    }

    final coveredCount = activeMembers.where((m) => m['isCoveredByHealthPass'] == true).length;

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Covered Family (${activeMembers.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showMemberSelectionSheet(allMembers),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primaryDark),
                      SizedBox(width: 4),
                      Text(
                        'Update',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Active clinical profile & health pass benefits for this chef session',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  coveredCount > 0 ? '$coveredCount Health Pass Active' : 'Household Verified',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.slate200),

          ...activeMembers.map((m) {
            final name = m['name']?.toString() ?? 'Member';
            final relation = m['relationship']?.toString() ?? 'MEMBER';
            final isPrimary = name.toLowerCase() == _currentMemberName.toLowerCase();
            final isCovered = (isPrimary && _currentIsHealthPassCovered) || m['isCoveredByHealthPass'] == true;
            final dietary = (m['dietaryPreferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final allergies = (m['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

            final memberDishes = dishes.where((d) => (d['memberName']?.toString() ?? 'Self').toLowerCase() == name.toLowerCase()).toList();
            final portions = memberDishes.fold<int>(0, (sum, d) => sum + ((d['servings'] as num?)?.toInt() ?? 1));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.primarySubtle.withOpacity(0.3) : AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPrimary ? AppColors.primary.withOpacity(0.4) : AppColors.slate200,
                  width: isPrimary ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isPrimary ? AppColors.primary : AppColors.slate200,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'M',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isPrimary ? Colors.white : AppColors.slate700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.slate300),
                              ),
                              child: Text(
                                relation.toUpperCase(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate600),
                              ),
                            ),
                            if (isCovered)
                              StatusBadge.success('COVERED')
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.slate200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FAMILY',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate700),
                                ),
                              ),
                            if (isPrimary) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRIMARY',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (portions > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${memberDishes.length} ${memberDishes.length == 1 ? "dish" : "dishes"} assigned ($portions ${portions == 1 ? "portion" : "portions"})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ),
                        if (dietary.isNotEmpty)
                          Text(
                            'Diet: ${dietary.join(", ")}',
                            style: const TextStyle(fontSize: 11, color: AppColors.slate700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          allergies.isEmpty ? 'No documented allergies' : '⚠️ Allergies: ${allergies.join(", ")}',
                          style: TextStyle(
                            fontSize: 11,
                            color: allergies.isEmpty ? AppColors.slate500 : AppColors.danger,
                            fontWeight: allergies.isEmpty ? FontWeight.normal : FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssignedChefCard() {
    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Assigned Certified Chef',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showChefSelectionSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_rounded, size: 13, color: AppColors.primaryDark),
                      SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.slate200),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySubtle,
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChefName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Verified for Hygiene, Nutrition & Culinary Excellence',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                        SizedBox(width: 2),
                        Text('4.9 (120+ visits)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                        SizedBox(width: 8),
                        Icon(Icons.timer_outlined, color: AppColors.slate500, size: 13),
                        SizedBox(width: 2),
                        Text('ETA ~25-35 mins', style: TextStyle(fontSize: 11, color: AppColors.slate600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsCard() {
    final occasion = widget.bookingConfig['occasion']?.toString().replaceAll('_', ' & ') ?? 'Lunch';
    final serviceDate = widget.bookingConfig['serviceDate']?.toString() ?? 'Today';
    final cookTime = _quote?.cookingTimeMinutes ?? 35;

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Chef Arrival & Kitchen Address',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AT-HOME CHEF',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Certified chef arrives 15-20 mins before cooking time',
            style: TextStyle(fontSize: 11, color: AppColors.slate500),
          ),
          const Divider(height: 18, color: AppColors.slate200),

          // Meal Occasion & Time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.amber50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: AppColors.amber700, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cooking Slot & Meal Time', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                    Text(
                      '$occasion • $serviceDate (~$cookTime mins live cook)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kitchen / Service Address with Change Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        const Text('Kitchen Address', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                        if (_selectedAddress != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.slate200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _selectedAddress!.label.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentAddressLine.isNotEmpty ? _currentAddressLine : 'Select your kitchen address',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.slate800, fontWeight: FontWeight.w600),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _selectOrChangeAddress,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.primarySubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDishesCard(List<dynamic> dishes) {
    final isAssigned = widget.bookingConfig['bookingFlow'] == 'ASSIGNED_MEAL';

    // Group dishes by member name - keep exact references
    final Map<String, List<Map<String, dynamic>>> dishesByMember = {};
    for (final raw in dishes) {
      if (raw is Map) {
        final d = (raw is Map<String, dynamic>) ? raw : Map<String, dynamic>.from(raw);
        final member = d['memberName']?.toString() ?? _currentMemberName;
        dishesByMember.putIfAbsent(member, () => []).add(d);
      }
    }

    final totalPortions = dishes.fold<int>(0, (sum, d) => sum + ((d['servings'] as num?)?.toInt() ?? 1));

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Menu (${dishes.length} ${dishes.length == 1 ? "Dish" : "Dishes"}, $totalPortions Portions)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Personalized for ${dishesByMember.keys.length} family ${dishesByMember.keys.length == 1 ? "member" : "members"}',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showAddMoreDishesOptions,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.primaryDark),
                      SizedBox(width: 3),
                      Text(
                        'Add Dishes',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.slate200),

          ...dishesByMember.entries.map((entry) {
            final memberName = entry.key;
            final memberDishes = entry.value;

            final memberSubtotal = memberDishes.fold<double>(
              0.0,
              (sum, d) =>
                  sum +
                  (((d['servings'] as num?)?.toInt() ?? 1) *
                      (isAssigned ? 0.0 : ((d['unitPrice'] as num?)?.toDouble() ?? 120.0))),
            );
            final memberPortions = memberDishes.fold<int>(
              0,
              (sum, d) => sum + ((d['servings'] as num?)?.toInt() ?? 1),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dishes for $memberName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${memberDishes.length} ${memberDishes.length == 1 ? "dish" : "dishes"} • $memberPortions ${memberPortions == 1 ? "portion" : "portions"}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.slate200),
                  const SizedBox(height: 6),
                  ...memberDishes.map((d) {
                    final name = d['name']?.toString() ?? 'Recipe';
                    final servings = (d['servings'] as num?)?.toInt() ?? 1;
                    final cookTime = (d['baseCookTimeMin'] as num?)?.toInt() ?? 20;
                    final unitPrice = isAssigned ? 0.0 : ((d['unitPrice'] as num?)?.toDouble() ?? 120.0);
                    final lineTotal = servings * unitPrice;

                    final lower = name.toLowerCase();
                    final isVeg = !['chicken', 'mutton', 'fish', 'prawn', 'meat', 'egg', 'pork'].any((w) => lower.contains(w));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          _buildVegIndicator(isVeg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showDishQuantitySheet(d),
                              borderRadius: BorderRadius.circular(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800),
                                    maxLines: 3,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '~$cookTime mins',
                                        style: const TextStyle(fontSize: 10.5, color: AppColors.slate500),
                                      ),
                                      const Text(' • ', style: TextStyle(fontSize: 10.5, color: AppColors.slate400)),
                                      Flexible(
                                        child: Text(
                                          unitPrice > 0 ? '₹${unitPrice.toStringAsFixed(0)}/portion' : 'Plan Covered',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: unitPrice > 0 ? AppColors.slate600 : AppColors.successDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Stepper: [-] qty [+]
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _updateDishQuantity(d, servings - 1),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                                    child: Icon(
                                      servings <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                      size: 14,
                                      color: servings <= 1 ? AppColors.danger : AppColors.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    '$servings',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _updateDishQuantity(d, servings + 1),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                                    child: Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 48,
                            child: Text(
                              lineTotal > 0 ? '₹${lineTotal.toStringAsFixed(0)}' : 'FREE',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: lineTotal > 0 ? AppColors.slate900 : AppColors.successDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _updateDishQuantity(d, 0),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 5),
                            Text(
                              'Total for $memberName',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate800),
                            ),
                          ],
                        ),
                        Text(
                          memberSubtotal > 0
                              ? '₹${memberSubtotal.toStringAsFixed(0)} ($memberPortions ${memberPortions == 1 ? "portion" : "portions"})'
                              : 'Covered by Plan ($memberPortions ${memberPortions == 1 ? "portion" : "portions"})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: memberSubtotal > 0 ? AppColors.primaryDark : AppColors.successDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          // Clean Menu Total Strip
          Builder(
            builder: (context) {
              final totalDishesSubtotal = dishes.fold<double>(
                0.0,
                (sum, d) =>
                    sum +
                    (((d['servings'] as num?)?.toInt() ?? 1) *
                        (isAssigned ? 0.0 : ((d['unitPrice'] as num?)?.toDouble() ?? 120.0))),
              );

              return Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Pantry Total (${dishes.length} dishes, $totalPortions portions)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                        ),
                      ],
                    ),
                    Text(
                      totalDishesSubtotal > 0 ? '₹${totalDishesSubtotal.toStringAsFixed(0)}' : 'Plan Covered',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: totalDishesSubtotal > 0 ? AppColors.slate900 : AppColors.successDark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddMoreDishesOptions,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Add More Dishes to Booking',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withOpacity(0.4), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppColors.primarySubtle.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChefNotesCard() {
    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Chef Cooking Notes & Preferences',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _chefNotesController,
            style: const TextStyle(fontSize: 13, color: AppColors.slate900, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. Mild spice, use olive oil, less salt...',
              hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate300),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _quickCookingNotes.map((note) {
              return InkWell(
                onTap: () => _addQuickNote(note),
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Text(
                    '+ $note',
                    style: const TextStyle(fontSize: 11, color: AppColors.slate700, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsListCard() {
    if (_isFreeChefBooking) {
      return const SizedBox.shrink();
    }
    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with modern Coupon Icon Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offers & Coupons',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Apply coupon for instant savings',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_appliedCoupon != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _appliedCoupon!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (_appliedCoupon != null) ...[
            // Applied Coupon Ticket Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _appliedCoupon!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'APPLIED',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You save ₹${_couponDiscount.toStringAsFixed(0)} on this chef visit!',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _removeCoupon,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'REMOVE',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Modern Coupon Code Input Field
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200, width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 8, right: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, size: 16, color: AppColors.primary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.slate900,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          letterSpacing: 0,
                          color: AppColors.slate400,
                          fontWeight: FontWeight.w500,
                        ),
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (val) => _applyCouponCode(val),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _applyCouponCode(_couponController.text),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: const Text(
                            'APPLY',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Top Offer Ticket Preview (Quick 1-Tap Apply)
            if (_availableOffers.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Emerald Left Accent Strip
                        Container(
                          width: 4,
                          color: AppColors.primary,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.percent_rounded, color: AppColors.primary, size: 17),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _availableOffers.first['code'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: AppColors.primaryDark,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _availableOffers.first['badge'] as String,
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _availableOffers.first['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => _applyCouponCode(
                                      _availableOffers.first['code'] as String,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                      child: const Text(
                                        'APPLY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // View all available offers link
            InkWell(
              onTap: _showOffersBottomSheet,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate200.withOpacity(0.7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'View all ${_availableOffers.length} available offers & coupons',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(QuoteModel q, List<dynamic> dishes) {
    final isAssigned = widget.bookingConfig['bookingFlow'] == 'ASSIGNED_MEAL';

    // Group dishes by member name and calculate totals
    final Map<String, double> memberDishTotals = {};
    final Map<String, int> memberPortionTotals = {};
    for (final raw in dishes) {
      if (raw is Map) {
        final d = Map<String, dynamic>.from(raw);
        final member = d['memberName']?.toString() ?? _currentMemberName;
        final servings = (d['servings'] as num?)?.toInt() ?? 1;
        final unitPrice = isAssigned ? 0.0 : ((d['unitPrice'] as num?)?.toDouble() ?? 120.0);
        final lineTotal = servings * unitPrice;
        memberDishTotals[member] = (memberDishTotals[member] ?? 0.0) + lineTotal;
        memberPortionTotals[member] = (memberPortionTotals[member] ?? 0) + servings;
      }
    }
    final totalPortions = memberPortionTotals.values.fold<int>(0, (sum, p) => sum + p);

    return EbicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Bill Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Item total, chef cooking fee & taxes',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BILL SUMMARY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.slate200),

          // Dishes / Ingredient Charges
          _buildPriceRow(
            'Dishes & Ingredients ($totalPortions portions)',
            q.itemCharges > 0
                ? '₹${q.itemCharges.toStringAsFixed(0)}'
                : (isAssigned ? 'FREE (Covered by Plan)' : '₹0'),
            isBenefit: isAssigned && q.itemCharges == 0,
          ),

          // Member itemized sub-breakdown (shown only when multiple members participate)
          if (memberDishTotals.length > 1)
            Container(
              margin: const EdgeInsets.only(left: 6, top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.people_alt_rounded, size: 13, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text(
                        'Dish Cost Breakdown by Family Member:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...memberDishTotals.entries.map((e) {
                    final mName = e.key;
                    final mTotal = e.value;
                    final mPortions = memberPortionTotals[mName] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('↳ ', style: TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.bold)),
                              Text(
                                '$mName ($mPortions ${mPortions == 1 ? "portion" : "portions"})',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.slate700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Text(
                            mTotal > 0 ? '₹${mTotal.toStringAsFixed(0)}' : 'Plan Covered',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: mTotal > 0 ? AppColors.slate800 : AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Home Chef Visit Fee
          _buildPriceRow('Chef Visit & Live Cooking Fee', '₹${q.chefServiceCharge.toStringAsFixed(0)}'),

          // Health Pass Free Visit Benefit
          if (q.healthPassBenefit > 0)
            _buildPriceRow('Health Pass Benefit', '-₹${q.healthPassBenefit.toStringAsFixed(0)}', isBenefit: true),

          // Promotional Voucher Discount
          if (!_isFreeChefBooking && (q.discount > 0 ? q.discount : _couponDiscount) > 0)
            _buildPriceRow(
              _appliedCoupon != null ? 'Coupon Discount ($_appliedCoupon)' : 'Coupon Discount',
              '-₹${(q.discount > 0 ? q.discount : _couponDiscount).toStringAsFixed(0)}',
              isDiscount: true,
            ),

          // Statutory Tax
          _buildPriceRow('Taxes & Govt. GST (5%)', '₹${q.tax.toStringAsFixed(0)}'),

          const Divider(height: 22, color: AppColors.slate200),

          // Final Amount Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount to Pay',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inclusive of all taxes & charges',
                        style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${q.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isDiscount = false, bool isBenefit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isBenefit ? AppColors.primaryDark : AppColors.slate800,
                fontWeight: isBenefit ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isBenefit
                  ? AppColors.primary
                  : isDiscount
                      ? AppColors.successDark
                      : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSafetyStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _TrustPill(icon: Icons.verified_user_rounded, text: 'Certified Chefs'),
          _TrustPill(icon: Icons.sanitizer_rounded, text: 'Hygienic Prep'),
          _TrustPill(icon: Icons.replay_rounded, text: '100% Guaranteed'),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gavel_rounded, size: 16, color: AppColors.slate700),
              SizedBox(width: 8),
              Text(
                'Chef Booking Terms & Conditions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPolicyBullet(
            icon: Icons.check_circle_outline_rounded,
            title: 'Free Cancellation',
            subtitle: '100% refund if cancelled at least 2 hours before scheduled chef arrival time.',
          ),
          const SizedBox(height: 6),
          _buildPolicyBullet(
            icon: Icons.soup_kitchen_outlined,
            title: 'Kitchen & Cookware',
            subtitle: 'Host provides basic cookware, stove and running water. Chef brings sanitized knives & apron.',
          ),
          const SizedBox(height: 6),
          _buildPolicyBullet(
            icon: Icons.verified_outlined,
            title: 'Hygiene & Verification',
            subtitle: 'All chefs undergo thorough criminal background checks and mandatory medical health certifications.',
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showFullTermsModal,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Read Full Terms & Service Policies',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBullet({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate700, height: 1.3),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate900)),
                TextSpan(text: subtitle),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFullTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chef Service Terms & Policies',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.slate200),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TermsSection(
                        title: '1. Service Scope & Live Cooking',
                        body: 'Our certified home chefs prepare the selected meals live inside your home kitchen. The estimated cooking duration is dynamically calculated based on the number of portions and complexity of recipes. Chefs prepare only items ordered in the confirmed booking.',
                      ),
                      SizedBox(height: 14),
                      _TermsSection(
                        title: '2. Cancellation & Rescheduling',
                        body: '• Free cancellation up to 2 hours prior to scheduled arrival time with 100% refund.\n• Cancellations within 2 hours of arrival window incur a 50% chef dispatch fee.\n• No refunds are permitted once the chef has arrived at your residence.',
                      ),
                      SizedBox(height: 14),
                      _TermsSection(
                        title: '3. Kitchen Readiness & Safety',
                        body: 'The customer is responsible for providing a clean cooking environment, functional stove or cooktop, running water, basic cookware, and basic seasoning/oil as required by the chosen dishes.',
                      ),
                      SizedBox(height: 14),
                      _TermsSection(
                        title: '4. Ingredients & Portions',
                        body: 'Meal portions adhere to standardized clinical nutrition weight metrics. Any extra portions requested directly to the chef on-site will be billed through the app.',
                      ),
                      SizedBox(height: 14),
                      _TermsSection(
                        title: '5. Hygiene, Conduct & Trust Guarantee',
                        body: 'All chefs hold valid FSSAI food handler certificates and background verifications. In the rare event of food dissatisfaction or non-arrival, our 100% satisfaction guarantee ensures immediate replacement or full refund.',
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('I Understand & Agree', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyBottomCheckout(QuoteModel q, List<dynamic> dishes) {
    final totalPortions = dishes.fold<int>(0, (sum, d) => sum + ((d['servings'] as num?)?.toInt() ?? 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '₹${q.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalPortions ${totalPortions == 1 ? "portion" : "portions"} • Incl. taxes & fees',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _proceedToPayment,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                q.total == 0.0 ? 'Confirm Booking' : 'Proceed to Pay',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVegIndicator(bool isVeg) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;

  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4)),
      ],
    );
  }
}

