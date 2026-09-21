import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/razorpay_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Sections 38 & 39: Health Pass Quote Review & Purchase Confirmation
class HealthPassQuoteReviewScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassQuoteReviewScreen({super.key, required this.arguments});

  @override
  State<HealthPassQuoteReviewScreen> createState() => _HealthPassQuoteReviewScreenState();
}

class _HealthPassQuoteReviewScreenState extends State<HealthPassQuoteReviewScreen> {
  final HealthPassRepository _repository = HealthPassRepository();
  final ApiClient _api = ApiClient();

  late HealthPassPlanModel _plan;
  late int _durationMonths;
  late List<String> _memberIds;
  late List<HouseholdMemberModel> _members;
  late HealthPassQuoteModel _quote;

  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;

  String? _draftPassId;
  HealthPassQuoteModel? _recalculatedQuote;

  bool _isSubmitting = false;
  bool _agreedToTerms = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _availableHealthPassOffers = [];
  bool _isLoadingOffers = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.arguments['plan'] as HealthPassPlanModel;
    _durationMonths = widget.arguments['durationMonths'] as int;
    _memberIds = (widget.arguments['memberIds'] as List<dynamic>).map((e) => e.toString()).toList();
    _members = (widget.arguments['members'] as List<dynamic>).cast<HouseholdMemberModel>();
    _quote = widget.arguments['quote'] as HealthPassQuoteModel;
    AnalyticsService().logHealthPassQuoteRequested(_plan.code);
    _loadAvailableHealthPassOffers();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableHealthPassOffers() async {
    setState(() => _isLoadingOffers = true);
    try {
      final res = await _api.get<dynamic>(
        ApiEndpoints.promotionsAvailable,
        queryParameters: {'serviceType': 'HEALTH_PASS'},
      );
      if (res.success && res.data != null) {
        final raw = res.data;
        List<Map<String, dynamic>> list = [];
        if (raw is List) {
          list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (raw is Map && raw['items'] is List) {
          list = (raw['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (mounted && list.isNotEmpty) {
          setState(() {
            _availableHealthPassOffers = list.map((p) {
              final val = (p['discountValue'] as num?)?.toDouble() ?? 0.0;
              return {
                'code': p['code']?.toString() ?? 'OFFER',
                'title': p['title']?.toString() ?? p['name']?.toString() ?? 'Special Offer',
                'desc': p['desc']?.toString() ?? p['description']?.toString() ?? p['terms']?.toString() ?? '',
                'discount': val,
                'badge': p['formattedDiscount']?.toString() ?? 'OFFER',
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load Health Pass promotions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOffers = false);
    }
  }

  HealthPassQuoteModel get _effectiveQuote => _recalculatedQuote ?? _quote;
  double get _finalTotal => _effectiveQuote.finalAmount;

  Future<void> _applyCoupon([String? explicitCode]) async {
    final code = (explicitCode ?? _couponController.text).trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingCoupon = true;
      _errorMessage = null;
    });

    try {
      if (_draftPassId == null) {
        final idempotencyKey = 'hp_pur_${DateTime.now().millisecondsSinceEpoch}';
        final draft = await _repository.purchaseDraft(
          planCode: _plan.code,
          durationMonths: _durationMonths,
          memberIds: _memberIds,
          idempotencyKey: idempotencyKey,
        );
        _draftPassId = draft['id']?.toString();
      }

      if (_draftPassId != null) {
        final res = await _repository.applyCoupon(_draftPassId!, code);
        final pb = (res['priceBreakdown'] as Map<String, dynamic>?) ?? res;
        final serverDisc = double.tryParse(pb['promotionDiscount']?.toString() ?? res['promotionDiscount']?.toString() ?? '0') ?? 0.0;
        final serverFinal = double.tryParse(pb['finalAmount']?.toString() ?? res['finalAmount']?.toString() ?? '0') ?? _quote.finalAmount;
        final serverTax = double.tryParse(pb['tax']?.toString() ?? res['tax']?.toString() ?? '0') ?? _quote.tax;

        if (serverDisc <= 0) {
          throw Exception('Coupon "$code" is not eligible or has expired.');
        }

        setState(() {
          _appliedCoupon = code;
          _couponDiscount = serverDisc;
          _recalculatedQuote = HealthPassQuoteModel(
            planCode: _quote.planCode,
            memberCount: _quote.memberCount,
            durationMonths: _quote.durationMonths,
            subtotal: _quote.subtotal,
            memberCharges: _quote.memberCharges,
            memberDiscount: _quote.memberDiscount,
            durationDiscount: _quote.durationDiscount,
            promotionDiscount: serverDisc,
            platformFee: _quote.platformFee,
            otherCharges: _quote.otherCharges,
            gstPercent: _quote.gstPercent,
            tax: serverTax,
            finalAmount: serverFinal,
          );
          _isApplyingCoupon = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primaryDark,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Coupon "$code" applied! Saved ₹${serverDisc.toInt()} on your pass.'),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        _isApplyingCoupon = false;
        _errorMessage = msg;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(msg.isNotEmpty ? msg : 'Invalid coupon code. Please try another.'),
          ),
        );
      }
    }
  }

  Future<void> _removeCoupon() async {
    if (_draftPassId != null) {
      try {
        await _repository.removeCoupon(_draftPassId!);
      } catch (_) {}
    }
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _recalculatedQuote = null;
      _couponController.clear();
    });
  }

  Future<void> _submitPurchase() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Health Pass membership terms to continue.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      AnalyticsService().logHealthPassPurchaseStarted(_plan.code);

      String passId;
      if (_draftPassId != null) {
        passId = _draftPassId!;
      } else {
        final idempotencyKey = 'hp_pur_${DateTime.now().millisecondsSinceEpoch}';
        final draft = await _repository.purchaseDraft(
          planCode: _plan.code,
          durationMonths: _durationMonths,
          memberIds: _memberIds,
          idempotencyKey: idempotencyKey,
        );
        passId = draft['id']?.toString() ?? '';
      }

      // Option 1: Direct 1-Tap Razorpay Checkout
      final payIdempotencyKey = 'pay_hp_${passId}_${DateTime.now().millisecondsSinceEpoch}';
      AnalyticsService().logHealthPassPaymentStarted(passId);

      final initRes = await _repository.initiatePayment(
        healthPassId: passId,
        method: 'GATEWAY',
        idempotencyKey: payIdempotencyKey,
      );

      String gatewayPaymentId;
      String gatewaySignature;

      if (initRes['status'] == 'SUCCEEDED') {
        gatewayPaymentId = initRes['gatewayRef']?.toString() ?? 'wallet_success';
        gatewaySignature = 'wallet_verified';
      } else if (initRes['gatewayOrderId'] != null && initRes['keyId'] != null) {
        final checkoutRes = await RazorpayService().openCheckout(
          keyId: initRes['keyId'].toString(),
          orderId: initRes['gatewayOrderId'].toString(),
          amountPaise: (initRes['amountPaise'] as num?) ?? (_finalTotal * 100),
          currency: initRes['currency']?.toString() ?? 'INR',
          name: 'EBIC Health Pass',
          description: '${_plan.name} (${_durationMonths}M)',
        );

        if (!checkoutRes.isSuccess) {
          throw Exception(checkoutRes.errorMessage ?? 'Payment cancelled or incomplete.');
        }

        gatewayPaymentId = checkoutRes.paymentId!;
        gatewaySignature = checkoutRes.signature!;
      } else {
        // Fallback simulation for local offline dev
        gatewayPaymentId = 'pay_sim_${DateTime.now().millisecondsSinceEpoch}';
        gatewaySignature = 'sig_sim_verified';
      }

      // Step 3: Authoritative Backend Payment Verification & Activation
      await _repository.verifyPayment(
        healthPassId: passId,
        gatewayPaymentId: gatewayPaymentId,
        gatewaySignature: gatewaySignature,
        idempotencyKey: payIdempotencyKey,
      );

      AnalyticsService().logHealthPassPurchaseCompleted(passId);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.healthPassActivation,
          arguments: {
            'isSuccess': true,
            'healthPassId': passId,
            'planName': _plan.name,
            'durationMonths': _durationMonths,
            'members': _members,
            'amountPaid': _finalTotal,
            'paymentId': gatewayPaymentId,
          },
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      AnalyticsService().logHealthPassPurchaseFailed(errorMsg);
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _isSubmitting = false;
        });
        Navigator.pushNamed(
          context,
          AppRoutes.healthPassActivation,
          arguments: {
            'isSuccess': false,
            'planName': _plan.name,
            'durationMonths': _durationMonths,
            'amountPaid': _finalTotal,
            'errorMessage': errorMsg,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Review & Confirm'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan & Duration Summary Card
                    EbicCard(
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
                                      _plan.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isDark ? Colors.white : AppColors.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_durationMonths ${_durationMonths == 1 ? 'Month' : 'Months'} Plan',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 24),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.schedule_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your $_durationMonths-month plan activates after your first dietitian consultation.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Covered Members Card
                    EbicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'COVERED FAMILY MEMBERS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_members.length} ${_members.length == 1 ? 'Member' : 'Members'}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _members.map((m) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${m.name} (${m.relationship})',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.slate800),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modern Offers & Coupons Card
                    if (_finalTotal > 0 || _appliedCoupon != null) ...[
                      _buildPromotionsCard(),
                      const SizedBox(height: 16),
                    ],

                    // Bill Summary Breakdown
                    _buildInvoiceCard(isDark),
                    const SizedBox(height: 16),

                    // Terms Checkbox
                    Row(
                      children: [
                        Checkbox(
                          activeColor: AppColors.primary,
                          value: _agreedToTerms,
                          onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Health Pass membership terms, benefits policy, and cancellation guidelines.',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate600, height: 1.3),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Confirmation Bar (Section 34)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200)),
              ),
              child: EbicButton(
                label: 'Pay ₹${_finalTotal.toInt()} & Activate',
                isLoading: _isSubmitting,
                onPressed: _submitPurchase,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(bool isDark) {
    final q = _effectiveQuote;
    final nowFormatted = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Invoice Header with Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800.withOpacity(0.5) : AppColors.slate50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bill Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date: $nowFormatted',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.emerald900.withOpacity(0.35) : AppColors.emerald50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.emerald700.withOpacity(0.5) : AppColors.emerald600.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 11,
                        color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'INCLUDES GST',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Plan Meta Sub-banner
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _plan.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Coverage: ${q.memberCount} ${q.memberCount == 1 ? 'Member' : 'Members'} • $_durationMonths ${_durationMonths == 1 ? 'Month' : 'Months'} Term',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_durationMonths}M Plan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16, thickness: 1),

          // 3. Itemized Bill Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _invoiceItemRow(
                  title: 'Plan Subscription',
                  subtitle: 'Primary covered member included',
                  amount: '₹${q.subtotal.toInt()}',
                  isDark: isDark,
                ),
                if (q.memberCharges > 0)
                  _invoiceItemRow(
                    title: 'Additional Family Members',
                    subtitle: '${q.memberCount - 1} additional ${q.memberCount - 1 == 1 ? 'member' : 'members'} covered',
                    amount: '+₹${q.memberCharges.toInt()}',
                    isDark: isDark,
                  ),
                if (q.memberDiscount > 0)
                  _invoiceItemRow(
                    title: 'Family Savings',
                    subtitle: 'Multi-member discount benefit',
                    amount: '-₹${q.memberDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.durationDiscount > 0)
                  _invoiceItemRow(
                    title: 'Plan Term Savings',
                    subtitle: '$_durationMonths-month plan savings',
                    amount: '-₹${q.durationDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.promotionDiscount > 0)
                  _invoiceItemRow(
                    title: 'Coupon Discount',
                    subtitle: _appliedCoupon != null ? 'Coupon "$_appliedCoupon" applied' : 'Voucher discount',
                    amount: '-₹${q.promotionDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.platformFee > 0)
                  _invoiceItemRow(
                    title: 'Platform & Service Fee',
                    subtitle: 'Dietitian concierge & care coordination',
                    amount: '+₹${q.platformFee.toInt()}',
                    isDark: isDark,
                  ),
                if (q.otherCharges > 0)
                  _invoiceItemRow(
                    title: 'Other Charges',
                    amount: '+₹${q.otherCharges.toInt()}',
                    isDark: isDark,
                  ),
                if (q.tax > 0)
                  _invoiceItemRow(
                    title: 'Taxes & GST (${q.gstPercent.toInt()}%)',
                    subtitle: 'Applicable statutory taxes',
                    amount: '+₹${q.tax.toInt()}',
                    isDark: isDark,
                  ),
              ],
            ),
          ),

          // 4. Custom Dashed Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: List.generate(
                30,
                (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 1.5,
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                  ),
                ),
              ),
            ),
          ),

          // 5. Total Payable Highlight Box
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.primarySubtle.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.primary.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Payable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Includes all taxes & GST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '₹${q.finalAmount.toInt()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // 6. Tax & Regulatory Note Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: AppColors.slate400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Official GST-compliant invoice will be issued upon payment and sent to your email.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceItemRow({
    required String title,
    String? subtitle,
    required String amount,
    required bool isDark,
    bool isDeduction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.slate800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: isDeduction
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                : EdgeInsets.zero,
            decoration: isDeduction
                ? BoxDecoration(
                    color: isDark ? AppColors.emerald900.withOpacity(0.35) : AppColors.emerald50,
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDeduction
                    ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                    : (isDark ? Colors.white : AppColors.slate900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOffersBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Pass Coupons',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: isDark ? Colors.white : AppColors.slate900),
                          ),
                          const Text(
                            'Tap apply to claim your discount',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? AppColors.slate400 : AppColors.slate600),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (_isLoadingOffers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_availableHealthPassOffers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No promotional offers currently available.',
                      style: TextStyle(
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ..._availableHealthPassOffers.map((offer) {
                  final isApplied = _appliedCoupon == offer['code'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isApplied
                          ? (isDark ? AppColors.emerald900.withOpacity(0.25) : AppColors.primarySubtle)
                          : (isDark ? AppColors.slate800 : AppColors.slate50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isApplied ? AppColors.primary : (isDark ? AppColors.slate700 : AppColors.slate200),
                        width: isApplied ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isApplied ? AppColors.primary : (isDark ? AppColors.emerald900.withOpacity(0.5) : const Color(0xFFD1FAE5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.confirmation_number_rounded,
                            color: isApplied ? Colors.white : AppColors.primary,
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
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.slate900),
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
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.slate800),
                              ),
                              Text(
                                offer['desc'] as String,
                                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        isApplied
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'APPLIED',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              )
                            : InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _applyCoupon(offer['code'] as String);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'APPLY',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
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

  Widget _buildPromotionsCard() {
    if (_finalTotal <= 0 && _appliedCoupon == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offers & Coupons',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.slate900),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Apply coupon for instant savings on your Health Pass',
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
                          'You save ₹${_couponDiscount.toInt()} on your Health Pass!',
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
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200, width: 1.2),
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
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white : AppColors.slate900,
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
                      onSubmitted: (val) => _applyCoupon(val),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _isApplyingCoupon ? null : () => _applyCoupon(_couponController.text),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: _isApplyingCoupon
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
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

            // Top Health Pass Offer Voucher Preview (Quick 1-Tap Apply)
            if (_availableHealthPassOffers.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.emerald900.withOpacity(0.18) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.emerald700.withOpacity(0.4) : const Color(0xFFA7F3D0), width: 1.2),
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
                                            _availableHealthPassOffers.first['code'] as String,
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
                                              _availableHealthPassOffers.first['badge'] as String,
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
                                        _availableHealthPassOffers.first['title'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.slate300 : AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () => _applyCoupon(
                                      _availableHealthPassOffers.first['code'] as String,
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
                  color: isDark ? AppColors.slate800 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200.withOpacity(0.7)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'View all available offers & coupons',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
