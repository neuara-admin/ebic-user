import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/bmi_health_widget.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/member_switcher_widget.dart';
import 'widgets/avatar_picker_sheet.dart';
import 'widgets/email_otp_sheet.dart';

/// Customer Profile & Account Dashboard Screen
/// Features Bento UI architecture, family switcher, clinical vitals summary,
/// household management, and comprehensive account settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiClient _api = ApiClient();
  bool _showVitals = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => MemberContext().loadMembers());
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    if (!_auth.isAuthenticated) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
      if (res.success && res.data != null) {
        final updatedUser = Map<String, dynamic>.from(_auth.user ?? {});
        updatedUser['name'] = res.data!['name'];
        updatedUser['email'] = res.data!['email'];
        updatedUser['phone'] = res.data!['phone'];
        updatedUser['avatarUrl'] = res.data!['avatarUrl'];
        updatedUser['emailVerified'] = res.data!['emailVerified'];
        updatedUser['phoneVerified'] = res.data!['phoneVerified'];
        _auth.updateCurrentUser(updatedUser);
        await TokenStorage.saveUser(
          id: res.data!['id'] ?? '',
          phone: res.data!['phone'] ?? '',
          name: res.data!['name'],
          email: res.data!['email'],
          avatarUrl: res.data!['avatarUrl'],
        );
      }
      await MemberContext().loadMembers(forceRefresh: true);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out of EBIC'),
        content: const Text(
          'Are you sure you want to sign out? Your household health profiles and active diet plans will remain securely saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      MemberContext().clearContext();
      await _auth.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAuthed = _auth.isAuthenticated;
    final user = _auth.user;
    final rawName = user?['name'] as String?;
    final hasName = rawName != null && rawName.trim().isNotEmpty;
    final name = hasName ? rawName.trim() : (isAuthed ? 'Add your name' : 'Guest User');

    final rawPhone = (user?['phone'] ?? user?['phoneNumber']) as String?;
    final hasPhone = rawPhone != null && rawPhone.trim().isNotEmpty;
    final phone = hasPhone ? rawPhone.trim() : '';

    final rawEmail = user?['email'] as String?;
    final hasEmail = rawEmail != null && rawEmail.trim().isNotEmpty;
    final email = hasEmail ? rawEmail.trim() : (isAuthed ? 'No email address added' : 'Tap to sign in or create account');
    final avatarUrl = user?['avatarUrl'] as String?;
    final isEmailVerified = user?['emailVerified'] == true;
    final isPhoneVerified = user?['phoneVerified'] == true;

    HouseholdMemberModel? selfMember;
    for (final m in MemberContext().members) {
      if (m.isSelf || m.relationship.toUpperCase() == 'SELF') {
        selfMember = m;
        break;
      }
    }
    selfMember ??= MemberContext().members.isNotEmpty ? MemberContext().members.first : null;
    final membersCount = MemberContext().members.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account & Profile'),
        elevation: 0,
        actions: [
          if (isAuthed)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                  if (updated == true && mounted) {
                    await _refreshProfile();
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppColors.primarySubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppColors.primary,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO USER PROFILE BENTO CARD
                _buildHeroProfileCard(
                  context: context,
                  isDark: isDark,
                  hasName: hasName,
                  name: name,
                  hasPhone: hasPhone,
                  phone: phone,
                  hasEmail: hasEmail,
                  email: email,
                  avatarUrl: avatarUrl,
                  isPhoneVerified: isPhoneVerified,
                  isEmailVerified: isEmailVerified,
                ),
                const SizedBox(height: 16),

                // 2. BENTO DASHBOARD QUICK STATS GRID (2x2)
                _buildBentoQuickStatsGrid(
                  context: context,
                  isDark: isDark,
                  membersCount: membersCount,
                  selfMember: selfMember,
                ),
                const SizedBox(height: 16),

                // 3. HEALTH VITALS, BMI & DIETARY PROFILE BENTO CARD
                _buildHealthVitalsBento(
                  context: context,
                  isDark: isDark,
                  selfMember: selfMember,
                ),
                const SizedBox(height: 16),

                // 4. ACTIVE HOUSEHOLD MEMBER SWITCHER
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ACTIVE HOUSEHOLD MEMBER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const MemberSwitcherBar(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. BENTO MENU GROUPS
                // Group 1: Household & Delivery
                _buildMenuGroup(
                  isDark: isDark,
                  title: 'Household & Delivery',
                  icon: Icons.home_work_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  children: [
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.family_restroom_rounded,
                      iconColor: const Color(0xFF4F46E5),
                      iconBgColor: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                      title: 'Household & Family Members',
                      subtitle: 'Manage profiles, dietary restrictions & health bios',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                        ),
                        child: Text(
                          '$membersCount ${membersCount == 1 ? 'MEMBER' : 'MEMBERS'}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.household),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFE11D48),
                      iconBgColor: isDark ? const Color(0xFF881337) : const Color(0xFFFFF1F2),
                      title: 'Saved Kitchen Addresses',
                      subtitle: 'Delivery kitchens with live hub serviceability',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF475569),
                      iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      title: 'Preferences & Language',
                      subtitle: 'Theme appearance, notifications & display language',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.preferences),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Group 2: Health Pass & Clinical Suite
                _buildMenuGroup(
                  isDark: isDark,
                  title: 'Health Pass & Clinical Suite',
                  icon: Icons.health_and_safety_rounded,
                  iconColor: const Color(0xFF059669),
                  children: [
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.workspace_premium_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                      title: 'Health Pass Subscription',
                      subtitle: 'Membership tier, entitlements & chef discounts',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, size: 12, color: Color(0xFFB45309)),
                            SizedBox(width: 4),
                            Text(
                              'VIP ACTIVE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.healthPass),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.medical_services_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                      title: 'Dietitian Consultations',
                      subtitle: 'Scheduled appointments & clinical nutrition advice',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.folder_shared_rounded,
                      iconColor: const Color(0xFF0D9488),
                      iconBgColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                      title: 'Health Documents Vault',
                      subtitle: 'HIPAA-encrypted blood reports & medical prescriptions',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.devices_other_rounded,
                      iconColor: const Color(0xFF0284C7),
                      iconBgColor: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
                      title: 'Connected Health Sources',
                      subtitle: 'Apple Health, Health Connect, Garmin & smart scales',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.connectedSources),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Group 3: Financial & Promos
                _buildMenuGroup(
                  isDark: isDark,
                  title: 'Payments & Rewards',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFFCA8A04),
                  children: [
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.stars_rounded,
                      iconColor: const Color(0xFFCA8A04),
                      iconBgColor: isDark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3),
                      title: 'EBIC Credits Wallet',
                      subtitle: 'Promotional, referral & refund credits balance',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.walletCredits),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.card_giftcard_rounded,
                      iconColor: const Color(0xFF9333EA),
                      iconBgColor: isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF),
                      title: 'Refer & Earn',
                      subtitle: 'Invite friends and earn ₹250 wallet credits per referral',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.referrals),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.local_offer_rounded,
                      iconColor: const Color(0xFFDB2777),
                      iconBgColor: isDark ? const Color(0xFF831843) : const Color(0xFFFCE7F3),
                      title: 'Promotions & Coupons',
                      subtitle: 'Active chef vouchers, discounts & partner codes',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.promotions),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Group 4: Support & Security
                _buildMenuGroup(
                  isDark: isDark,
                  title: 'Support & Security',
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF2563EB),
                  children: [
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.support_agent_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                      title: 'Help & Customer Support',
                      subtitle: 'Live resolution, FAQ knowledge base & ticket tracker',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.support),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.lock_person_rounded,
                      iconColor: const Color(0xFF64748B),
                      iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      title: 'Privacy & Member Data Consent',
                      subtitle: 'Member health data sharing and clinical authorization',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
                    ),
                    _buildMenuRow(
                      isDark: isDark,
                      icon: Icons.security_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBgColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFEDE9FE),
                      title: 'Account Security & Sessions',
                      subtitle: 'Two-factor auth, verified devices & login sessions',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.security),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 6. SIGN OUT BUTTON
                if (isAuthed) ...[
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _logout();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(isDark ? 0.15 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Logout of EBIC',
                            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  EbicButton(
                    label: 'Sign In or Create Account',
                    icon: Icons.login_rounded,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.welcome),
                  ),
                ],
                const SizedBox(height: 24),

                // 7. BRAND APP FOOTER
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EBIC Neuara • Premium Health & Culinary Care',
                            style: TextStyle(
                              color: isDark ? AppColors.slate400 : AppColors.slate600,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0 (Build 42) • HIPAA & DPDP Compliant',
                        style: TextStyle(
                          color: isDark ? AppColors.slate500 : AppColors.slate400,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HERO PROFILE BENTO CARD ---
  Widget _buildHeroProfileCard({
    required BuildContext context,
    required bool isDark,
    required bool hasName,
    required String name,
    required bool hasPhone,
    required String phone,
    required bool hasEmail,
    required String email,
    required String? avatarUrl,
    required bool isPhoneVerified,
    required bool isEmailVerified,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Camera Badge (clean without outer border)
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final updated = await AvatarPickerSheet.show(context, currentAvatarUrl: avatarUrl);
                    if (updated == true && mounted) {
                      await _refreshProfile();
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? Image.network(
                                  AppConfig.resolveMediaUrl(avatarUrl) ?? avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(hasName, name, hasPhone),
                                )
                              : _buildAvatarFallback(hasName, name, hasPhone),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.slate900 : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                    const SizedBox(width: 16),

                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: hasName
                                        ? (isDark ? Colors.white : AppColors.slate900)
                                        : AppColors.slate500,
                                    fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                              ),
                              // VIP Member Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFB45309)),
                                    SizedBox(width: 3),
                                    Text(
                                      'VIP',
                                      style: TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasPhone) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 12, color: isDark ? AppColors.slate400 : AppColors.slate500),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: isDark ? AppColors.slate300 : AppColors.slate600,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 12, color: isDark ? AppColors.slate400 : AppColors.slate500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    color: hasEmail ? (isDark ? AppColors.slate400 : AppColors.slate600) : AppColors.slate400,
                                    fontSize: 12,
                                    fontStyle: hasEmail ? FontStyle.normal : FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? AppColors.slate800 : AppColors.slate200),
                const SizedBox(height: 12),

                // Verification Chips Wrap
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasPhone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isPhoneVerified ? AppColors.emerald50 : AppColors.amber50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPhoneVerified
                                ? AppColors.emerald700.withOpacity(0.2)
                                : AppColors.amber700.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPhoneVerified ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              size: 11,
                              color: isPhoneVerified ? AppColors.emerald700 : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPhoneVerified ? 'PHONE VERIFIED' : 'PHONE UNVERIFIED',
                              style: TextStyle(
                                color: isPhoneVerified ? AppColors.emerald700 : AppColors.warning,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasEmail)
                      InkWell(
                        onTap: isEmailVerified
                            ? null
                            : () async {
                                HapticFeedback.lightImpact();
                                final verified = await EmailOtpSheet.show(context, email: email);
                                if (verified == true && mounted) {
                                  await _refreshProfile();
                                }
                              },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isEmailVerified ? AppColors.emerald50 : AppColors.amber50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isEmailVerified
                                  ? AppColors.emerald700.withOpacity(0.2)
                                  : AppColors.amber700.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEmailVerified ? Icons.check_circle_rounded : Icons.mail_lock_rounded,
                                size: 11,
                                color: isEmailVerified ? AppColors.emerald700 : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isEmailVerified ? 'EMAIL VERIFIED' : 'EMAIL UNVERIFIED — TAP TO VERIFY',
                                style: TextStyle(
                                  color: isEmailVerified ? AppColors.emerald700 : AppColors.warning,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () async {
                          final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                          if (updated == true && mounted) {
                            await _refreshProfile();
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppColors.amber50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.amber300),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline, size: 11, color: AppColors.amber800),
                              SizedBox(width: 4),
                              Text(
                                'ADD EMAIL',
                                style: TextStyle(
                                  color: AppColors.amber800,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildAvatarFallback(bool hasName, String name, bool hasPhone) {
    return Container(
      color: AppColors.primarySubtle,
      child: Center(
        child: Text(
          hasName ? name[0].toUpperCase() : (hasPhone ? 'C' : 'U'),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- BENTO DASHBOARD QUICK STATS GRID (2x2) ---
  Widget _buildBentoQuickStatsGrid({
    required BuildContext context,
    required bool isDark,
    required int membersCount,
    required HouseholdMemberModel? selfMember,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ACCOUNT DASHBOARD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildBentoTile(
                isDark: isDark,
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF4F46E5),
                iconBg: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                value: '$membersCount ${membersCount == 1 ? 'Profile' : 'Profiles'}',
                title: 'Household',
                subtitle: 'Family members',
                onTap: () => Navigator.pushNamed(context, AppRoutes.household),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoTile(
                isDark: isDark,
                icon: Icons.soup_kitchen_rounded,
                iconColor: const Color(0xFFE11D48),
                iconBg: isDark ? const Color(0xFF881337) : const Color(0xFFFFF1F2),
                value: 'Kitchens',
                title: 'Addresses',
                subtitle: 'Delivery hubs',
                onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBentoTile(
                isDark: isDark,
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                value: 'EBIC Credits',
                title: 'Wallet',
                subtitle: 'Rewards & ledger',
                onTap: () => Navigator.pushNamed(context, AppRoutes.walletCredits),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoTile(
                isDark: isDark,
                icon: Icons.monitor_heart_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                value: selfMember?.bmi != null ? 'BMI ${selfMember!.bmi!.toStringAsFixed(1)}' : 'Vitals Log',
                title: 'Metabolic Bio',
                subtitle: selfMember?.bmi != null ? 'Active' : 'Tap to set',
                onTap: () {
                  setState(() => _showVitals = true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? AppColors.slate600 : AppColors.slate400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEALTH VITALS & BMI BENTO CARD ---
  Widget _buildHealthVitalsBento({
    required BuildContext context,
    required bool isDark,
    required HouseholdMemberModel? selfMember,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.favorite_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'HEALTH VITALS & METABOLIC BIO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showVitals = !_showVitals);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showVitals ? AppColors.primarySubtle : (isDark ? AppColors.slate800 : AppColors.slate100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showVitals ? AppColors.primary.withOpacity(0.3) : (isDark ? AppColors.slate700 : AppColors.slate300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showVitals ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 13,
                        color: _showVitals ? AppColors.primaryDark : AppColors.slate700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showVitals ? 'Hide' : 'View',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _showVitals ? AppColors.primaryDark : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_showVitals)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showVitals = true);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800.withOpacity(0.6) : AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical Vitals Protected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Height, weight, DOB and BMI metrics are secured for privacy.',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.touch_app_outlined, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            )
          else ...[
            // 3-Metric Tiles: Height, Weight, Age/DOB
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Height', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                        const SizedBox(height: 2),
                        Text(
                          selfMember?.heightDisplay ?? 'Not set',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: isDark ? AppColors.slate700 : AppColors.slate200),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Weight', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                          const SizedBox(height: 2),
                          Text(
                            selfMember?.weightDisplay ?? 'Not set',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 28, color: isDark ? AppColors.slate700 : AppColors.slate200),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DOB & Age', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                          const SizedBox(height: 2),
                          Text(
                            selfMember?.dateOfBirth != null
                                ? '${selfMember!.formattedDob} (${selfMember.age}y)'
                                : 'Not set',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // BMI Gauge or Prompt Card
            if (selfMember?.bmi != null || (selfMember?.heightCm != null && selfMember?.weightKg != null))
              BmiHealthWidget(
                bmi: selfMember?.bmi,
                heightCm: selfMember?.heightCm,
                weightKg: selfMember?.weightKg,
              )
            else
              InkWell(
                onTap: () async {
                  final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                  if (updated == true && mounted) {
                    await _refreshProfile();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_chart_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add height, weight and DOB to calculate live BMI and unlock personalized chef nutrition.',
                          style: TextStyle(fontSize: 12, color: AppColors.slate700),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),

            // Dietary & Health Conditions Chips
            if (selfMember != null &&
                (selfMember.dietaryPreferences.isNotEmpty ||
                    selfMember.medicalConditions.isNotEmpty ||
                    selfMember.allergies.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...selfMember.dietaryPreferences.map((d) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.emerald700.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu, size: 11, color: AppColors.emerald700),
                            const SizedBox(width: 4),
                            Text(
                              d,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald700,
                              ),
                            ),
                          ],
                        ),
                      )),
                  ...selfMember.medicalConditions.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.healing, size: 11, color: Color(0xFFB45309)),
                            const SizedBox(width: 4),
                            Text(
                              c,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      )),
                  ...selfMember.allergies.map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFBE123C)),
                            const SizedBox(width: 4),
                            Text(
                              a,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                      if (updated == true && mounted) {
                        await _refreshProfile();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                    label: const Text('Update Health Bio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showVitals = false);
                  },
                  icon: const Icon(Icons.visibility_off_outlined, size: 14, color: AppColors.slate600),
                  label: const Text('Hide', style: TextStyle(fontSize: 12, color: AppColors.slate700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- MENU GROUP BUILDER ---
  Widget _buildMenuGroup({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  // --- MENU ROW BUILDER ---
  Widget _buildMenuRow({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark ? AppColors.slate600 : AppColors.slate400,
                      ),
                ],
              ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: isDark ? AppColors.slate800 : AppColors.slate100,
              ),
          ],
        ),
      ),
    );
  }
}
