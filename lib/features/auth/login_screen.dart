import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Section 16 — Customer Login Screen
/// Pure phone + OTP customer authentication flow with rate-limiting protection.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, bool initialPasswordMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleOtpRequest() async {
    final phoneInput = _phoneController.text.trim();
    final phoneError = Validators.validatePhone(phoneInput);
    if (phoneError != null) {
      setState(() => _errorMessage = phoneError);
      return;
    }

    final cleanPhone = Validators.normalizePhone(phoneInput);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().requestOtp(cleanPhone, purpose: 'LOGIN');
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      final devCode = res.data?['devCode'] as String?;
      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'phone': cleanPhone,
          'purpose': 'LOGIN',
          'devCode': devCode,
        },
      );
    } else {
      setState(() {
        if (res.error?.code == 'RATE_LIMITED' || res.error?.code == '429') {
          _errorMessage = 'Too many requests. Please wait a minute before requesting another code.';
        } else if (res.error?.code == 'ACCOUNT_RESTRICTED') {
          _errorMessage = 'Your account is currently restricted. Please contact support.';
        } else {
          _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Failed to send OTP. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slate900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Customer Sign In',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign In with Phone',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will send a 6-digit OTP verification code to your mobile number.',
                style: TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Mobile Number
              const Text(
                'Mobile Number',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slate800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: const Text(
                      '+91',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800),
                    ),
                  ),
                  hintText: '9876543210',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              EbicButton(
                label: 'Send Verification Code',
                isLoading: _isLoading,
                onPressed: _handleOtpRequest,
              ),

              const SizedBox(height: 24),
              // Register Link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.register),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppColors.slate600, fontSize: 14),
                      ),
                      Text(
                        'Sign Up',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Account Recovery Link (Section 20 & 32)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.accountRecovery);
                  },
                  child: const Text(
                    "Can't access your account? Account Recovery",
                    style: TextStyle(
                      color: AppColors.slate500,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
