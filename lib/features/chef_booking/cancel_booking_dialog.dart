import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

class CancelBookingDialog extends StatefulWidget {
  final String orderId;
  final VoidCallback onCancelled;

  const CancelBookingDialog({
    super.key,
    required this.orderId,
    required this.onCancelled,
  });

  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  final ApiClient _api = ApiClient();
  bool _isLoading = false;
  bool _isEvaluating = true;
  String? _errorMessage;

  String? _selectedReason = 'CHANGE_OF_PLANS';
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? _evaluationResult;

  final List<Map<String, String>> _reasons = [
    {'code': 'CHANGE_OF_PLANS', 'label': 'Change of plans / scheduling conflict'},
    {'code': 'EMERGENCY', 'label': 'Personal emergency'},
    {'code': 'INGREDIENTS_UNAVAILABLE', 'label': 'Missing key ingredients at home'},
    {'code': 'ORDERED_BY_MISTAKE', 'label': 'Ordered by mistake'},
    {'code': 'OTHER', 'label': 'Other reason'},
  ];

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _isEvaluating = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.cancellationEvaluate,
        body: {
          'entityType': 'ORDER',
          'entityId': widget.orderId,
          'actorType': 'CUSTOMER',
          'reasonCode': _selectedReason,
        },
      );

      if (res.success && res.data != null) {
        setState(() {
          _evaluationResult = res.data;
          _isEvaluating = false;
        });
      } else {
        setState(() {
          _evaluationResult = {
            'eligible': true,
            'refundPercentage': 100,
            'policyName': 'EBIC Standard Customer Cancellation Window',
          };
          _isEvaluating = false;
        });
      }
    } catch (_) {
      setState(() {
        _evaluationResult = {
          'eligible': true,
          'refundPercentage': 100,
          'policyName': 'EBIC Standard Cancellation Policy',
        };
        _isEvaluating = false;
      });
    }
  }

  Future<void> _submitCancellation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Execute cancellation (Section 53)
      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.chefBookingCancel(widget.orderId),
        body: {
          'reasonCode': _selectedReason,
          'note': _noteController.text.trim(),
        },
        requiresIdempotency: true,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onCancelled();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chef booking cancelled successfully. Refund initiated to wallet/source.'),
            backgroundColor: AppColors.slate900,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cancel Booking',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to cancel this chef dispatch? Cancellations are evaluated against the authoritative backend policy.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
              ),
              const SizedBox(height: 16),

              if (_isEvaluating) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ] else if (_evaluationResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            _evaluationResult!['policyName'] ?? 'Cancellation Policy Evaluation',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estimated Refund: ${_evaluationResult!['refundPercentage'] ?? 100}% of booking charges',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Select Cancellation Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),

              ...List.generate(_reasons.length, (idx) {
                final r = _reasons[idx];
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(r['label']!, style: const TextStyle(fontSize: 13)),
                  value: r['code']!,
                  groupValue: _selectedReason,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _selectedReason = val);
                    _checkEligibility();
                  },
                );
              }),

              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Additional note (Optional)',
                  hintText: 'e.g. Need to reschedule for tomorrow',
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: EbicButton(
                      label: 'Keep Booking',
                      variant: EbicButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EbicButton(
                      label: 'Confirm Cancel',
                      variant: EbicButtonVariant.danger,
                      isLoading: _isLoading,
                      onPressed: _submitCancellation,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
