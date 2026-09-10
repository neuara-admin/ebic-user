import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();

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
      await _auth.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.user;
    final name = user?['name'] ?? 'EBIC Valued Customer';
    final phone = user?['phoneNumber'] ?? user?['phone'] ?? '+91 98765 43210';
    final email = user?['email'] ?? 'customer@everybitecounts.com';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Account & Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header Card
              EbicCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900)),
                          const SizedBox(height: 2),
                          Text(phone, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                          Text(email, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 59 Profile Structure Group 1: Household & Service Delivery
              const Text('Household & Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.family_restroom_rounded,
                title: 'Household & Family Members',
                subtitle: 'Manage family health profiles & covered members',
                onTap: () => Navigator.pushNamed(context, AppRoutes.household),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.location_on_outlined,
                title: 'Saved Kitchen Addresses',
                subtitle: 'Delivery addresses with serviceability checks',
                onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
              ),
              const SizedBox(height: 20),

              // Group 2: Health Suite
              const Text('Health Pass & Diet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.health_and_safety_outlined,
                title: 'Health Pass Subscription',
                subtitle: 'Membership tier, entitlements & benefits',
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.medical_services_outlined,
                title: 'Dietitian Consultations',
                subtitle: 'Upcoming sessions & clinical history',
                onTap: () => Navigator.pushNamed(context, AppRoutes.consultationsList),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.folder_shared_outlined,
                title: 'Health Documents Vault',
                subtitle: 'HIPAA encrypted diagnostic reports & prescriptions',
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
              ),
              const SizedBox(height: 20),

              // Group 3: Financial & Promos
              const Text('Payments & Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'EBIC Wallet & Credits',
                subtitle: 'Ledger balance, cashback & refund history',
                onTap: () => Navigator.pushNamed(context, AppRoutes.walletCredits),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.local_offer_outlined,
                title: 'Promotions & Coupons',
                subtitle: 'Active discounts & referral rewards',
                onTap: () => Navigator.pushNamed(context, AppRoutes.promotions),
              ),
              const SizedBox(height: 20),

              // Group 4: Support & Security
              const Text('Support & Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.support_agent_rounded,
                title: 'Help & Customer Support',
                subtitle: 'Raise tickets, FAQs & live resolution',
                onTap: () => Navigator.pushNamed(context, AppRoutes.support),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notification Preferences',
                subtitle: 'Real-time chef alerts & meal reminders',
                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.lock_person_outlined,
                title: 'Privacy & Member Data Consent',
                subtitle: 'Member-specific health data authorization',
                onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
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
              const Center(
                child: Text(
                  'EBIC Customer App • V1.0.0 (Production Build)',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
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
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.slate700, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
        ],
      ),
    );
  }
}
