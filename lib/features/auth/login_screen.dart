import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

class LoginScreen extends StatefulWidget {
  final bool initialPasswordMode;

  const LoginScreen({super.key, this.initialPasswordMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isPasswordMode;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isPasswordMode = widget.initialPasswordMode;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _handleOtpRequest() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile phone number.');
      return;
    }
    // Clean formatted phone if needed
    final cleanPhone = phone.startsWith('+') ? phone : '+91$phone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().requestOtp(cleanPhone);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'phone': cleanPhone,
          'referralCode': _referralController.text.trim(),
        },
      );
    } else {
      setState(() {
        _errorMessage = res.error?.message ?? 'Failed to send OTP. Please check the number.';
      });
    }
  }

  Future<void> _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().loginWithPassword(email: email, password: password);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (route) => false);
    } else {
      setState(() {
        _errorMessage = res.error?.message ?? 'Invalid credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPasswordMode ? 'Welcome Back' : 'Sign In with Phone',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _isPasswordMode
                  ? 'Enter your account credentials below.'
                  : 'We will send a 6-digit OTP verification code to your mobile number.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
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

              if (!_isPasswordMode) ...[
                // Phone & OTP mode
                const Text(
                  'Mobile Number',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: const Text(
                        '+91',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    hintText: '9876543210',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Referral / Invite Code (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _referralController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.card_giftcard_outlined),
                    hintText: 'e.g. WELCOME20',
                  ),
                ),
                const SizedBox(height: 32),
                EbicButton(
                  label: 'Send Verification Code',
                  isLoading: _isLoading,
                  onPressed: _handleOtpRequest,
                ),
              ] else ...[
                // Email & Password mode
                const Text(
                  'Email Address',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'user@example.com',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: '••••••••',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),
                EbicButton(
                  label: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _handlePasswordLogin,
                ),
              ],

              const SizedBox(height: 32),
              // Switch mode button
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isPasswordMode = !_isPasswordMode;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isPasswordMode
                        ? 'Prefer mobile phone login? Sign in with OTP'
                        : 'Staff or existing password account? Sign in with Password',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
