import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/status_badge.dart';

class HealthPassScreen extends StatefulWidget {
  const HealthPassScreen({super.key});

  @override
  State<HealthPassScreen> createState() => _HealthPassScreenState();
}

class _HealthPassScreenState extends State<HealthPassScreen> {
  final ApiClient _api = ApiClient();
  MyHealthPassModel? _myPass;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPass();
  }

  Future<void> _fetchPass() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.healthPassCurrent);
      if (res.success && res.data != null) {
        setState(() {
          _myPass = MyHealthPassModel.fromJson(res.data!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _myPass = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPass,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _myPass == null ? _buildNoPassState() : _buildActivePassContent(_myPass!),
              ),
            ),
    );
  }

  Widget _buildNoPassState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.health_and_safety_outlined, size: 48, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "You don't have an active Health Pass",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlock dedicated clinical dietitians, personalized daily diet plans, health document vault, and chef booking benefits.',
            style: TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          EbicButton(
            label: 'Explore Health Pass Plans',
            icon: Icons.explore_outlined,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePassContent(MyHealthPassModel pass) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 9: Health Pass Overview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pass.planName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  StatusBadge(status: pass.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(dateFormat.format(pass.startDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(dateFormat.format(pass.endDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Covered Members', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${pass.coveredMembersCount} Members', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Health Modules Grid
        const Text(
          'Health Suite Features',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildFeatureTile(
                title: 'Dietitian',
                subtitle: 'Consult & Review',
                icon: Icons.medical_services_outlined,
                color: AppColors.primary,
                onTap: () => Navigator.pushNamed(context, AppRoutes.dietitian),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureTile(
                title: 'Diet Plan',
                subtitle: 'Personalized Meals',
                icon: Icons.restaurant_menu_rounded,
                color: AppColors.accent,
                onTap: () => Navigator.pushNamed(context, AppRoutes.dietPlan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeatureTile(
                title: 'Health Profile',
                subtitle: 'Vitals & BMI',
                icon: Icons.monitor_heart_outlined,
                color: AppColors.secondary,
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthProfile),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureTile(
                title: 'Documents',
                subtitle: 'Lab & Diagnostics',
                icon: Icons.folder_shared_outlined,
                color: AppColors.purple500,
                onTap: () => Navigator.pushNamed(context, AppRoutes.healthDocuments),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Health Pass Benefits Checklist (Section 9)
        const Text(
          'Active Benefits & Entitlements',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 12),

        EbicCard(
          child: Column(
            children: pass.benefits.map((benefit) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(fontSize: 13, color: AppColors.slate700, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Renewal / Change Plan
        EbicButton(
          label: 'Upgrade / Renew Pass',
          icon: Icons.workspace_premium_outlined,
          variant: EbicButtonVariant.outline,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPassPlans),
        ),
      ],
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return EbicCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
