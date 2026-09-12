import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';

/// Module 4 — Section 41: Health Pass Payment Result & Activation Screen
/// Authoritatively handles both PAYMENT SUCCESS and PAYMENT FAILURE states.
class HealthPassActivationScreen extends StatelessWidget {
  final Map<String, dynamic> arguments;

  const HealthPassActivationScreen({super.key, required this.arguments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isSuccess = arguments['isSuccess'] as bool? ?? true;
    final planName = arguments['planName']?.toString() ?? 'EBIC Care Health Pass';
    final durationMonths = int.tryParse(arguments['durationMonths']?.toString() ?? '1') ?? 1;
    final members = (arguments['members'] as List<dynamic>?)?.cast<HouseholdMemberModel>() ?? [];
    final passId = arguments['healthPassId']?.toString() ?? '';
    final amountPaid = double.tryParse(arguments['amountPaid']?.toString() ?? arguments['amount']?.toString() ?? '0') ?? 0.0;
    final paymentId = arguments['paymentId']?.toString() ?? arguments['gatewayPaymentId']?.toString();
    final errorMessage = arguments['errorMessage']?.toString() ?? arguments['reason']?.toString();

    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back to payment gateway; redirect to main shell
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainShell, (r) => false, arguments: isSuccess ? 2 : 0);
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(isSuccess ? 'Payment Confirmation' : 'Payment Status'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.mainShell,
                  (r) => false,
                  arguments: isSuccess ? 2 : 0,
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: isSuccess
                ? _buildSuccessView(
                    context: context,
                    isDark: isDark,
                    planName: planName,
                    durationMonths: durationMonths,
                    members: members,
                    passId: passId,
                    amountPaid: amountPaid,
                    paymentId: paymentId,
                  )
                : _buildFailureView(
                    context: context,
                    isDark: isDark,
                    planName: planName,
                    durationMonths: durationMonths,
                    amountPaid: amountPaid,
                    errorMessage: errorMessage,
                  ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PAYMENT SUCCESS VIEW
  // ==========================================
  Widget _buildSuccessView({
    required BuildContext context,
    required bool isDark,
    required String planName,
    required int durationMonths,
    required List<HouseholdMemberModel> members,
    required String passId,
    required double amountPaid,
    required String? paymentId,
  }) {
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),

        // 1. Success Animated Glow Badge
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryLight, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 18),

        // 2. Title & Subtitle
        Text(
          'Payment Successful!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.slate900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your EBIC Health Pass is confirmed and entitlements are ready.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate600, height: 1.35),
        ),
        const SizedBox(height: 20),

        // 3. Official Payment Receipt Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Tax Invoice Receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.emerald900.withOpacity(0.35) : AppColors.emerald50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppColors.emerald700.withOpacity(0.5) : AppColors.emerald600.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'PAID • GST COMPLIANT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (amountPaid > 0) ...[
                _receiptRow('Amount Paid', '₹${amountPaid.toInt()}', isDark, isHighlight: true),
                const SizedBox(height: 8),
              ],
              _receiptRow('Plan Enrolled', planName, isDark),
              const SizedBox(height: 8),
              _receiptRow('Subscription Term', '$durationMonths ${durationMonths == 1 ? 'Month' : 'Months'} Plan', isDark),
              const SizedBox(height: 8),
              _receiptRow('Date & Time', nowFormatted, isDark),

              if (paymentId != null && paymentId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment ID', style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
                    Row(
                      children: [
                        Text(
                          paymentId.length > 18 ? '${paymentId.substring(0, 8)}...${paymentId.substring(paymentId.length - 6)}' : paymentId,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.slate300 : AppColors.slate800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: paymentId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment ID copied to clipboard'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Initial Consultation Onboarding Kickoff Callout (CRITICAL RULE)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.slate800, AppColors.slate800.withOpacity(0.8)]
                  : [AppColors.primarySubtle.withOpacity(0.85), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryLight.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 1: Complete Initial Consultation',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Validity commences upon completion',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your $durationMonths-month membership validity begins strictly on the date your initial dietitian consultation is completed. Schedule your video call now to commence your clinical diet plan!',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.video_call_outlined, size: 18),
                  label: const Text('Schedule Initial Consultation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.consultationBook);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Entitlements & Members Summary
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MEMBERSHIP SUMMARY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${members.length} ${members.length == 1 ? 'Member' : 'Members'} Covered',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (members.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: members.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            m.name,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.slate800),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 20),
              ],
              Row(
                children: [
                  const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Monthly chef visits and clinical dietitian allowances reset every month from your commencement date.',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 6. Navigation Actions
        EbicButton(
          label: 'View Health Pass Details',
          isFullWidth: true,
          onPressed: () {
            // Redirect directly to Main Shell with Tab 2 (Health Pass Dashboard)
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.mainShell,
              (r) => false,
              arguments: 2,
            );
          },
        ),
        const SizedBox(height: 10),
        EbicButton(
          label: 'Back to Home',
          variant: EbicButtonVariant.outline,
          isFullWidth: true,
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.mainShell,
              (r) => false,
              arguments: 0,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // PAYMENT FAILURE VIEW
  // ==========================================
  Widget _buildFailureView({
    required BuildContext context,
    required bool isDark,
    required String planName,
    required int durationMonths,
    required double amountPaid,
    required String? errorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),

        // 1. Failure Icon Badge
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.danger.withOpacity(0.4), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withOpacity(0.15),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.close_rounded, size: 48, color: AppColors.danger),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Title & Explanation
        Text(
          'Payment Unsuccessful',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.slate900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We were unable to complete the payment for your Health Pass subscription.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate600, height: 1.4),
        ),
        const SizedBox(height: 22),

        // 3. Failure Reason & Refund Reassurance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.danger.withOpacity(0.4) : const Color(0xFFFECACA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Transaction Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage != null && errorMessage.isNotEmpty
                    ? errorMessage
                    : 'The transaction was cancelled or declined by your bank / payment service provider.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.slate300 : const Color(0xFF7F1D1D),
                  height: 1.35,
                ),
              ),
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If any amount was debited from your account, it will be automatically refunded to your original payment method within 3–5 business days.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Plan Attempted Card
        EbicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ATTEMPTED SUBSCRIPTION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              _receiptRow('Selected Plan', planName, isDark),
              const SizedBox(height: 8),
              _receiptRow('Term Duration', '$durationMonths ${durationMonths == 1 ? 'Month' : 'Months'}', isDark),
              if (amountPaid > 0) ...[
                const SizedBox(height: 8),
                _receiptRow('Order Total', '₹${amountPaid.toInt()}', isDark, isHighlight: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 5. Recovery Actions
        EbicButton(
          label: 'Retry Payment',
          isFullWidth: true,
          onPressed: () {
            // Pop back to the quote review screen to retry checkout
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 10),
        EbicButton(
          label: 'Explore Other Plans',
          variant: EbicButtonVariant.outline,
          isFullWidth: true,
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.healthPassPlans,
              (r) => r.isFirst,
            );
          },
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Contact Customer Support', style: TextStyle(fontSize: 12.5)),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.support);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _receiptRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500)),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? AppColors.primary
                : (isDark ? Colors.white : AppColors.slate900),
          ),
        ),
      ],
    );
  }
}
