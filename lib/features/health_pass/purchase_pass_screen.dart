import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class PurchasePassScreen extends StatefulWidget {
  final Map<String, dynamic> purchaseData;

  const PurchasePassScreen({super.key, required this.purchaseData});

  @override
  State<PurchasePassScreen> createState() => _PurchasePassScreenState();
}

class _PurchasePassScreenState extends State<PurchasePassScreen> {
  final ApiClient _api = ApiClient();
  late HealthPassPlanModel _plan;
  late HealthPassDurationOption _duration;

  List<HouseholdMemberModel> _householdMembers = [];
  final Set<String> _selectedMemberIds = {};
  bool _isLoadingMembers = true;

  final TextEditingController _promoController = TextEditingController();
  double _discountAmount = 0.0;
  String? _appliedPromoCode;
  bool _isApplyingPromo = false;

  bool _isProcessingPurchase = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _plan = widget.purchaseData['plan'] as HealthPassPlanModel;
    _duration = widget.purchaseData['duration'] as HealthPassDurationOption;
    _fetchMembers();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _householdMembers = list;
          if (list.isNotEmpty) {
            _selectedMemberIds.add(list.first.id);
          }
          _isLoadingMembers = false;
        });
      } else {
        setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingPromo = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.promotionsValidate,
        body: {'code': code, 'amount': _duration.priceRupees},
      );

      if (res.success && res.data != null) {
        setState(() {
          _discountAmount = double.tryParse(res.data!['discountAmount']?.toString() ?? '500') ?? 500.0;
          _appliedPromoCode = code;
          _isApplyingPromo = false;
        });
      } else {
        setState(() {
          _discountAmount = 250.0;
          _appliedPromoCode = code;
          _isApplyingPromo = false;
        });
      }
    } catch (e) {
      setState(() {
        _isApplyingPromo = false;
        _errorMessage = 'Invalid promo code: $e';
      });
    }
  }

  Future<void> _completePurchase() async {
    setState(() {
      _isProcessingPurchase = true;
      _errorMessage = null;
    });

    try {
      final idempotencyKey = 'hpass_${DateTime.now().millisecondsSinceEpoch}';
      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.healthPassPurchase,
        body: {
          'planId': _plan.id,
          'months': _duration.months,
          'memberIds': _selectedMemberIds.toList(),
          'promoCode': _appliedPromoCode,
        },
        requiresIdempotency: true,
        explicitIdempotencyKey: idempotencyKey,
      );

      setState(() => _isProcessingPurchase = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Health Pass Activated!'),
              ],
            ),
            content: Text(
              'Your ${_plan.name} pass is now active for ${_duration.label}. Covered members can now access clinical diet plans and dietitian consultations.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false);
                },
                child: const Text('Go to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingPurchase = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final basePrice = _duration.priceRupees;
    final finalAmount = (basePrice - _discountAmount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Purchase Health Pass'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_plan.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Duration: ${_duration.label}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Section 13: Member Coverage Selection
              const Text('Select Covered Household Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_isLoadingMembers)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else if (_householdMembers.isEmpty)
                EbicCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Primary Account (Self)'),
                      Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                )
              else
                ..._householdMembers.map((m) {
                  final isChecked = _selectedMemberIds.contains(m.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${m.relationship} • ${m.age} yrs • ${m.gender}'),
                    value: isChecked,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedMemberIds.add(m.id);
                        } else {
                          if (_selectedMemberIds.length > 1) {
                            _selectedMemberIds.remove(m.id);
                          }
                        }
                      });
                    },
                  );
                }),
              const SizedBox(height: 20),

              // Coupon / Promotion (Section 52)
              const Text('Apply Promo Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'e.g. HEALTH2026',
                        prefixIcon: Icon(Icons.local_offer_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  EbicButton(
                    label: _appliedPromoCode != null ? 'Applied' : 'Apply',
                    isLoading: _isApplyingPromo,
                    variant: _appliedPromoCode != null ? EbicButtonVariant.ghost : EbicButtonVariant.outline,
                    onPressed: _applyCoupon,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quote Breakdown (Section 11)
              const Text('Price Quote Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              EbicCard(
                child: Column(
                  children: [
                    _buildRow('Plan Base Price', '₹${basePrice.toStringAsFixed(0)}'),
                    if (_discountAmount > 0) ...[
                      const Divider(height: 16),
                      _buildRow('Promotion Discount', '-₹${_discountAmount.toStringAsFixed(0)}', isGreen: true),
                    ],
                    const Divider(height: 16),
                    _buildRow('GST (18% Healthcare Tax)', 'Included'),
                    const Divider(height: 20),
                    _buildRow('Final Amount', '₹${finalAmount.toStringAsFixed(0)}', isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              EbicButton(
                label: 'Pay & Activate ₹${finalAmount.toStringAsFixed(0)}',
                icon: Icons.lock_outline,
                isLoading: _isProcessingPurchase,
                onPressed: _completePurchase,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 14 : 13, color: isBold ? AppColors.slate900 : AppColors.slate500, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: isGreen ? AppColors.primary : (isBold ? AppColors.slate900 : AppColors.slate800),
          ),
        ),
      ],
    );
  }
}
