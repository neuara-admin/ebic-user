import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/razorpay_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Sections 46 & 47: Health Pass Renewal Screen
class HealthPassRenewalScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassRenewalScreen({super.key, required this.arguments});

  @override
  State<HealthPassRenewalScreen> createState() => _HealthPassRenewalScreenState();
}

class _HealthPassRenewalScreenState extends State<HealthPassRenewalScreen> {
  final HealthPassRepository _repository = HealthPassRepository();
  final ApiClient _api = ApiClient();

  late String _healthPassId;
  late String _planCode;
  late String _planName;

  int _selectedDurationMonths = 3;
  final Set<String> _selectedMemberIds = {};
  List<HouseholdMemberModel> _householdMembers = [];
  HealthPassQuoteModel? _renewalQuote;

  bool _isLoading = true;
  bool _isQuoting = false;
  bool _isRenewing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _healthPassId = widget.arguments['healthPassId']?.toString() ?? '';
    _planCode = widget.arguments['planCode']?.toString() ?? 'CARE_V1';
    _planName = widget.arguments['planName']?.toString() ?? 'EBIC Care';

    AnalyticsService().logHealthPassRenewalStarted(_healthPassId);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        _householdMembers = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Default select household members
        for (final m in _householdMembers) {
          _selectedMemberIds.add(m.id);
        }
      }

      await _refreshRenewalQuote();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshRenewalQuote() async {
    if (_selectedMemberIds.isEmpty) return;
    setState(() => _isQuoting = true);
    try {
      final quote = await _repository.quoteRenewal(
        healthPassId: _healthPassId,
        planCode: _planCode,
        durationMonths: _selectedDurationMonths,
        memberIds: _selectedMemberIds.toList(),
      );
      if (mounted) {
        setState(() {
          _renewalQuote = quote;
          _isQuoting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isQuoting = false);
    }
  }

  Future<void> _submitRenewal() async {
    if (_renewalQuote == null) return;

    setState(() {
      _isRenewing = true;
      _errorMessage = null;
    });

    try {
      final idempotencyKey = 'hp_ren_${_healthPassId}_${DateTime.now().millisecondsSinceEpoch}';
      final draft = await _repository.createRenewal(
        healthPassId: _healthPassId,
        planCode: _planCode,
        durationMonths: _selectedDurationMonths,
        memberIds: _selectedMemberIds.toList(),
        idempotencyKey: idempotencyKey,
      );

      final newPassId = draft['id']?.toString() ?? _healthPassId;
      final selectedMembersList = _householdMembers.where((m) => _selectedMemberIds.contains(m.id)).toList();
      final totalAmount = _renewalQuote!.finalAmount;

      // Option 1: Direct 1-Tap Razorpay Checkout
      final payIdempotencyKey = 'pay_hp_${newPassId}_${DateTime.now().millisecondsSinceEpoch}';
      AnalyticsService().logHealthPassPaymentStarted(newPassId);

      final initRes = await _repository.initiatePayment(
        healthPassId: newPassId,
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
          amountPaise: (initRes['amountPaise'] as num?) ?? (totalAmount * 100),
          currency: initRes['currency']?.toString() ?? 'INR',
          name: 'EBIC Health Pass Renewal',
          description: '$_planName (${_selectedDurationMonths}M)',
        );

        if (!checkoutRes.isSuccess) {
          throw Exception(checkoutRes.errorMessage ?? 'Renewal payment cancelled or incomplete.');
        }

        gatewayPaymentId = checkoutRes.paymentId!;
        gatewaySignature = checkoutRes.signature!;
      } else {
        gatewayPaymentId = 'pay_sim_${DateTime.now().millisecondsSinceEpoch}';
        gatewaySignature = 'sig_sim_verified';
      }

      // Verify payment & activate renewed pass
      await _repository.verifyPayment(
        healthPassId: newPassId,
        gatewayPaymentId: gatewayPaymentId,
        gatewaySignature: gatewaySignature,
        idempotencyKey: payIdempotencyKey,
      );

      AnalyticsService().logHealthPassRenewalCompleted(newPassId);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.healthPassActivation,
          arguments: {
            'healthPassId': newPassId,
            'planName': _planName,
            'durationMonths': _selectedDurationMonths,
            'members': selectedMembersList,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isRenewing = false;
        });
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
        title: Text('Renew $_planName'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Renewal Banner (Section 70)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate900 : AppColors.primarySubtle.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.slate800 : AppColors.primarySubtle),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.autorenew_rounded, color: AppColors.primary, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Renewing extends your current coverage without service interruption. You can adjust duration or covered members.',
                                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate200 : AppColors.primaryDark, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Choose Duration (Section 71)
                          const Text(
                            'SELECT RENEWAL DURATION',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [1, 3, 6, 12].map((months) {
                              final isSelected = _selectedDurationMonths == months;
                              return Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedDurationMonths = months);
                                    _refreshRenewalQuote();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? AppColors.emerald700.withOpacity(0.2) : AppColors.emerald50)
                                          : (isDark ? AppColors.slate900 : Colors.white),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$months M',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? AppColors.primary : (isDark ? Colors.white : AppColors.slate900),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          months == 1 ? '1 mo' : '$months mos',
                                          style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Covered Members (Section 72)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COVERED HOUSEHOLD MEMBERS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.8),
                              ),
                              Text(
                                '${_selectedMemberIds.length} Selected',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: _householdMembers.map((m) {
                              final isSelected = _selectedMemberIds.contains(m.id);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (isSelected && _selectedMemberIds.length > 1) {
                                      _selectedMemberIds.remove(m.id);
                                    } else if (!isSelected) {
                                      _selectedMemberIds.add(m.id);
                                    }
                                  });
                                  _refreshRenewalQuote();
                                },
                                title: Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.slate900)),
                                subtitle: Text(m.relationship, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Dynamic Renewal Quote
                          if (_renewalQuote != null) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.slate900 : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                        const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Renewal Tax Invoice',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : AppColors.slate900,
                                                  ),
                                                ),
                                              ),
                                              if (_isQuoting) ...[
                                                const SizedBox(width: 6),
                                                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySubtle,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'RENEWAL',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryDark,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Items
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _priceRow('Base Renewal Subscription', '₹${_renewalQuote!.subtotal.toInt()}', isDark),
                                        if (_renewalQuote!.memberCharges > 0)
                                          _priceRow('Additional Members', '+₹${_renewalQuote!.memberCharges.toInt()}', isDark),
                                        if (_renewalQuote!.memberDiscount > 0)
                                          _priceRow('Member Discount', '-₹${_renewalQuote!.memberDiscount.toInt()}', isDark, color: AppColors.emerald700),
                                        if (_renewalQuote!.durationDiscount > 0)
                                          _priceRow('Duration Commitment Discount', '-₹${_renewalQuote!.durationDiscount.toInt()}', isDark, color: AppColors.emerald700),
                                        if (_renewalQuote!.platformFee > 0)
                                          _priceRow('Platform Fee', '+₹${_renewalQuote!.platformFee.toInt()}', isDark),
                                        if (_renewalQuote!.otherCharges > 0)
                                          _priceRow('Other Charges', '+₹${_renewalQuote!.otherCharges.toInt()}', isDark),
                                        if (_renewalQuote!.tax > 0)
                                          _priceRow(
                                            _renewalQuote!.gstPercent > 0
                                                ? 'GST & Taxes (${_renewalQuote!.gstPercent.toInt()}%)'
                                                : 'GST & Taxes',
                                            '+₹${_renewalQuote!.tax.toInt()}',
                                            isDark,
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Dashed separator
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: List.generate(
                                        26,
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

                                  // Total box
                                  Padding(
                                    padding: const EdgeInsets.all(16),
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
                                                'Renewal Total Payable',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white : AppColors.slate900,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Includes all applicable taxes & GST',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, color: AppColors.slate500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${_renewalQuote!.finalAmount.toInt()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Button Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900 : Colors.white,
                      border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200)),
                    ),
                    child: EbicButton(
                label: _renewalQuote != null ? 'Pay ₹${_renewalQuote!.finalAmount.toInt()} & Renew' : 'Renew Pass',
                      isLoading: _isRenewing,
                      onPressed: _renewalQuote == null || _isQuoting ? null : _submitRenewal,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _priceRow(String label, String value, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate600)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? (isDark ? Colors.white : AppColors.slate800))),
        ],
      ),
    );
  }
}
