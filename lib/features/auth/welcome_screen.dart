import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Aesthetics
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.slate950, AppColors.slate900, Color(0xFF064E3B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            // Icon badge
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primaryLight, size: 36),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Precision Nutrition,\nPrepared In Your Kitchen.',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Book certified in-home chefs for healthy, calorie-counted meals tailored to your Health Pass dietitian plan.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.75),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Feature highlights
                            _buildFeatureRow(Icons.timer_outlined, 'Instant Chef Visits & Real-Time Tracking'),
                            const SizedBox(height: 12),
                            _buildFeatureRow(Icons.health_and_safety_outlined, 'Clinical Dietitian Plans & Health Pass'),
                            const SizedBox(height: 12),
                            _buildFeatureRow(Icons.checklist_rounded, 'Automated Ingredient Preparation Checklists'),
                            const Spacer(),
                            const SizedBox(height: 24),
                            // Action buttons per Module 2 Section 6.1
                            EbicButton(
                              label: 'Create Account',
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.register);
                              },
                            ),
                            const SizedBox(height: 12),
                            EbicButton(
                              label: 'Sign In with Phone / OTP',
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.login);
                              },
                              isOutlined: true,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
