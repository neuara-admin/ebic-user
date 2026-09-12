import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ebic_button.dart';

/// Modal bottom sheet for verifying customer email address via 6-digit OTP code.
class EmailOtpSheet extends StatefulWidget {
  final String email;

  const EmailOtpSheet({super.key, required this.email});

  static Future<bool?> show(BuildContext context, {required String email}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmailOtpSheet(email: email),
    );
  }

  @override
  State<EmailOtpSheet> createState() => _EmailOtpSheetState();
}

class _EmailOtpSheetState extends State<EmailOtpSheet> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _devCode;
  int _secondsRemaining = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
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

  Future<void> _requestOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.requestEmailOtp,
        body: {'email': widget.email},
      );

      if (!mounted) return;

      if (res.success) {
        _startTimer();
        final devCode = res.data?['devCode'] as String?;
        setState(() {
          _isSendingOtp = false;
          _devCode = devCode;
        });

        // Auto-fill in debug if dev code exists
        if (kDebugMode && devCode != null && devCode.length == 6) {
          for (int i = 0; i < 6; i++) {
            _controllers[i].text = devCode[i];
          }
        }
      } else {
        setState(() {
          _isSendingOtp = false;
          _errorMessage = res.message ?? 'Failed to send verification email.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _errorMessage = 'Could not send verification email. Please check your network.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _controllers.map((c) => c.text).join().trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the verification code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.verifyEmailOtp,
        body: {
          'email': widget.email,
          'code': code,
        },
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (res.success && res.data != null) {
        final updatedUser = Map<String, dynamic>.from(_auth.user ?? {});
        updatedUser['email'] = res.data!['email'] ?? widget.email;
        updatedUser['emailVerified'] = true;
        _auth.updateCurrentUser(updatedUser);

        await TokenStorage.saveUser(
          id: res.data!['id'] ?? updatedUser['id'] ?? '',
          phone: updatedUser['phone'] ?? '',
          name: updatedUser['name'],
          email: updatedUser['email'],
          avatarUrl: updatedUser['avatarUrl'],
        );

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Email verified successfully!'),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = res.message ?? 'Invalid or expired verification code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.emerald50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),

          const Text(
            'Verify Email Address',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 6),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
              children: [
                const TextSpan(text: 'We sent a 6-digit verification code to\n'),
                TextSpan(
                  text: widget.email,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rose50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 6 PIN cells
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate300, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else if (val.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                    if (_controllers.every((c) => c.text.isNotEmpty)) {
                      _verifyOtp();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Dev Code Banner in debug mode
          if (kDebugMode && _devCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber300),
              ),
              child: Text(
                '⚡ Dev Code: $_devCode',
                style: const TextStyle(color: AppColors.amber800, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Resend section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _secondsRemaining > 0
                    ? 'Resend code in ${_secondsRemaining}s'
                    : "Didn't receive the code?",
                style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
              if (_secondsRemaining == 0)
                TextButton(
                  onPressed: _isSendingOtp ? null : _requestOtp,
                  child: _isSendingOtp
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                          'Resend Code',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          EbicButton(
            label: 'Verify Email',
            isLoading: _isVerifying,
            onPressed: _verifyOtp,
          ),
        ],
      ),
    );
  }
}
