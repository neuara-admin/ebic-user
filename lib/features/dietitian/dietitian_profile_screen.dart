import 'package:flutter/material.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../health_pass/data/health_pass_repository.dart';
import 'dietitian_chat_screen.dart';

class DietitianProfileScreen extends StatefulWidget {
  final DietitianModel dietitian;

  const DietitianProfileScreen({super.key, required this.dietitian});

  @override
  State<DietitianProfileScreen> createState() => _DietitianProfileScreenState();
}

class _DietitianProfileScreenState extends State<DietitianProfileScreen> {
  final HealthPassRepository _healthPassRepo = HealthPassRepository();

  ActiveHealthPassModel? _activePass;
  bool _isLoadingPass = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final pass = await _healthPassRepo.fetchCurrentPass();
      if (mounted) {
        setState(() {
          _activePass = pass;
          _isLoadingPass = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPass = false;
        });
      }
    }
  }

  bool get _hasActiveSubscription {
    final pass = _activePass;
    if (pass == null) return false;
    return pass.status.toUpperCase() == 'ACTIVE' && !pass.isExpired;
  }

  void _openChatScreen() {
    if (!_hasActiveSubscription) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DietitianChatScreen(
          dietitian: widget.dietitian,
          activePass: _activePass,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final specList = (widget.dietitian.specialization ??
            'Clinical Nutrition, Metabolic Health, Weight Management')
        .split(RegExp(r'[,•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        title: const Text(
          'Dietitian Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Profile',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Profile Card
                    _buildHeroDoctorCard(isDark),
                    const SizedBox(height: 16),

                    // Quick Stats Row (Rating, Experience, Patients, Verification)
                    _buildStatsRow(isDark),
                    const SizedBox(height: 20),

                    // Specializations & Focus Areas
                    _buildSectionHeader('Clinical Focus & Specialties', Icons.verified_user_outlined),
                    const SizedBox(height: 10),
                    _buildSpecializations(specList, isDark),
                    const SizedBox(height: 20),

                    // About Doctor / Bio
                    _buildSectionHeader('About Dietitian', Icons.info_outline_rounded),
                    const SizedBox(height: 10),
                    _buildAboutCard(isDark),
                    const SizedBox(height: 20),

                    // Professional Credentials & Logistics
                    _buildSectionHeader('Professional Credentials', Icons.badge_outlined),
                    const SizedBox(height: 10),
                    _buildCredentialsCard(isDark),
                    const SizedBox(height: 20),

                    // What's Included in Consultation
                    _buildSectionHeader('Consultation Inclusions', Icons.assignment_turned_in_outlined),
                    const SizedBox(height: 10),
                    _buildInclusionsCard(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Action Bar (Chat button only visible with active subscription)
            _buildBottomActionBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDoctorCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primarySubtle,
                      AppColors.emerald400.withOpacity(0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Center(
                  child: Text(
                    widget.dietitian.name.isNotEmpty
                        ? widget.dietitian.name
                            .replaceAll('Dr. ', '')
                            .split(' ')
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .take(2)
                            .join()
                        : 'RD',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.slate900 : Colors.white,
                      width: 2.5,
                    ),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            widget.dietitian.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          const SizedBox(height: 4),

          // Qualification
          Text(
            widget.dietitian.qualification ?? 'Senior Clinical Dietitian & Registered Dietitian (RD)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate400 : AppColors.slate600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Hub Tag
          if (widget.dietitian.hubName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.dietitian.hubName!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Rating', '${widget.dietitian.rating} ★', AppColors.accent, isDark),
          _buildStatDivider(isDark),
          _buildStatItem('Experience', '${widget.dietitian.experienceYears} Yrs', AppColors.primary, isDark),
          _buildStatDivider(isDark),
          _buildStatItem('Sessions', '250+', AppColors.secondary, isDark),
          _buildStatDivider(isDark),
          _buildStatItem('Status', 'Active', AppColors.success, isDark),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 28,
      width: 1,
      color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
    );
  }



  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecializations(List<String> specs, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: specs.map((spec) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.emerald700.withOpacity(0.4) : AppColors.emerald400.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutCard(bool isDark) {
    final bioText = (widget.dietitian.bio != null && widget.dietitian.bio!.isNotEmpty)
        ? widget.dietitian.bio!
        : '${widget.dietitian.name} is a board-certified clinical dietitian specializing in clinical nutrition therapy, endocrine health, and personalized metabolic meal planning. '
            'She works closely with home chefs to ensure that tailored dietary guidelines are converted into delicious, healthy daily meals.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bioText,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Sync: Prescriptions are automatically connected to your EBIC home chef.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.slate300 : AppColors.slate800,
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

  Widget _buildCredentialsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSafeDetailRow('Qualification', widget.dietitian.qualification ?? 'M.Sc Clinical Nutrition, RD', isDark),
          _buildDetailDivider(isDark),
          _buildSafeDetailRow('Experience', '${widget.dietitian.experienceYears} Years in Clinical Practice', isDark),
          _buildDetailDivider(isDark),
          _buildSafeDetailRow('Languages', widget.dietitian.languages ?? 'English, Hindi', isDark),
          _buildDetailDivider(isDark),
          _buildSafeDetailRow('Care Hub', widget.dietitian.hubName ?? 'Hyderabad Central Care Hub', isDark),
          _buildDetailDivider(isDark),
          _buildSafeDetailRow('Consultation Mode', 'HD Video Session (45 min) + Diet Chart', isDark),
        ],
      ),
    );
  }

  Widget _buildSafeDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider(bool isDark) {
    return Divider(
      height: 16,
      color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildInclusionsCard(bool isDark) {
    final inclusions = [
      {'icon': Icons.videocam_outlined, 'title': '1-on-1 Video Session (30-45 mins)', 'desc': 'Full lifestyle, biometric, and dietary history assessment.'},
      {'icon': Icons.pie_chart_outline_rounded, 'title': 'Custom Clinical Diet Chart', 'desc': 'Macro & micronutrient targets designed for your health goals.'},
      {'icon': Icons.sync_rounded, 'title': 'Automatic Home Chef Alignment', 'desc': 'Recipes & ingredient guidelines automatically shared with your cook.'},
      {'icon': Icons.chat_bubble_outline_rounded, 'title': '7-Day In-App Chat Support', 'desc': 'Ask follow-up questions and request recipe adjustments.'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: inclusions.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == inclusions.length - 1;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Divider(
                  height: 20,
                  color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Fixed Bottom Action Bar:
  /// - If user HAS an active Health Pass subscription: shows "Chat" (encrypted) and "Book Session" buttons.
  /// - If user DOES NOT have a subscription: shows ONLY "Book Consultation" (NO chat button).
  Widget _buildBottomActionBar(BuildContext context, bool isDark) {
    final rawName = widget.dietitian.name.trim();
    final nameWithoutDr = rawName.replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '');
    final drDisplayName = 'Dr. ${nameWithoutDr.split(' ').first}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: _hasActiveSubscription
          ? Row(
              children: [
                // Chat Button (Active Health Pass Exclusive)
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: _openChatScreen,
                    icon: const Icon(Icons.lock_rounded, size: 13, color: AppColors.primary),
                    label: const Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Book Consultation Button
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationBook,
                        arguments: {'dietitian': widget.dietitian},
                      );
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 15, color: Colors.white),
                    label: Text(
                      'Book with $drDisplayName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STANDARD SESSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1-on-1 Video Call',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      Text(
                        'Diet chart & kitchen sync',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: EbicButton(
                    label: 'Book with $drDisplayName',
                    icon: Icons.calendar_month_rounded,
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.consultationBook,
                        arguments: {'dietitian': widget.dietitian},
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
