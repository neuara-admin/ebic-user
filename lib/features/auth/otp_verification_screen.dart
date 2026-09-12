import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Sections 14–17 — OTP Verification Screen
/// Purpose-bound verification with individual 6-digit input cells,
/// server-enforced countdown, masked phone, zero-secret logging,
/// and smooth auto-advance focus.
class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String purpose;
  final String? name;
  final String? email;
  final String? referralCode;
  final String? devCode;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.purpose = 'LOGIN',
    this.name,
    this.email,
    this.referralCode,
    this.devCode,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _secondsRemaining = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // In dev mode, auto-fill dev OTP if present
    if (kDebugMode && widget.devCode != null && widget.devCode!.length == 6) {
      for (int i = 0; i < 6; i++) {
        _digitControllers[i].text = widget.devCode![i];
      }
    }
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    // Security: Clear OTP from controllers on dispose (Section 17)
    for (final controller in _digitControllers) {
      controller.clear();
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _digitControllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    if (_isLoading) return; // Concurrency protection (Section 57)

    final code = _enteredOtp.trim();
    final otpError = Validators.validateOtp(code);
    if (otpError != null) {
      setState(() => _errorMessage = otpError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().verifyOtp(
      phone: widget.phone,
      code: code,
      purpose: widget.purpose,
      name: widget.name,
      email: widget.email,
      referralCode: widget.referralCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      // Clear OTP immediately after verification (Section 17)
      for (final controller in _digitControllers) {
        controller.clear();
      }

      if (widget.purpose == 'PASSWORD_RESET') {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.resetPassword,
          arguments: {'phone': widget.phone, 'code': code},
        );
      } else {
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
      }
    } else {
      setState(() {
        if (res.error?.code == 'AUTH_OTP_EXPIRED') {
          _errorMessage = 'This verification code has expired. Please request a new OTP.';
        } else if (res.error?.code == 'AUTH_OTP_LIMIT') {
          _errorMessage = 'Too many attempts. For security, please request a new verification code.';
        } else if (res.error?.code == 'ACCOUNT_RESTRICTED') {
          _errorMessage = 'Your account is currently restricted. Please contact support.';
        } else {
          _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Incorrect verification code. Please check and try again.';
        }
      });
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0 || _isLoading) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final res = await AuthService().requestOtp(widget.phone, purpose: widget.purpose);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      _startTimer();
      for (final controller in _digitControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      final newDevCode = res.data?['devCode'] as String?;
      if (kDebugMode && newDevCode != null && newDevCode.length == 6) {
        for (int i = 0; i < 6; i++) {
          _digitControllers[i].text = newDevCode[i];
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new 6-digit verification code has been dispatched.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _errorMessage = res.error?.displayMessage ?? res.error?.message ?? 'Failed to resend OTP. Please try again.';
      });
    }
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length < 8) return phone;
    final prefix = phone.substring(0, phone.length - 4);
    return '${prefix.substring(0, 7)} **** ${phone.substring(phone.length - 2)}';
  }

  String _getTitle() {
    switch (widget.purpose) {
      case 'REGISTRATION':
        return 'Verify Registration';
      case 'PASSWORD_RESET':
        return 'Verify Password Reset';
      case 'ACCOUNT_RECOVERY':
        return 'Account Recovery';
      default:
        return 'Verify Phone Number';
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purpose badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.purpose == 'REGISTRATION'
                      ? 'Step 2: Verification'
                      : 'Security Verification',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getTitle(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Enter the 6-digit code sent to ${_maskPhoneNumber(widget.phone)}',
                style: const TextStyle(fontSize: 14, color: AppColors.slate600, height: 1.4),
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
                const SizedBox(height: 20),
              ],

              // 6 PIN Input Cells
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildPinCell(index)),
              ),
              const SizedBox(height: 24),

              // Change Phone Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Wrong number? Change contact details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Verify Button
              EbicButton(
                label: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _handleVerify,
              ),
              const SizedBox(height: 24),

              // Resend Section
              Center(
                child: _secondsRemaining > 0
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.slate500),
                          const SizedBox(width: 6),
                          Text(
                            'Resend code in ${_secondsRemaining}s',
                            style: const TextStyle(
                              color: AppColors.slate500,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: _handleResend,
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                        label: const Text(
                          "Didn't receive code? Resend OTP",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinCell(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _digitControllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        child: TextField(
          controller: _digitControllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _digitControllers[index].text.isNotEmpty
                    ? AppColors.primary
                    : Colors.grey.shade300,
                width: _digitControllers[index].text.isNotEmpty ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (val) {
            setState(() {});
            if (val.isNotEmpty) {
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                // Auto trigger verify on 6th digit
                if (_enteredOtp.length == 6) {
                  _handleVerify();
                }
              }
            }
          },
        ),
      ),
    );
  }
}
