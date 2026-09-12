import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Section 15 — Registration Screen
/// Implements full customer registration with real-time client validation,
/// duplicate submission prevention, and duplicate account recovery prompts.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _termsAccepted = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return; // Prevent double taps (Section 57)

    setState(() => _errorMessage = null);

    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorMessage = 'Please enter your full name (at least 2 characters).');
      return;
    }

    final phoneInput = _phoneController.text.trim();
    final phoneError = Validators.validatePhone(phoneInput);
    if (phoneError != null) {
      setState(() => _errorMessage = phoneError);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    if (!_termsAccepted) {
      setState(() => _errorMessage = 'Please agree to the Terms of Service & Privacy Policy.');
      return;
    }

    final cleanPhone = Validators.normalizePhone(phoneInput);
    final referralCode = _referralController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      // Step 1: Request OTP with explicit REGISTRATION purpose (Section 17 & 51)
      final res = await AuthService().requestOtp(cleanPhone, purpose: 'REGISTRATION');
      setState(() => _isSubmitting = false);

      if (!mounted) return;

      if (res.success) {
        final devCode = res.data?['devCode'] as String?;
        // Navigate to OTP verification passing registration payload
        Navigator.pushNamed(
          context,
          AppRoutes.otp,
          arguments: {
            'phone': cleanPhone,
            'purpose': 'REGISTRATION',
            'name': name,
            'email': email.isNotEmpty ? email : null,
            'referralCode': referralCode.isNotEmpty ? referralCode : null,
            'devCode': devCode,
          },
        );
      } else {
        if (res.error?.code == 'ACCOUNT_ALREADY_EXISTS') {
          _showDuplicateAccountDialog(cleanPhone);
        } else {
          setState(() {
            _errorMessage = res.error?.message ?? 'Registration failed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'An unexpected error occurred. Please check your network.';
      });
    }
  }

  void _showDuplicateAccountDialog(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Account Exists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'An account may already exist with these details.\nWould you like to log in instead?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.login,
                arguments: {'prefillPhone': phone},
              );
            },
            child: const Text('Log In', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Join EBIC Nutrition',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your details to register and access personalized healthy chef bookings.',
                style: TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.4),
              ),
              const SizedBox(height: 24),

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
                const SizedBox(height: 18),
              ],

              // Full Name
              _buildFieldLabel('Full Name *'),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: 'e.g. John Doe',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // Mobile Number
              _buildFieldLabel('Mobile Number *'),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _inputDecoration(
                  hint: '98765 43210',
                  prefixIcon: Icons.phone_android_rounded,
                  prefixText: '+91 ',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),

              // Email Address
              _buildFieldLabel('Email Address (Optional)'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: 'john.doe@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // Referral Code
              _buildFieldLabel('Referral Code (Optional)'),
              TextField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  hint: 'e.g. EBIC2026',
                  prefixIcon: Icons.card_giftcard_outlined,
                ),
              ),
              const SizedBox(height: 18),

              // Terms & Privacy
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                      child: const Text(
                        'I agree to the Terms of Service and Privacy Policy.',
                        style: TextStyle(fontSize: 13, color: AppColors.slate600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              EbicButton(
                label: 'Create Account & Send OTP',
                isLoading: _isSubmitting,
                onPressed: _handleRegister,
              ),
              const SizedBox(height: 20),

              // Login Link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  child: RichText(
                    text: const TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: AppColors.slate600, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.slate700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: AppColors.slate400, size: 20),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: AppColors.slate900,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
