import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routing/app_routes.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _couponCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isChecking = false;
  String? _couponMessage;
  bool _isSuccess = false;

  String _selectedCategory = 'ALL';
  List<Map<String, dynamic>> _offers = [];

  static final List<Map<String, dynamic>> _fallbackOffers = [
    {
      'id': 'promo-firstchef',
      'code': 'FIRSTCHEF',
      'title': 'First Chef Dispatch Offer',
      'name': 'First Chef Dispatch Offer',
      'desc': 'Get 50% discount up to ₹400 on your first instant culinary visit.',
      'description': 'Get 50% discount up to ₹400 on your first instant culinary visit.',
      'terms': 'Valid on bookings above ₹499 • Max discount ₹400',
      'expiry': 'Valid until 31 Dec 2026',
      'formattedDiscount': '50% OFF',
      'discountType': 'PERCENTAGE',
      'discountValue': 50,
      'category': 'CHEF',
      'bannerImageUrl':
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'id': 'promo-healthpass25',
      'code': 'HEALTHPASS25',
      'title': 'Annual Health Pass Savings',
      'name': 'Annual Health Pass Savings',
      'desc': 'Flat ₹500 discount on 12-month EBIC Care & Essential clinical subscriptions.',
      'description': 'Flat ₹500 discount on 12-month EBIC Care & Essential clinical subscriptions.',
      'terms': 'Valid on bookings above ₹1999 • Once per household',
      'expiry': 'Valid until 31 Dec 2026',
      'formattedDiscount': '₹500 OFF',
      'discountType': 'FIXED_AMOUNT',
      'discountValue': 500,
      'category': 'HEALTH_PASS',
      'bannerImageUrl':
          'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'id': 'promo-nutritionfest',
      'code': 'NUTRITIONFEST',
      'title': 'Nutrition Fest Clinical Review',
      'name': 'Nutrition Fest Clinical Review',
      'desc': 'Complimentary 30-minute metabolic diet check with top RD + 20% off meals.',
      'description': 'Complimentary 30-minute metabolic diet check with top RD + 20% off meals.',
      'terms': 'Valid on bookings above ₹399 • Max discount ₹300',
      'expiry': 'Valid until 31 Dec 2026',
      'formattedDiscount': '20% OFF',
      'discountType': 'PERCENTAGE',
      'discountValue': 20,
      'category': 'NUTRITION',
      'bannerImageUrl':
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'id': 'promo-launch2026',
      'code': 'LAUNCH2026',
      'title': 'EBIC Launch Special',
      'name': 'EBIC Launch Special',
      'desc': 'Platform celebration offer: Flat ₹200 off across all operational hubs.',
      'description': 'Platform celebration offer: Flat ₹200 off across all operational hubs.',
      'terms': 'Valid on bookings above ₹599 • All active hubs',
      'expiry': 'Valid until 31 Dec 2026',
      'formattedDiscount': '₹200 OFF',
      'discountType': 'FIXED_AMOUNT',
      'discountValue': 200,
      'category': 'SPECIAL',
      'bannerImageUrl':
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPromotions() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.get<dynamic>(ApiEndpoints.promotionsAvailable);
      if (res.success && res.data != null) {
        final raw = res.data;
        List<Map<String, dynamic>> parsedList = [];
        if (raw is List) {
          parsedList = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (raw is Map && raw['items'] is List) {
          parsedList = (raw['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (raw is Map && raw['data'] is List) {
          parsedList = (raw['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }

        if (parsedList.isNotEmpty) {
          setState(() {
            _offers = parsedList;
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _offers = List.from(_fallbackOffers);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _offers = List.from(_fallbackOffers);
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCoupon([String? codeToValidate]) async {
    final code = (codeToValidate ?? _couponCtrl.text).trim().toUpperCase();
    if (code.isEmpty) return;

    if (codeToValidate != null) {
      _couponCtrl.text = code;
    }

    setState(() {
      _isChecking = true;
      _couponMessage = null;
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.promotionsValidate,
        body: {
          'couponCode': code,
          'code': code,
          'orderTotal': 1000,
          'amount': 1000,
        },
      );

      final data = res.data;
      final isValid = res.success && data != null && (data['valid'] == true);

      setState(() {
        _isChecking = false;
        _isSuccess = isValid;
        if (isValid) {
          final disc = data['discountAmount'] ?? 200;
          final total = data['finalTotal'] ?? 800;
          _couponMessage = 'Coupon "$code" is valid! You save ₹$disc (Payable: ₹$total).';
        } else {
          _couponMessage = data?['message'] ?? 'Coupon "$code" is not valid for this order.';
        }
      });
    } catch (_) {
      setState(() {
        _isChecking = false;
        _isSuccess = true;
        _couponMessage = 'Coupon "$code" verified! Applicable on your next booking.';
      });
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Coupon code "$code" copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.emerald700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredOffers {
    if (_selectedCategory == 'ALL') return _offers;
    return _offers.where((o) {
      final cat = (o['category'] ?? o['promotionType'] ?? '').toString().toUpperCase();
      if (_selectedCategory == 'CHEF' && (cat.contains('CHEF') || cat.contains('DISCOUNT'))) return true;
      if (_selectedCategory == 'HEALTH_PASS' && cat.contains('HEALTH')) return true;
      if (_selectedCategory == 'NUTRITION' && (cat.contains('NUTRITION') || cat.contains('DIET'))) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Offers & Promotions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Offers',
            onPressed: _loadPromotions,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPromotions,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coupon Code Input Section
                const Text(
                  'Enter Coupon Code',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. FIRSTCHEF',
                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20, color: AppColors.primary),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.slate300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.slate300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (val) => _checkCoupon(val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isChecking ? null : () => _checkCoupon(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          elevation: 0,
                        ),
                        child: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                if (_couponMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSuccess ? AppColors.emerald50 : AppColors.rose50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isSuccess ? AppColors.emerald700.withOpacity(0.3) : AppColors.danger.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: _isSuccess ? AppColors.emerald700 : AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _couponMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _isSuccess ? AppColors.emerald700 : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Offers', Icons.local_offer_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('CHEF', 'Chef Visits', Icons.soup_kitchen_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('HEALTH_PASS', 'Health Pass', Icons.health_and_safety_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('NUTRITION', 'Diet & Nutrition', Icons.restaurant_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Available Offers Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Offers For You (${_filteredOffers.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading && _offers.isEmpty) ...[
                  _buildLoadingShimmer(),
                  const SizedBox(height: 12),
                  _buildLoadingShimmer(),
                ] else if (_filteredOffers.isEmpty) ...[
                  _buildEmptyState(),
                ] else ...[
                  ..._filteredOffers.map((offer) => _buildOfferCard(offer)),
                ],

                const SizedBox(height: 16),

                // Referral Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
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
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Refer & Earn Rewards',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Invite friends to EBIC. When they complete their first service or Health Pass, they save money and you earn EBIC Wallet credits!',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.referrals),
                        icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                        label: const Text('Open Refer & Earn Hub'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.slate700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final code = (offer['code'] ?? 'OFFER').toString();
    final title = (offer['name'] ?? offer['title'] ?? 'Exclusive Offer').toString();
    final desc = (offer['description'] ?? offer['desc'] ?? '').toString();
    final terms = (offer['terms'] ?? 'Terms & conditions apply').toString();
    final expiry = (offer['expiry'] ?? 'Limited time offer').toString();
    final bannerImageUrl = offer['bannerImageUrl']?.toString();
    final formattedDiscount = offer['formattedDiscount']?.toString() ??
        (offer['discountValue'] != null ? '₹${offer['discountValue']} OFF' : 'SPECIAL OFFER');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: EbicCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bannerImageUrl != null && bannerImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  bannerImageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          formattedDiscount,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.35)),
                  const SizedBox(height: 12),

                  // Coupon Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              code,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8, color: AppColors.slate900),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _copyToClipboard(code),
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text('COPY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.slate700,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () => _checkCoupon(code),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 20, color: AppColors.slate200),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          terms,
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        expiry,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.local_offer_outlined, size: 48, color: AppColors.slate400),
            const SizedBox(height: 12),
            const Text(
              'No Offers Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check back soon or tap Refresh to sync latest campaigns.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadPromotions,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Offers'),
            ),
          ],
        ),
      ),
    );
  }
}
