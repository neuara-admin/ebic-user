import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../health_pass/data/health_pass_repository.dart';

/// Module 4 — Section 24–30: Book a Home Chef
/// Streamlined, high-converting chef booking selector screen.
/// Accessible to customers with an active EBIC Health Pass.
class BookingTypeScreen extends StatefulWidget {
  const BookingTypeScreen({super.key});

  @override
  State<BookingTypeScreen> createState() => _BookingTypeScreenState();
}

class _BookingTypeScreenState extends State<BookingTypeScreen> {
  bool _isCheckingPass = true;
  ActiveHealthPassModel? _activePass;

  /// Preview video configured in admin settings (Customer App); null hides it.
  String? get _videoTeaserUrl => RemoteConfigService().chefBookingVideoUrl;

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
          ),
        );
        return;
      }

      setState(() {
        _activePass = pass;
        _isCheckingPass = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingPass = false);
      }
    }
  }

  void _showVideoPreviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChefVideoModal(
        videoUrl: _videoTeaserUrl!,
        title: 'Live Chef Cooking Experience',
      ),
    );
  }

  void _showHowItWorksModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How EBIC Home Chef Works',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              const SizedBox(height: 14),
              _buildModalStep(
                number: '1',
                title: 'Select Meals & Time Slot',
                desc: 'Pick your dietitian-curated meal plan or choose custom dishes and schedule your preferred cooking time.',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildModalStep(
                number: '2',
                title: 'Chef Prepares Meals Live',
                desc: 'A verified executive chef arrives with aprons & tools, cooking hot food right in your kitchen using your cookware.',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildModalStep(
                number: '3',
                title: 'Plated & Clean Kitchen Left Behind',
                desc: 'Food is plated fresh, cooking utensils washed, and countertops wiped spotless before departure.',
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalStep({
    required String number,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            number,
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isCheckingPass) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Book a Home Chef', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          elevation: 0,
          backgroundColor: isDark ? AppColors.slate900 : Colors.white,
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Book a Home Chef', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            onPressed: _showHowItWorksModal,
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
              // 1. Compact Health Pass Quota Banner
              if (_activePass != null) ...[
                _buildCompactQuotaBanner(_activePass!, isDark),
                const SizedBox(height: 14),
              ],

              // 2. Crisp, Minimalist Header & Trust Badges
              _buildHeaderSection(isDark),
              const SizedBox(height: 18),

              // 3. Option 1: Cook My Diet Plan (Clinically Tailored)
              _buildBookingOptionCard(
                isDark: isDark,
                title: 'Cook My Diet Plan',
                badgeText: 'RECOMMENDED',
                badgeColor: AppColors.primary,
                badgeBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                icon: Icons.eco_rounded,
                accentColor: AppColors.primary,
                subtitle: 'Personalized to your doctor-prescribed meal chart and calorie goals.',
                features: const ['Doctor-Approved', 'Family Portioning', 'Clinical Profile'],
                buttonText: 'Cook Diet Plan Meals',
                isPrimary: true,
                onTap: () => Navigator.pushNamed(context, AppRoutes.bookChefAssigned),
              ),

              const SizedBox(height: 14),

              // 4. Option 2: Chef's A La Carte Menu
              _buildBookingOptionCard(
                isDark: isDark,
                title: "Chef's Recipe Menu",
                badgeText: 'ON-DEMAND',
                badgeColor: const Color(0xFFD97706),
                badgeBg: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                icon: Icons.menu_book_rounded,
                accentColor: const Color(0xFFD97706),
                subtitle: 'Handpick dishes across high-protein, keto, and family comfort favorites.',
                features: const ['50+ Healthy Dishes', 'Custom Portions', 'Instant Pricing'],
                buttonText: "Browse Chef's Menu",
                isPrimary: false,
                onTap: () => Navigator.pushNamed(context, AppRoutes.bookChefCatalogue),
              ),

              const SizedBox(height: 20),

              // 5. Streamlined "3-Step Experience" Card
              _buildCompactProcessCard(isDark),
              const SizedBox(height: 14),

              // 6. Minimal Kitchen Readiness Notice
              _buildKitchenReadinessTile(isDark),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 1. Compact Health Pass Quota ─────────────────────────

  Widget _buildCompactQuotaBanner(ActiveHealthPassModel pass, bool isDark) {
    final remaining = pass.chefVisitsRemaining;
    final total = pass.chefVisitsAllocated > 0 ? pass.chefVisitsAllocated : (remaining + pass.chefVisitsUsed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06281E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF047857).withOpacity(0.4) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$remaining of $total Chef Visits Available',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF166534),
                  ),
                ),
                Text(
                  'Chef service fee is 100% covered by your Health Pass quota.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.slate400 : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'INCLUDED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 9.5,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 2. Header & Trust Pills ─────────────────────────

  Widget _buildHeaderSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Certified Chef in Your Kitchen',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (_videoTeaserUrl != null) InkWell(
              onTap: _showVideoPreviewModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate300),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Watch 15s',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Hot, fresh meals cooked live using your own cookware & clean ingredients.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.slate400 : AppColors.slate600,
          ),
        ),
        const SizedBox(height: 10),
        // Wrap so the badges flow onto a second line on narrow phones
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildTrustBadge(Icons.star_rounded, const Color(0xFFF59E0B), '4.9 Rated', isDark),
            _buildTrustBadge(Icons.verified_user_rounded, AppColors.primary, 'Verified Chefs', isDark),
            _buildTrustBadge(Icons.cleaning_services_rounded, const Color(0xFF0D9488), 'Clean-Up Done', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, Color iconColor, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.slate700 : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 3 & 4. Primary Booking Cards ─────────────────────────

  Widget _buildBookingOptionCard({
    required bool isDark,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
    required List<String> features,
    required String buttonText,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? AppColors.primary.withOpacity(0.5)
                : (isDark ? AppColors.slate700 : AppColors.slate200),
            width: isPrimary ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.06)
                  : Colors.black.withOpacity(isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Badge + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? AppColors.slate600 : AppColors.slate400,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Subtitle Description
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Feature Chips
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: features.map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 11, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: isPrimary
                  ? ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                buttonText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        side: BorderSide(color: accentColor.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                buttonText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 5. Compact 3-Step Process ─────────────────────────

  Widget _buildCompactProcessCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THE LIVE COOKING JOURNEY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
              InkWell(
                onTap: _showHowItWorksModal,
                child: const Text(
                  'Details →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildProcessItem('1. Select', 'Meals & slot', Icons.tune_rounded, isDark)),
              Container(width: 1, height: 24, color: isDark ? AppColors.slate800 : AppColors.slate200),
              Expanded(child: _buildProcessItem('2. Cooks Live', 'Your utensils', Icons.outdoor_grill_rounded, isDark)),
              Container(width: 1, height: 24, color: isDark ? AppColors.slate800 : AppColors.slate200),
              Expanded(child: _buildProcessItem('3. Spotless', 'Cleaned up', Icons.auto_awesome_rounded, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessItem(String title, String sub, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 3),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 9.5,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 6. Kitchen Readiness Tile ─────────────────────────

  Widget _buildKitchenReadinessTile(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.kitchen_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kitchen Readiness: Standard stovetop (gas/induction) & basic cookware. Chefs bring specialty tools & sanitizers.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate300 : AppColors.slate600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Video Preview Modal ─────────────────────────

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
