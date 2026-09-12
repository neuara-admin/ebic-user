import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Section 22 & 40–42 — Account Deactivation Screen
/// Explains consequences, confirms deactivation, and gracefully terminates the session.
class AccountDeactivationScreen extends StatefulWidget {
  const AccountDeactivationScreen({super.key});

  @override
  State<AccountDeactivationScreen> createState() => _AccountDeactivationScreenState();
}

class _AccountDeactivationScreenState extends State<AccountDeactivationScreen> {
  bool _isLoading = false;
  bool _acknowledged = false;

  Future<void> _handleDeactivate() async {
    if (!_acknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please acknowledge the deactivation consequences.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Deactivation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to deactivate your EBIC account? Your session will be terminated immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final res = await AuthService().deactivateAccount();
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deactivated.'),
            backgroundColor: AppColors.slate900,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error?.message ?? 'Deactivation failed. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
        title: const Text('Deactivate Account', style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slate900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temporary Account Deactivation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Deactivating your account temporarily hides your profile and pauses meal notifications. You can reactivate your account anytime by signing in or contacting support.',
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
                'What happens when you deactivate:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              const SizedBox(height: 12),

              _buildPoint(Icons.pause_circle_outline_rounded, 'Active sessions and device tokens are revoked immediately.'),
              _buildPoint(Icons.no_meals_outlined, 'Upcoming scheduled recurring orders will be placed on hold.'),
              _buildPoint(Icons.history_edu_outlined, 'Your past consultation records and health history remain securely saved.'),
              const Spacer(),

              // Checkbox acknowledgment
              Row(
                children: [
                  Checkbox(
                    value: _acknowledged,
                    activeColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _acknowledged = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'I understand the consequences and wish to deactivate my account.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              EbicButton(
                label: 'Deactivate My Account',
                color: AppColors.danger,
                isLoading: _isLoading,
                onPressed: _handleDeactivate,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.slate600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
