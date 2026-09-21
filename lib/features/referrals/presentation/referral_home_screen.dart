import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ebic_card.dart';
import '../../../shared/widgets/ebic_button.dart';
import '../data/referral_models.dart';
import '../data/referral_repository.dart';
import 'widgets/referral_detail_sheet.dart';

class ReferralHomeScreen extends StatefulWidget {
  const ReferralHomeScreen({super.key});

  @override
  State<ReferralHomeScreen> createState() => _ReferralHomeScreenState();
}

class _ReferralHomeScreenState extends State<ReferralHomeScreen> {
  final ReferralRepository _repo = ReferralRepository();
  bool _isLoading = true;
  String? _errorMessage;
  ReferralDashboardModel? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _repo.getDashboard();
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _dashboard = res.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.message ?? 'Unable to load referral details. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Referral code "$code" copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInvite() {
    if (_dashboard == null) return;
    final code = _dashboard!.referralCode;
    final url = _dashboard!.shareUrl;
    final camp = _dashboard!.activeCampaign;

    final referrerAmt = camp?.referrerRewardAmount.toStringAsFixed(0) ?? '250';
    final refereeAmt = camp?.refereeRewardAmount.toStringAsFixed(0) ?? '150';

    final text = 'Join me on EBIC — Every Bite Counts!\n'
        'Get ₹$refereeAmt off your first Health Pass or Chef-at-home booking with my invite (and I get ₹$referrerAmt)!\n\n'
        'Use referral code: $code\n'
        'Or tap: $url';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite link & message copied!', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Paste directly into WhatsApp, SMS, or any chat app.', style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.emerald700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Referral History',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.referralHistory),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _dashboard == null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Hero Card
                        _buildHeroCard(),
                        const SizedBox(height: 16),

                        // 2. Referral Code Card
                        _buildCodeCard(isDark),
                        const SizedBox(height: 16),

                        // 3. Reward Information Card
                        _buildRewardInfoCard(isDark),
                        const SizedBox(height: 16),

                        // 4. Statistics Card (Invited, Qualified, Rewarded)
                        _buildStatsCard(isDark),
                        const SizedBox(height: 20),

                        // 5. Recent Referrals & History Link
                        _buildRecentReferralsSection(isDark),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeroCard() {
    final camp = _dashboard?.activeCampaign;
    final rewardText = camp != null
        ? 'Earn ₹${camp.referrerRewardAmount.toStringAsFixed(0)} wallet credits for every friend who joins & qualifies.'
        : 'Share EBIC with your friends and earn rewards when they qualify.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'GIVE ₹150 • GET ₹250',
              style: TextStyle(
                color: AppColors.primarySubtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Invite friends to EBIC',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rewardText,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          EbicButton(
            label: 'Invite Friends',
            icon: Icons.share_rounded,
            onPressed: _shareInvite,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(bool isDark) {
    final code = _dashboard?.referralCode ?? '------';

    return EbicCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR REFERRAL CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: AppColors.primary,
                      tooltip: 'Copy Code',
                      onPressed: () => _copyCode(code),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      color: AppColors.primary,
                      tooltip: 'Share',
                      onPressed: _shareInvite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardInfoCard(bool isDark) {
    final camp = _dashboard?.activeCampaign;
    final qualCondition = camp?.humanReadableQualification ?? 'First successful Health Pass purchase or Chef booking';

    return EbicCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Earn rewards for successful referrals',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invite your friends and receive rewards when they complete their qualifying action: $qualCondition.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rewards are credited directly to your EBIC Wallet balance and never expire.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    final stats = _dashboard?.stats ?? const ReferralStatsModel(invited: 0, qualified: 0, rewarded: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Invited', '${stats.invited}', AppColors.slate700, isDark),
          Container(width: 1, height: 36, color: isDark ? AppColors.slate800 : AppColors.slate200),
          _buildStatColumn('Qualified', '${stats.qualified}', AppColors.amber700, isDark),
          Container(width: 1, height: 36, color: isDark ? AppColors.slate800 : AppColors.slate200),
          _buildStatColumn('Rewards', '${stats.rewarded}', AppColors.primary, isDark),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentReferralsSection(bool isDark) {
    final recents = _dashboard?.recentReferrals ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Referrals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            if (recents.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.referralHistory),
                child: const Text('View All →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (recents.isEmpty)
          _buildEmptyState(isDark)
        else
          Column(
            children: recents.map((item) => _buildReferralCard(item, isDark)).toList(),
          ),
      ],
    );
  }

  Widget _buildReferralCard(ReferralItemModel item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          item.friendName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Joined: ${item.joinedDateDisplay}',
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBadge(item.humanStatus, item.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
          ],
        ),
        onTap: () => ReferralDetailSheet.show(context, item),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: isDark ? AppColors.slate600 : AppColors.slate400),
          const SizedBox(height: 10),
          Text(
            'No referrals yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Invite your friends to EBIC and track your rewards here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _shareInvite,
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Invite Friends'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String displayLabel, String rawStatus) {
    Color bg;
    Color fg;

    switch (rawStatus.toUpperCase()) {
      case 'REWARDED':
        bg = AppColors.emerald50;
        fg = AppColors.emerald700;
        break;
      case 'QUALIFIED':
      case 'REWARD_PENDING':
        bg = AppColors.primarySubtle;
        fg = AppColors.primaryDark;
        break;
      case 'REGISTERED':
      case 'ATTRIBUTED':
      case 'ELIGIBLE':
        bg = AppColors.amber50;
        fg = AppColors.amber800;
        break;
      default:
        bg = AppColors.slate100;
        fg = AppColors.slate600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.slate700),
            ),
            const SizedBox(height: 18),
            EbicButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadDashboard,
            ),
          ],
        ),
      ),
    );
  }
}
