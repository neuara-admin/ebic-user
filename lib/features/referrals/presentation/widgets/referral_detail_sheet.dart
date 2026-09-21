import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_models.dart';

class ReferralDetailSheet extends StatelessWidget {
  final ReferralItemModel referral;

  const ReferralDetailSheet({super.key, required this.referral});

  static Future<void> show(BuildContext context, ReferralItemModel referral) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReferralDetailSheet(referral: referral),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.slate900 : Colors.white;

    final isQualified = referral.status == 'QUALIFIED' || referral.status == 'REWARD_PENDING' || referral.status == 'REWARDED';
    final isRewarded = referral.status == 'REWARDED' || referral.rewardStatus == 'ISSUED';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referral Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${referral.id.length > 8 ? referral.id.substring(0, 8).toUpperCase() : referral.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(referral.status),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Attributes summary
          _buildDetailRow(
            context,
            icon: Icons.person_rounded,
            label: 'Friend',
            value: referral.friendName,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            context,
            icon: Icons.calendar_today_rounded,
            label: 'Joined EBIC',
            value: referral.joinedDateDisplay,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            context,
            icon: Icons.verified_rounded,
            label: 'Qualification',
            value: isQualified ? 'Completed' : 'Pending qualifying booking/order',
            isDark: isDark,
            valueColor: isQualified ? AppColors.emerald700 : AppColors.amber700,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Reward',
            value: isRewarded
                ? '₹${referral.rewardAmount?.toStringAsFixed(0) ?? '250'} Credited to Wallet'
                : (isQualified ? 'Processing (Pending approval)' : 'Unlocks after friend completes service'),
            isDark: isDark,
            valueColor: isRewarded ? AppColors.primary : (isQualified ? AppColors.amber700 : AppColors.slate500),
          ),
          const SizedBox(height: 20),

          // Timeline Section
          Text(
            'Timeline & Milestones',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slate800,
            ),
          ),
          const SizedBox(height: 12),

          _buildTimelineStep(
            context,
            title: 'Friend Joined',
            subtitle: referral.joinedDateDisplay,
            isDone: true,
            isLast: false,
          ),
          _buildTimelineStep(
            context,
            title: 'Qualifying Action Completed',
            subtitle: isQualified
                ? (referral.qualifiedAt != null ? DateFormat('dd MMM yyyy').format(referral.qualifiedAt!) : 'Completed')
                : 'Awaiting first pass/chef booking',
            isDone: isQualified,
            isLast: false,
          ),
          _buildTimelineStep(
            context,
            title: 'Wallet Reward Credited',
            subtitle: isRewarded ? 'Credited to EBIC Wallet' : 'Automatic credit after review',
            isDone: isRewarded,
            isLast: true,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: isDark ? AppColors.slate300 : AppColors.slate600),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : AppColors.slate800),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.primary : AppColors.slate200,
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 12 : 6,
                  color: isDone ? Colors.white : AppColors.slate400,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? AppColors.primary : AppColors.slate200,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDone ? AppColors.slate900 : AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDone ? AppColors.slate600 : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'REWARDED':
        bg = AppColors.emerald50;
        fg = AppColors.emerald700;
        text = 'REWARDED';
        break;
      case 'QUALIFIED':
      case 'REWARD_PENDING':
        bg = AppColors.primarySubtle;
        fg = AppColors.primaryDark;
        text = 'QUALIFIED';
        break;
      case 'REGISTERED':
      case 'ATTRIBUTED':
      case 'ELIGIBLE':
        bg = AppColors.amber50;
        fg = AppColors.amber800;
        text = 'PENDING';
        break;
      default:
        bg = AppColors.slate100;
        fg = AppColors.slate600;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
