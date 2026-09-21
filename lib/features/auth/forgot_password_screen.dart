import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/ebic_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;
  String? _devToken;

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiClient().post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
      requiresAuth: false,
    );
    setState(() => _isLoading = false);

    if (res.success) {
      final devLink = res.data?['devResetLink'] as String?;
      if (devLink != null && devLink.contains('token=')) {
        _devToken = Uri.tryParse(devLink)?.queryParameters['token'];
      }
      setState(() => _isSent = true);
    } else {
      setState(() => _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Failed to send reset link.');
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
          child: _isSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset Password', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          'Enter the email associated with your account and we will send instructions to reset your password.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'user@example.com',
          ),
        ),
        const SizedBox(height: 28),
        EbicButton(
          label: 'Send Reset Link',
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Check Your Email',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We have sent password reset instructions to ${_emailController.text.trim()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500),
          ),
          if (_devToken != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Reset Password Directly (Dev Link)'),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.resetPassword,
                  arguments: {'token': _devToken},
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          EbicButton(
            label: 'Back to Sign In',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
