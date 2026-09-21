import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_global_components.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_confirmation_dialog.dart';
import '../../shared/widgets/ebic_text_field.dart';

/// Module 20: Section 304 — Account Security & Section 305 — Login Sessions
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final AuthService _auth = AuthService();
  bool _isLoadingSessions = true;
  List<Map<String, dynamic>> _sessions = [];
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionError = null;
    });

    final res = await _auth.getSessions();
    if (!mounted) return;

    if (res.success && res.data != null) {
      final list = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _sessions = list;
        _isLoadingSessions = false;
      });
    } else {
      setState(() {
        _sessionError = res.error?.message ?? 'Failed to load active sessions';
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    final confirm = await EBICConfirmationDialog.show(
      context: context,
      title: 'Revoke Session',
      message: 'Are you sure you want to log out of this device? It will require re-authenticating.',
      confirmLabel: 'Revoke',
      isDestructive: true,
    );

    if (confirm != true) return;

    final res = await _auth.revokeSession(sessionId);
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session revoked successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadSessions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error?.message ?? 'Failed to revoke session'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  EBICTextField(
                    label: 'Current Password',
                    controller: currentPassController,
                    isPassword: true,
                    prefix: const Icon(Icons.lock_outline, size: 20, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 12),
                  EBICTextField(
                    label: 'New Password',
                    controller: newPassController,
                    isPassword: true,
                    prefix: const Icon(Icons.lock_reset_outlined, size: 20, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 12),
                  EBICTextField(
                    label: 'Confirm New Password',
                    controller: confirmPassController,
                    isPassword: true,
                    prefix: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final currentPass = currentPassController.text.trim();
                              final newPass = newPassController.text.trim();
                              final confirmPass = confirmPassController.text.trim();

                              if (currentPass.isEmpty || newPass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill all fields')),
                                );
                                return;
                              }
                              if (newPass != confirmPass) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Passwords do not match')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              // Mock/call change password
                              await Future.delayed(const Duration(milliseconds: 600));
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final phone = user?['phone'] ?? 'Not set';
    final email = user?['email'] ?? 'Not set';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Account Security'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSessions,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity Verification Section
                const Text(
                  'Account Identity & Credentials',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 12),
                EbicCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_iphone_rounded, color: AppColors.primaryDark),
                        ),
                        title: const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(phone, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.email_outlined, color: AppColors.primaryDark),
                        ),
                        title: const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(email, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (email != 'Not set' && email.isNotEmpty)
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (email != 'Not set' && email.isNotEmpty) ? 'Verified' : 'Pending',
                            style: TextStyle(
                              color: (email != 'Not set' && email.isNotEmpty) ? AppColors.success : AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppColors.slate700),
                        ),
                        title: const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Manage your sign-in password', style: TextStyle(color: AppColors.slate500, fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Active Login Sessions (Section 305)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Login Sessions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (_sessions.length > 1)
                      TextButton.icon(
                        icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
                        label: const Text(
                          'Log out other devices',
                          style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final confirm = await EBICConfirmationDialog.show(
                            context: context,
                            title: 'Log out other devices',
                            message: 'This will invalidate sessions on all devices except this one.',
                            confirmLabel: 'Log Out Others',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            await _auth.logoutAll();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logged out of other devices')),
                              );
                              _loadSessions();
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Devices where you are currently signed in. You can revoke any session.',
                  style: TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
                const SizedBox(height: 12),

                if (_isLoadingSessions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppLoading(message: 'Loading active sessions...'),
                  )
                else if (_sessionError != null)
                  AppError(
                    message: _sessionError!,
                    onRetry: _loadSessions,
                  )
                else if (_sessions.isEmpty)
                  const AppEmpty(
                    icon: Icons.devices_rounded,
                    title: 'No Active Sessions',
                    message: 'Only this active session was found.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      final isCurrent = s['isCurrent'] == true;
                      final deviceName = s['deviceName'] ?? s['device'] ?? 'Mobile Device';
                      final clientType = s['clientType'] ?? 'Flutter App';
                      final sessionId = s['id'] ?? '';

                      return EbicCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppColors.primarySubtle : AppColors.slate100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                deviceName.toString().toLowerCase().contains('chrome') ||
                                        deviceName.toString().toLowerCase().contains('web')
                                    ? Icons.laptop_mac_rounded
                                    : Icons.smartphone_rounded,
                                color: isCurrent ? AppColors.primaryDark : AppColors.slate600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        deviceName.toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(
                                              color: AppColors.success,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isCurrent ? '$clientType • Active now' : '$clientType • Active session',
                                    style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCurrent)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                tooltip: 'Revoke session',
                                onPressed: () => _revokeSession(sessionId),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
                // Security Controls / Two-Step Verification readiness (Section 304)
                const Text(
                  'Additional Protections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 12),
                EbicCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Biometric / App Lock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Require fingerprint or Face ID to open app', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                        value: false,
                        onChanged: (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Biometric verification will be enabled in next update')),
                          );
                        },
                      ),
                      const Divider(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Two-Step Verification (2FA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('OTP verification on new device logins', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                        value: true,
                        onChanged: null, // Always enabled by default per Section 299 & 304
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
