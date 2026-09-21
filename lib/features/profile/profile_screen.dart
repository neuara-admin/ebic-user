import 'package:flutter/material.dart';
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
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/member_switcher_widget.dart';
import 'widgets/avatar_picker_sheet.dart';
import 'widgets/email_otp_sheet.dart';

/// Module 3 — Sections 23 & 24: Customer Profile Screen
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
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out of your EBIC account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
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

    final user = _auth.user;
    final rawName = user?['name'] as String?;
    final hasName = rawName != null && rawName.trim().isNotEmpty;
    final name = hasName ? rawName.trim() : 'Add your name';

    final rawPhone = (user?['phone'] ?? user?['phoneNumber']) as String?;
    final hasPhone = rawPhone != null && rawPhone.trim().isNotEmpty;
    final phone = hasPhone ? rawPhone.trim() : '';

    final rawEmail = user?['email'] as String?;
    final hasEmail = rawEmail != null && rawEmail.trim().isNotEmpty;
    final email = hasEmail ? rawEmail.trim() : 'No email address added';
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account & Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
              if (updated == true && mounted) {
                await _refreshProfile();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppColors.primary,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Header Card (Section 5 & 6)
                EbicCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                      if (updated == true && mounted) {
                        await _refreshProfile();
                      }
                    },
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final updated = await AvatarPickerSheet.show(context, currentAvatarUrl: avatarUrl);
                                if (updated == true && mounted) {
                                  await _refreshProfile();
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                        ? Image.network(
                                            AppConfig.resolveMediaUrl(avatarUrl) ?? avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                hasName
                                                    ? name[0].toUpperCase()
                                                    : (hasPhone ? 'C' : 'U'),
                                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              hasName
                                                  ? name[0].toUpperCase()
                                                  : (hasPhone ? 'C' : 'U'),
                                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: hasName
                                          ? (isDark ? Colors.white : AppColors.slate900)
                                          : AppColors.slate500,
                                      fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                  if (hasPhone) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      phone,
                                      style: TextStyle(
                                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: hasEmail ? AppColors.slate500 : AppColors.slate400,
                                      fontSize: 12,
                                      fontStyle: hasEmail ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
                              onPressed: () async {
                                final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                                if (updated == true && mounted) {
                                  await _refreshProfile();
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        // Verification Status Chips (Section 14)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hasPhone)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isPhoneVerified ? AppColors.emerald50 : AppColors.amber50,
                                    borderRadius: BorderRadius.circular(4),
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
                                        isPhoneVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 12,
                                        color: isPhoneVerified ? AppColors.emerald700 : AppColors.warning,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPhoneVerified ? 'PHONE VERIFIED' : 'PHONE UNVERIFIED',
                                        style: TextStyle(
                                          color: isPhoneVerified ? AppColors.emerald700 : AppColors.warning,
                                          fontSize: 10,
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
                                          final verified = await EmailOtpSheet.show(context, email: email);
                                          if (verified == true && mounted) {
                                            await _refreshProfile();
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isEmailVerified ? AppColors.emerald50 : AppColors.amber50,
                                      borderRadius: BorderRadius.circular(4),
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
                                          isEmailVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                                          size: 12,
                                          color: isEmailVerified ? AppColors.emerald700 : AppColors.warning,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isEmailVerified ? 'EMAIL VERIFIED' : 'EMAIL UNVERIFIED — TAP TO VERIFY',
                                          style: TextStyle(
                                            color: isEmailVerified ? AppColors.emerald700 : AppColors.warning,
                                            fontSize: 10,
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.amber50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.amber300),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle_outline, size: 12, color: AppColors.amber800),
                                        SizedBox(width: 4),
                                        Text(
                                          'ADD EMAIL',
                                          style: TextStyle(
                                            color: AppColors.amber800,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Health Vitals, BMI & Dietary Profile Section
                EbicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.favorite_rounded, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'HEALTH VITALS & BMI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                  color: AppColors.slate700,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showVitals = !_showVitals;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _showVitals ? AppColors.primarySubtle : AppColors.slate100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _showVitals ? AppColors.primary.withValues(alpha: 0.3) : AppColors.slate300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showVitals ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 14,
                                    color: _showVitals ? AppColors.primaryDark : AppColors.slate700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showVitals ? 'Hide' : 'View',
                                    style: TextStyle(
                                      fontSize: 12,
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

                      // When hidden: show a proper UI card with a prominent action button
                      if (!_showVitals)
                        InkWell(
                          onTap: () => setState(() => _showVitals = true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : AppColors.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySubtle,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Health Vitals & BMI Protected',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Height, weight, DOB and BMI are hidden for privacy.',
                                            style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Show Health Vitals & BMI',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Measurements row: Height, Weight, DOB
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate50,
                            borderRadius: BorderRadius.circular(10),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: AppColors.slate200),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 28, color: AppColors.slate200),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('DOB', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        selfMember?.dateOfBirth != null
                                            ? '${selfMember!.formattedDob} (${selfMember.age}y)'
                                            : 'Not set',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

                        // BMI Visual Card / Gauge
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
                                      'Add height, weight and DOB to calculate BMI and receive personalized nutrition recommendations.',
                                      style: TextStyle(fontSize: 12, color: AppColors.slate700),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Actions Row: Update Vitals & Hide
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final updated = await Navigator.pushNamed(context, AppRoutes.editProfile);
                                  if (updated == true && mounted) {
                                    await _refreshProfile();
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                label: const Text('Update Vitals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _showVitals = false),
                              icon: const Icon(Icons.visibility_off_outlined, size: 14, color: AppColors.slate600),
                              label: const Text('Hide', style: TextStyle(fontSize: 12, color: AppColors.slate700)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.slate300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Dietary & Health Conditions Tags
                      if (selfMember != null &&
                          (selfMember.dietaryPreferences.isNotEmpty || selfMember.medicalConditions.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...selfMember.dietaryPreferences.map((d) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 35: Central Member Switcher Bar
                const MemberSwitcherBar(),
                const SizedBox(height: 24),

                // Group 1: Household & Kitchen Addresses (Sections 25–31)
                Text('Household & Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.slate300 : AppColors.slate800)),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.family_restroom_rounded,
                  title: 'Household & Family Members',
                  subtitle: 'Manage family health profiles & covered members',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.household),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.location_on_outlined,
                  title: 'Saved Kitchen Addresses',
                  subtitle: 'Delivery addresses with live hub serviceability',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.tune_rounded,
                  title: 'Preferences & Language',
                  subtitle: 'App language, channels & display settings',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.preferences),
                ),
                const SizedBox(height: 20),

                // Group 2: Health Suite
                Text('Health Pass & Diet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.slate300 : AppColors.slate800)),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.health_and_safety_outlined,
                  title: 'Health Pass Subscription',
                  subtitle: 'Membership tier, entitlements & benefits',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.healthPass),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.medical_services_outlined,
                  title: 'Dietitian Consultations',
                  subtitle: 'Upcoming sessions & clinical history',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.folder_shared_outlined,
                  title: 'Health Documents Vault',
                  subtitle: 'HIPAA encrypted diagnostic reports & prescriptions',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
                ),
                const SizedBox(height: 20),

                // Group 3: Financial & Promos
                Text('Payments & Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.slate300 : AppColors.slate800)),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'EBIC Wallet & Credits',
                  subtitle: 'Ledger balance, cashback & refund history',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.walletCredits),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.card_giftcard_rounded,
                  title: 'Refer & Earn',
                  subtitle: 'Invite friends, earn ₹250 wallet credits & track rewards',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.referrals),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.local_offer_outlined,
                  title: 'Promotions & Coupons',
                  subtitle: 'Active discounts & referral rewards',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.promotions),
                ),
                const SizedBox(height: 20),

                // Group 4: Support & Security
                Text('Support & Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.slate300 : AppColors.slate800)),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.support_agent_rounded,
                  title: 'Help & Customer Support',
                  subtitle: 'Raise tickets, FAQs & live resolution',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.support),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.lock_person_outlined,
                  title: 'Privacy & Member Data Consent',
                  subtitle: 'Member-specific health data authorization',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  isDark: isDark,
                  icon: Icons.security_rounded,
                  title: 'Account Security & Sessions',
                  subtitle: 'Password, verified channels & active devices',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.security),
                ),
                const SizedBox(height: 24),


                // Sign Out
                EbicCard(
                  onTap: _logout,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Logout of EBIC',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'EBIC Customer App • Module 3 Customer Profile & Household',
                    style: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return EbicCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isDark ? AppColors.primaryLight : AppColors.slate700, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: isDark ? AppColors.slate400 : AppColors.slate500, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? AppColors.slate600 : AppColors.slate400),
        ],
      ),
    );
  }
}
