import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/loading_view.dart';

/// Module 2 Section 22 & 43–45 — Account Deletion Screen
/// Evaluates backend-governed active transactions, prevents deletion when
/// blocked, and processes verified deletion requests.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isCheckingEligibility = true;
  bool _isEligible = false;
  List<String> _blockingReasons = [];

  bool _isSubmitting = false;
  String _selectedReason = 'No longer using the service';
  final TextEditingController _confirmationController = TextEditingController();

  final List<String> _deletionReasons = [
    'No longer using the service',
    'Moving to an unserviceable area',
    'Privacy or data security concerns',
    'Cost or subscription preferences',
    'Other reason',
  ];

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isCheckingEligibility = true);

    try {
      final res = await AuthService().checkDeletionEligibility();
      if (!mounted) return;

      if (res.success && res.data != null) {
        final data = res.data!;
        final eligible = data['eligible'] as bool? ?? false;
        final reasons = (data['blockingReasons'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        setState(() {
          _isCheckingEligibility = false;
          _isEligible = eligible;
          _blockingReasons = reasons;
        });
      } else {
        setState(() {
          _isCheckingEligibility = false;
          _isEligible = false;
          _blockingReasons = ['Unable to verify transaction status. Please contact support.'];
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingEligibility = false;
        _isEligible = false;
        _blockingReasons = ['Network error. Please try again.'];
      });
    }
  }

  Future<void> _handleConfirmDeletion() async {
    if (_confirmationController.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type DELETE to confirm.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await AuthService().requestAccountDeletion(reason: _selectedReason);
      setState(() => _isSubmitting = false);

      if (!mounted) return;

      if (res.success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Deletion Request Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              res.data?['message'] ??
                  'Your deletion request has been registered. Your session has ended.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error?.message ?? 'Failed to process deletion request.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delete Account', style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slate900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isCheckingEligibility
            ? const Center(child: EBICLoader(message: 'Checking active transactions...'))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _isEligible ? _buildEligibleContent() : _buildBlockedContent(),
              ),
      ),
    );
  }

  Widget _buildBlockedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.dangerLight.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.danger, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Deletion Blocked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Your account cannot currently be deleted because there are active transactions that must be resolved first.',
                style: TextStyle(fontSize: 14, color: AppColors.slate700, height: 1.4),
              ),
              const SizedBox(height: 14),
              ..._blockingReasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 13, color: AppColors.slate800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'What to do next:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Complete or cancel pending meal orders.\n'
          '2. Wait for active Health Pass duration to conclude or contact customer care.\n'
          '3. Allow pending refunds to finish bank settlement.',
          style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.6),
        ),
        const SizedBox(height: 32),

        EbicButton(
          label: 'Contact Support',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.support),
        ),
        const SizedBox(height: 12),
        EbicButton(
          label: 'Re-Check Eligibility',
          isOutlined: true,
          onPressed: _checkEligibility,
        ),
      ],
    );
  }

  Widget _buildEligibleContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permanent Account Deletion',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.danger),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Requesting deletion initiates a business process. Data will be purged according to statutory health and tax retention laws.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Select reason for leaving:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedReason,
              items: _deletionReasons.map((r) {
                return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Type DELETE to confirm:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmationController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'DELETE',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 32),

        EbicButton(
          label: 'Permanently Delete Account',
          color: AppColors.danger,
          isLoading: _isSubmitting,
          onPressed: _handleConfirmDeletion,
        ),
      ],
    );
  }
}
