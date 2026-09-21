import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../health_pass/data/health_pass_repository.dart';

/// Module 4 — Section 24–30: Book a Home Chef
/// Accessible ONLY to customers with an active EBIC Health Pass.
/// Non-subscribers and expired users are redirected to browse the recipe menu.
class BookingTypeScreen extends StatefulWidget {
  const BookingTypeScreen({super.key});

  @override
  State<BookingTypeScreen> createState() => _BookingTypeScreenState();
}

class _BookingTypeScreenState extends State<BookingTypeScreen> {
  bool _isCheckingPass = true;
  ActiveHealthPassModel? _activePass;

  // Curated Culinary Config for Chef Booking Options
  final Map<String, dynamic> _screenConfig = {
    'heroTitle': 'Certified Chef in Your Kitchen',
    'heroSubtitle': 'Fresh, healthy meals cooked live using your own cookware and clean ingredients.',
    'videoTeaserUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'assignedMeal': {
      'title': 'Cook My Diet Plan',
      'badge': 'RECOMMENDED • CLINICALLY TAILORED',
      'subtitle': 'Nutritionist-approved meals customized for your household',
      'description': 'Enjoy balanced meals tailored to your health goals, calorie targets, and dietary preferences.',
      'imageUrl': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80',
      'tags': ['Healthy & Balanced', 'Family Diet Plans', 'Zero Hassle'],
      'buttonText': 'Cook Diet Plan',
    },
    'catalogueMeal': {
      'title': "Chef's Menu",
      'badge': 'CUSTOM DISHES • ON-DEMAND',
      'subtitle': 'Choose from 50+ delicious, wholesome recipes',
      'description': 'Handpick dishes across high-protein, low-carb, and comfort categories with custom servings.',
      'imageUrl': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
      'tags': ['50+ Healthy Recipes', 'Custom Portions', 'Instant Pricing'],
      'buttonText': "Explore Chef's Menu",
    },
  };

  @override
  void initState() {
    super.initState();
    _checkHealthPassAccess();
  }

  /// Authoritative Health Pass verification:
  /// Customers without an active Health Pass (or with an expired pass)
  /// are automatically redirected to browse the recipe menu.
  Future<void> _checkHealthPassAccess() async {
    setState(() => _isCheckingPass = true);
    try {
      final pass = await HealthPassRepository().fetchCurrentPass();
      final hasActivePass = pass != null && pass.isActive && !pass.isExpired;

      if (!mounted) return;

      if (!hasActivePass) {
        // Redirect to browse menu page (Catalogue)
        Navigator.pushReplacementNamed(context, AppRoutes.bookChefCatalogue);

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pass != null && pass.isExpired
                        ? 'Your Health Pass has expired. Renew your pass to book private chefs.'
                        : 'An active Health Pass is required to book in-home chefs.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
            dismissDirection: DismissDirection.horizontal,
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          messenger.hideCurrentSnackBar();
        });
        return;
      }

      setState(() {
        _activePass = pass;
        _isCheckingPass = false;
      });
    } catch (_) {
      // In case of transient network error, allow user to view with fallback
      if (mounted) {
        setState(() => _isCheckingPass = false);
      }
    }
  }

  void _showVideoPreviewModal(String videoUrl, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChefVideoModal(videoUrl: videoUrl, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPass) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Book a Home Chef',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate900),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.slate900,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Checking Health Pass membership...',
                style: TextStyle(color: AppColors.slate600, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final assigned = _screenConfig['assignedMeal'] as Map<String, dynamic>;
    final catalogue = _screenConfig['catalogueMeal'] as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Book a Home Chef',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate900),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.slate600, size: 22),
            onPressed: () => _showHowItWorksModal(),
            tooltip: 'How Chef Booking Works',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Health Pass Membership Entitlements Banner
              if (_activePass != null) ...[
                _buildActivePassEntitlementsCard(_activePass!),
                const SizedBox(height: 14),
              ],

              // Visual Hero Banner with Video Teaser Button
              _buildVisualHeroBanner(),
              const SizedBox(height: 20),

              // Section Header
              const Text(
                'How would you like to order?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick your clinical dietitian meal plan or choose custom recipes from our menu.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 16),

              // Option 1: Cook My Diet Plan (Assigned Meal)
              _buildImageOptionCard(
                context: context,
                onTap: () => Navigator.pushNamed(context, AppRoutes.bookChefAssigned),
                badgeLabel: assigned['badge'] ?? 'RECOMMENDED • CLINICALLY TAILORED',
                badgeColor: AppColors.emerald700,
                badgeBg: AppColors.emerald50,
                title: assigned['title'] ?? 'Cook My Diet Plan',
                subtitle: assigned['subtitle'] ?? 'Healthy meals tailored for your family',
                description: assigned['description'] ?? 'Enjoy balanced meals tailored to your health goals, calorie targets, and dietary preferences.',
                imageUrl: assigned['imageUrl'] ?? '',
                tags: (assigned['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                actionLabel: assigned['buttonText'] ?? 'Start Diet Plan Cooking',
                accentColor: AppColors.primary,
                fallbackIcon: Icons.restaurant_menu_rounded,
                isRecommended: true,
              ),

              const SizedBox(height: 18),

              // Option 2: Chef's Menu
              _buildImageOptionCard(
                context: context,
                onTap: () => Navigator.pushNamed(context, AppRoutes.bookChefCatalogue),
                badgeLabel: catalogue['badge'] ?? 'CUSTOM DISHES • ON-DEMAND',
                badgeColor: const Color(0xFFC2410C),
                badgeBg: const Color(0xFFFFF7ED),
                title: catalogue['title'] ?? "Chef's Menu",
                subtitle: catalogue['subtitle'] ?? 'Browse 50+ delicious, wholesome recipes',
                description: catalogue['description'] ?? 'Choose dishes with custom servings and instant live pricing.',
                imageUrl: catalogue['imageUrl'] ?? '',
                tags: (catalogue['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                actionLabel: catalogue['buttonText'] ?? "Explore Chef's Menu",
                accentColor: const Color(0xFFEA580C),
                fallbackIcon: Icons.menu_book_rounded,
                isRecommended: false,
              ),

              const SizedBox(height: 22),

              // How In-Home Chef Service Works (3 Visual Steps)
              _buildHowItWorksCard(),
              const SizedBox(height: 18),

              // Kitchen & Cookware Checklist
              _buildKitchenPreparationCard(),
              const SizedBox(height: 18),

              // The Home Chef Promise Section
              _buildChefPromiseCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Active Health Pass Entitlements Pill & Quota Status
  Widget _buildActivePassEntitlementsCard(ActiveHealthPassModel pass) {
    final remaining = pass.chefVisitsRemaining;
    final total = pass.chefVisitsAllocated > 0 ? pass.chefVisitsAllocated : (remaining + pass.chefVisitsUsed);
    final planName = pass.planName.isNotEmpty ? pass.planName : 'EBIC Health Pass';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 10,
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                      ),
                      const Text(
                        'Active Membership Entitlement',
                        style: TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.soup_kitchen_rounded, color: Color(0xFF15803D), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining of $total In-Home Chef Visits Available',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Chef cooking fee is covered by your subscription quota.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualHeroBanner() {
    final heroTitle = _screenConfig['heroTitle'] as String? ?? 'Certified Chef in Your Kitchen';
    final heroSub = _screenConfig['heroSubtitle'] as String? ?? 'Fresh meals cooked live using your own cookware.';
    final videoUrl = _screenConfig['videoTeaserUrl'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white.withOpacity(0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'EXECUTIVE CHEF DISPATCH',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (videoUrl.isNotEmpty)
                      InkWell(
                        onTap: () => _showVideoPreviewModal(videoUrl, 'Live Chef Cooking Experience'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Watch 15s Video',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  heroTitle,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  heroSub,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Text('⭐ 4.9 Rating', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    SizedBox(width: 12),
                    Text('•  100% Background Verified', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    SizedBox(width: 12),
                    Text('•  Clean-Up Included', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOptionCard({
    required BuildContext context,
    required VoidCallback onTap,
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeBg,
    required String title,
    required String subtitle,
    required String description,
    required String imageUrl,
    required List<String> tags,
    required String actionLabel,
    required Color accentColor,
    required IconData fallbackIcon,
    bool isRecommended = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRecommended ? AppColors.primary.withOpacity(0.5) : accentColor.withOpacity(0.3),
            width: isRecommended ? 1.8 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isRecommended ? AppColors.primary.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  color: accentColor.withOpacity(0.1),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildCardPlaceholder(accentColor, fallbackIcon),
                        )
                      : _buildCardPlaceholder(accentColor, fallbackIcon),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.35),
                  ),
                  const SizedBox(height: 10),

                  // Feature Pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.slate700, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              actionLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
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
    );
  }

  Widget _buildCardPlaceholder(Color accentColor, IconData icon) {
    return Container(
      color: accentColor.withOpacity(0.08),
      child: Center(
        child: Icon(icon, size: 48, color: accentColor.withOpacity(0.4)),
      ),
    );
  }

  /// 3-Step Visual Experience Stepper
  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'How In-Home Chef Service Works',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            stepNumber: '1',
            title: 'Select Meals & Time Slot',
            desc: 'Pick your dietitian-curated meal plan or choose custom dishes and schedule your preferred cooking time.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            stepNumber: '2',
            title: 'Chef Prepares Meals Live',
            desc: 'A verified executive chef arrives with aprons & tools, cooking hot food right in your kitchen.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            stepNumber: '3',
            title: 'Plated & Clean Kitchen Left Behind',
            desc: 'Food is plated and served, cookware washed, and countertops wiped spotless before departure.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({required String stepNumber, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            stepNumber,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.slate900),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate600, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kitchen Readiness & Cookware Checklist
  Widget _buildKitchenPreparationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.kitchen_rounded, color: AppColors.slate800, size: 18),
              SizedBox(width: 8),
              Text(
                'Kitchen & Cookware Readiness',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'All you need is a functional stovetop (gas or induction) and basic pots/pans. Chefs bring their specialty knives and hygiene tools.',
            style: TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildChecklistChip('Gas / Induction Cooktop'),
              const SizedBox(width: 6),
              _buildChecklistChip('Basic Utensils'),
              const SizedBox(width: 6),
              _buildChecklistChip('Clean Water'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate800),
          ),
        ],
      ),
    );
  }

  Widget _buildChefPromiseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Why EBIC Home Chef?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPromiseRow(
            Icons.pan_tool_alt_rounded,
            'Cooked in Your Kitchen',
            'Chefs use your own cookware and trusted ingredients for absolute hygiene.',
          ),
          const SizedBox(height: 10),
          _buildPromiseRow(
            Icons.cleaning_services_rounded,
            'Spotless Kitchen Clean-up',
            'Chefs sanitize countertops and wash used cooking utensils before leaving.',
          ),
          const SizedBox(height: 10),
          _buildPromiseRow(
            Icons.favorite_rounded,
            'Health-Conscious Cooking',
            'Less oil, balanced sodium, and customized taste according to your liking.',
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.slate900),
              ),
              const SizedBox(height: 1.5),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: AppColors.slate600, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHowItWorksModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Home Chef Service Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.slate900),
            ),
            const SizedBox(height: 12),
            const Text(
              'EBIC connects you with certified executive chefs who prepare nutritious, restaurant-caliber meals in your home cookware. Every dish strictly adheres to your clinical nutrition guidelines.',
              style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChefVideoModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _ChefVideoModal({required this.videoUrl, required this.title});

  @override
  State<_ChefVideoModal> createState() => _ChefVideoModalState();
}

class _ChefVideoModalState extends State<_ChefVideoModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized && _controller != null)
                    VideoPlayer(_controller!)
                  else if (_hasError)
                    Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_disabled_rounded, color: Colors.white54, size: 36),
                            SizedBox(height: 8),
                            Text('Video preview unavailable', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  if (_isInitialized && _controller != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Verified home chefs prepare healthy, appetizing dishes live right inside your kitchen.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
