import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_button.dart';

/// Module 2 Section 14 — Onboarding Screen (Sections 6.1–6.3)
/// Introduces EBIC core pillars (Personalized Nutrition, In-Home Chefs, Health Pass)
/// and records completion locally in LocalPreferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      badge: 'PERSONALIZED NUTRITION',
      title: 'Dietitian Care Tailored to You',
      description:
          'Consult with certified clinical dietitians to establish your exact calorie, protein, and dietary targets. Get customized meal plans built for your unique lifestyle.',
      icon: Icons.health_and_safety_rounded,
      accentColor: AppColors.primary,
    ),
    _OnboardingPageData(
      badge: 'IN-HOME CHEFS',
      title: 'Freshly Cooked in Your Kitchen',
      description:
          'Professional, verified chefs arrive at your doorstep to prepare delicious, healthy meals matching your diet plan. Clean preparation, fresh ingredients, zero hassle.',
      icon: Icons.restaurant_menu_rounded,
      accentColor: AppColors.primaryDark,
    ),
    _OnboardingPageData(
      badge: 'HEALTH PASS & TRACKING',
      title: 'Track Every Bite & Vital Metric',
      description:
          'Monitor body vitals, water, activity, and nutrition with interactive insights. Unlock unlimited chef bookings and clinical consultations with Health Pass memberships.',
      icon: Icons.insights_rounded,
      accentColor: AppColors.secondary,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await LocalPreferences.getInstance();
    await prefs.setOnboardingCompleted(true);
    await AnalyticsService().logOnboardingCompleted();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.welcome);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo mark
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EBIC',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hero Icon Card with gradient aura
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                page.accentColor.withOpacity(0.35),
                                page.accentColor.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [page.accentColor, page.accentColor.withOpacity(0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: page.accentColor.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(page.icon, color: Colors.white, size: 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Pill badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: page.accentColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: page.accentColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            page.badge,
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom controls: Page Indicators & Action CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.primaryLight : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Button
                  EbicButton(
                    label: isLast ? 'Get Started' : 'Next',
                    icon: isLast ? Icons.arrow_forward_rounded : null,
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _OnboardingPageData({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}
