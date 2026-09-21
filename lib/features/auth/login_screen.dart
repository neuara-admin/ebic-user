import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Section 16 — Customer Login Screen
/// Supports Phone + OTP authentication flow with rate-limiting protection,
/// plus an Email/Password login mode for staff & credentialed accounts.
class LoginScreen extends StatefulWidget {
  final bool initialPasswordMode;

  const LoginScreen({super.key, this.initialPasswordMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late bool _isPasswordMode;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasCheckedArgs = false;

  @override
  void initState() {
    super.initState();
    _isPasswordMode = widget.initialPasswordMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedArgs) {
      _hasCheckedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final prefill = args['prefillPhone'] as String?;
        if (prefill != null && prefill.isNotEmpty) {
          final digits = prefill.replaceAll(RegExp(r'\D'), '');
          _phoneController.text = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    if (!mounted) return;
    setState(() => _isLoading = false);

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
        } else if (res.error?.code == 'STAFF_ACCOUNT_REQUIRES_PASSWORD_LOGIN') {
          _isPasswordMode = true;
          _errorMessage = 'Staff accounts sign in with email and password.';
        } else {
          _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Failed to send OTP. Please try again.';
        }
      });
    }
  }

  Future<void> _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().loginWithPassword(email: email, password: password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      final dest = AppRouter.intendedDestinationRoute;
      final destArgs = AppRouter.intendedDestinationArgs;
      AppRouter.intendedDestinationRoute = null;
      AppRouter.intendedDestinationArgs = null;

      if (dest != null && dest != AppRoutes.mainShell && dest != AppRoutes.login) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (route) => false);
        Navigator.pushNamed(context, dest, arguments: destArgs);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (route) => false);
      }
    } else {
      setState(() {
        if (res.error?.code == 'RATE_LIMITED' || res.error?.code == '429') {
          _errorMessage = 'Too many attempts. Please wait a minute before trying again.';
        } else if (res.error?.code == 'ACCOUNT_LOCKED') {
          _errorMessage = 'Account temporarily locked due to repeated failed sign-ins. Try again later or reset password.';
        } else if (res.error?.code == 'INVALID_CREDENTIALS') {
          _errorMessage = 'Incorrect email or password. Please check and try again.';
        } else {
          _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Sign in failed. Please try again.';
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
              // Badge & Mode Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isPasswordMode ? 'Staff & Password Login' : 'Customer Sign In',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isPasswordMode = !_isPasswordMode;
                        _errorMessage = null;
                      });
                    },
                    icon: Icon(
                      _isPasswordMode ? Icons.phone_android_rounded : Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _isPasswordMode ? 'Use Phone OTP' : 'Use Password',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _isPasswordMode ? 'Sign In with Password' : 'Sign In with Phone',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPasswordMode
                    ? 'Enter your registered email and password to access your account.'
                    : 'We will send a 6-digit OTP verification code to your mobile number.',
                style: const TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.4),
              ),
              const SizedBox(height: 28),

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

              if (!_isPasswordMode) ...[
                // Mobile Number Input
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
                const SizedBox(height: 28),
                EbicButton(
                  label: 'Send Verification Code',
                  isLoading: _isLoading,
                  onPressed: _handleOtpRequest,
                ),
              ] else ...[
                // Email Address Input
                const Text(
                  'Email Address',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slate800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slate400, size: 20),
                    hintText: 'admin@ebic.example',
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
                const SizedBox(height: 18),

                // Password Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slate800),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.slate400, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.slate400,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: '••••••••',
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
                const SizedBox(height: 28),
                EbicButton(
                  label: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _handlePasswordLogin,
                ),
              ],

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
