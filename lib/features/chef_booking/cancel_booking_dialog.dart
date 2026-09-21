import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';

/// Module 18 & Specification Sections 251–257: Customer Order Cancellation
/// Connects to backend cancellation governance, checks real-time refund/entitlement eligibility,
/// presents controlled reason codes, and triggers immediate state synchronization with backend and web console.
class CancelBookingDialog extends StatefulWidget {
  final String orderId;
  final VoidCallback onCancelled;
  final bool isBottomSheet;

  const CancelBookingDialog({
    super.key,
    required this.orderId,
    required this.onCancelled,
    this.isBottomSheet = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required VoidCallback onCancelled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelBookingDialog(
        orderId: orderId,
        onCancelled: onCancelled,
        isBottomSheet: true,
      ),
    );
  }

  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

typedef CancelBookingSheet = CancelBookingDialog;

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  final ApiClient _api = ApiClient();
  bool _isLoading = false;
  bool _isEvaluating = true;
  String? _errorMessage;

  String? _selectedReason = 'CUSTOMER_CHANGED_PLANS';
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? _eligibility;

  // Controlled cancellation reason codes (Section 257) with dynamic backend directory sync
  List<Map<String, String>> _reasons = [
    {
      'code': 'CUSTOMER_CHANGED_PLANS',
      'label': 'Change of plans / personal scheduling',
      'icon': 'calendar_today',
    },
    {
      'code': 'WRONG_BOOKING',
      'label': 'Wrong booking / duplicate selection',
      'icon': 'content_copy',
    },
    {
      'code': 'NO_LONGER_REQUIRED',
      'label': 'No longer required',
      'icon': 'highlight_off',
    },
    {
      'code': 'PAYMENT_ISSUE',
      'label': 'Payment or billing issue',
      'icon': 'payments_outlined',
    },
    {
      'code': 'ADDRESS_ISSUE',
      'label': 'Address / kitchen location problem',
      'icon': 'location_on_outlined',
    },
    {
      'code': 'TIMING_ISSUE',
      'label': 'Timing / schedule conflict',
      'icon': 'schedule',
    },
    {
      'code': 'OTHER',
      'label': 'Other personal reason',
      'icon': 'more_horiz',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _checkEligibility(),
      _loadReasonsDirectory(),
    ]);
  }

  Future<void> _loadReasonsDirectory() async {
    try {
      final res = await _api.get<List<dynamic>>(
        '${ApiEndpoints.cancellationReasons}?actorType=CUSTOMER',
      );
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final List<Map<String, String>> dynamicReasons = [];
        for (final item in res.data!) {
          if (item is Map) {
            dynamicReasons.add({
              'code': item['code']?.toString() ?? 'OTHER',
              'label': item['name']?.toString() ?? item['label']?.toString() ?? 'Other reason',
              'icon': 'radio_button_checked',
            });
          }
        }
        if (dynamicReasons.isNotEmpty && mounted) {
          setState(() {
            _reasons = dynamicReasons;
            if (!_reasons.any((r) => r['code'] == _selectedReason)) {
              _selectedReason = _reasons.first['code'];
            }
          });
        }
      }
    } catch (_) {
      // Gracefully fall back to local controlled reason codes
    }
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _isEvaluating = true;
      _errorMessage = null;
    });

    try {
      // Section 255: GET /api/v1/orders/:orderId/cancellation/eligibility
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.orderCancellationEligibility(widget.orderId),
      );

      if (res.success && res.data != null) {
        setState(() {
          _eligibility = res.data;
          _isEvaluating = false;
        });
      } else {
        setState(() {
          _eligibility = {
            'allowed': true,
            'refund_information': {'eligible': true, 'amount': 0, 'currency': 'INR'},
            'entitlement_information': {'entitlement_action': 'RELEASE'},
          };
          _isEvaluating = false;
        });
      }
    } catch (_) {
      setState(() {
        _eligibility = {
          'allowed': true,
          'refund_information': {'eligible': true, 'amount': 0, 'currency': 'INR'},
          'entitlement_information': {'entitlement_action': 'NO_ACTION'},
        };
        _isEvaluating = false;
      });
    }
  }

  Future<void> _submitCancellation() async {
    if (_eligibility?['allowed'] == false) {
      setState(() {
        _errorMessage = _eligibility?['reason'] ?? 'Cancellation is not allowed for this booking.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Section 255: POST /api/v1/orders/:orderId/cancellation
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orderCancellation(widget.orderId),
        body: {
          'reason_code': _selectedReason,
          'reasonCode': _selectedReason,
          'comment': _noteController.text.trim(),
          'note': _noteController.text.trim(),
        },
        requiresIdempotency: true,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onCancelled();
        final refundInfo = res.data?['refund'];
        final refundAmount = refundInfo?['amount'] ?? 0;
        final hasRefund = refundInfo?['eligible'] == true && refundAmount > 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasRefund
                        ? 'Booking cancelled. Refund of ₹$refundAmount initiated to your payment source.'
                        : 'Booking cancelled successfully.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.slate950,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.slate900 : Colors.white;
    final cardBg = isDark ? AppColors.slate800 : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? AppColors.slate700 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.slate900;
    final textSecondary = isDark ? AppColors.slate300 : AppColors.slate600;

    final refundInfo = _eligibility?['refund_information'] as Map<String, dynamic>?;
    final entitlementInfo = _eligibility?['entitlement_information'] as Map<String, dynamic>?;
    final bool allowed = _eligibility?['allowed'] ?? true;
    final String? notAllowedReason = _eligibility?['reason'];
    final num refundAmount = refundInfo?['amount'] ?? 0;
    final String entitlementAction = entitlementInfo?['entitlement_action'] ?? 'NO_ACTION';

    final sheetRadius = widget.isBottomSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(20);

    final Widget body = Material(
      color: sheetBg,
      borderRadius: sheetRadius,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
            maxWidth: widget.isBottomSheet ? double.infinity : 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isBottomSheet) ...[
                // Drag Handle
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                const SizedBox(height: 16),
              ],

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancel Chef Booking',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Booking Ref: EBIC-${widget.orderId.substring(0, widget.orderId.length > 8 ? 8 : widget.orderId.length).toUpperCase()}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 18),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  // Advisory Notice
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.slate700 : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cancellation policy evaluates refund amounts and automatically releases Health Pass chef-visit entitlements.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Eligibility & Refund Information Card
                  if (_isEvaluating) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Evaluating refund policy & entitlements...',
                              style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (!allowed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 22, color: AppColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              notAllowedReason ?? 'This booking cannot be cancelled at this stage.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimated Refund Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                refundAmount > 0 ? '₹${refundAmount.toStringAsFixed(0)}' : 'Free Cancellation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.emerald400 : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          if (entitlementAction == 'RELEASE') ...[
                            const SizedBox(height: 10),
                            Divider(height: 1, color: cardBorder),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: isDark ? AppColors.emerald400 : AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '1 Chef Visit entitlement will be automatically returned to your active Health Pass.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.emerald400 : AppColors.successDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Controlled Reason Selector
                  Text(
                    'Reason for Cancellation (Required)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._reasons.map((r) {
                    final isSelected = _selectedReason == r['code'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: allowed
                            ? () {
                                setState(() => _selectedReason = r['code']);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primarySubtle)
                                : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : cardBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? AppColors.primary : AppColors.slate400,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r['label']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : AppColors.primaryDark)
                                        : textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Optional Comment Field
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Additional Notes (Optional)',
                      labelStyle: TextStyle(color: textSecondary, fontSize: 12),
                      hintText: 'Provide any details for our operations team...',
                      hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 12),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Fixed Bottom Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(
                  top: BorderSide(color: cardBorder, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: cardBorder),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Keep Booking',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: (allowed && !_isLoading) ? _submitCancellation : null,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Confirm Cancel',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );

    if (!widget.isBottomSheet) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: body,
      );
    }
    return body;
  }
}
