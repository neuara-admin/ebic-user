import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/analytics/analytics_service.dart';
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

  @override
  void initState() {
    super.initState();
    _plan = widget.arguments['plan'] as HealthPassPlanModel;
    _durationMonths = widget.arguments['durationMonths'] as int;
    _memberIds = (widget.arguments['memberIds'] as List<dynamic>).map((e) => e.toString()).toList();
    _members = (widget.arguments['members'] as List<dynamic>).cast<HouseholdMemberModel>();
    _quote = widget.arguments['quote'] as HealthPassQuoteModel;
    AnalyticsService().logHealthPassQuoteRequested(_plan.code);
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  HealthPassQuoteModel get _effectiveQuote => _recalculatedQuote ?? _quote;
  double get _finalTotal => _effectiveQuote.finalAmount;

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
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
        final disc = double.tryParse(res['promotionDiscount']?.toString() ?? pb['promotionDiscount']?.toString() ?? '0') ?? 0.0;
        final tax = double.tryParse(res['tax']?.toString() ?? pb['tax']?.toString() ?? '0') ?? _quote.tax;
        final finalAmt = double.tryParse(res['finalAmount']?.toString() ?? pb['finalAmount']?.toString() ?? '0') ?? max(0, _quote.finalAmount - disc);

        setState(() {
          _appliedCoupon = code.toUpperCase();
          _couponDiscount = disc;
          _recalculatedQuote = HealthPassQuoteModel(
            planCode: _quote.planCode,
            memberCount: _quote.memberCount,
            durationMonths: _quote.durationMonths,
            subtotal: _quote.subtotal,
            memberCharges: _quote.memberCharges,
            memberDiscount: _quote.memberDiscount,
            durationDiscount: _quote.durationDiscount,
            promotionDiscount: disc,
            platformFee: _quote.platformFee,
            otherCharges: _quote.otherCharges,
            gstPercent: _quote.gstPercent,
            tax: tax,
            finalAmount: finalAmt,
          );
          _isApplyingCoupon = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon "$code" applied! Saved ₹${disc.toInt()}.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isApplyingCoupon = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Failed to apply coupon.')),
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
                                      '$_durationMonths ${_durationMonths == 1 ? 'Month' : 'Months'} Subscription',
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
                                  '$_durationMonths Months validity begins upon first completed consultation',
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
                                  'COVERED HOUSEHOLD MEMBERS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_members.length} Members',
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

                    // Promo Code Card
                    EbicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HAVE A COUPON OR PROMO CODE?',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          if (_appliedCoupon != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_offer, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Coupon "$_appliedCoupon" applied (-₹${_couponDiscount.toInt()})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _removeCoupon,
                                  child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter promo code (e.g. HEALTH50)',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 96,
                                  child: EbicButton(
                                    label: 'Apply',
                                    isFullWidth: true,
                                    isLoading: _isApplyingCoupon,
                                    onPressed: _applyCoupon,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Official Tax Invoice & Price Summary Breakdown
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
                            'I agree to the EBIC Health Pass Membership Terms, anniversary entitlement reset policy, and cancellation guidelines.',
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
                        'Tax Invoice & Bill Summary',
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
                        'GST INVOICE',
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
                  title: 'Base Subscription Fee',
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
                    title: 'Family Group Savings',
                    subtitle: 'Multi-member discount benefit',
                    amount: '-₹${q.memberDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.durationDiscount > 0)
                  _invoiceItemRow(
                    title: 'Plan Term Savings',
                    subtitle: '$_durationMonths-Month upfront commitment discount',
                    amount: '-₹${q.durationDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.promotionDiscount > 0)
                  _invoiceItemRow(
                    title: 'Promotional Coupon Discount',
                    subtitle: _appliedCoupon != null ? 'Promo code: $_appliedCoupon' : 'Special voucher applied',
                    amount: '-₹${q.promotionDiscount.toInt()}',
                    isDark: isDark,
                    isDeduction: true,
                  ),
                if (q.platformFee > 0)
                  _invoiceItemRow(
                    title: 'Platform & Care Coordination Fee',
                    subtitle: 'Digital nutrition charting & dietitian concierge',
                    amount: '+₹${q.platformFee.toInt()}',
                    isDark: isDark,
                  ),
                if (q.otherCharges > 0)
                  _invoiceItemRow(
                    title: 'Administrative & Service Charges',
                    amount: '+₹${q.otherCharges.toInt()}',
                    isDark: isDark,
                  ),
                if (q.tax > 0)
                  _invoiceItemRow(
                    title: 'Goods & Services Tax (GST)',
                    subtitle: q.gstPercent > 0
                        ? 'Applicable statutory tax @ ${q.gstPercent.toInt()}%'
                        : 'Applicable statutory taxes',
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
                        'Total Amount Payable',
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
                        'Incl. of all taxes & GST',
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
}
