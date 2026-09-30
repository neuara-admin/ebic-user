import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dietitian_model.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../health_pass/data/health_pass_repository.dart';
import 'dietitian_chat_screen.dart';

class DietitianProfileScreen extends StatefulWidget {
  final DietitianModel dietitian;
  final ActiveHealthPassModel? initialPass;

  const DietitianProfileScreen({
    super.key,
    required this.dietitian,
    this.initialPass,
  });

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
    _activePass = widget.initialPass;
    _isLoadingPass = widget.initialPass == null;
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

  /// Chat and direct calls are strictly available only for active Health Pass users
  /// between pass startDate and endDate.
  bool get _hasActiveSubscription {
    final pass = _activePass;
    if (pass == null) return false;
    if (pass.status.toUpperCase() != 'ACTIVE' || pass.isExpired) return false;
    final now = DateTime.now();
    if (pass.startDate != null) {
      final start = DateTime(
          pass.startDate!.year, pass.startDate!.month, pass.startDate!.day);
      if (now.isBefore(start)) return false;
    }
    if (pass.endDate != null) {
      final end = DateTime(pass.endDate!.year, pass.endDate!.month,
          pass.endDate!.day, 23, 59, 59);
      if (now.isAfter(end)) return false;
    }
    return true;
  }

  String _formatPassDates() {
    final pass = _activePass;
    if (pass == null) return 'No Active Pass';
    final df = DateFormat('dd MMM yyyy');
    final s = pass.startDate != null ? df.format(pass.startDate!) : 'Start';
    final e = pass.endDate != null ? df.format(pass.endDate!) : 'End';
    return '$s – $e';
  }

  String? get _passValidityNotice {
    final pass = _activePass;
    final df = DateFormat('dd MMM yyyy');
    if (pass == null) {
      return 'An active Health Pass is required to chat, call, or contact your dietitian.';
    }
    final now = DateTime.now();
    if (pass.startDate != null) {
      final start = DateTime(
          pass.startDate!.year, pass.startDate!.month, pass.startDate!.day);
      if (now.isBefore(start)) {
        return 'Your Health Pass starts on ${df.format(pass.startDate!)}. Chat and direct calling access will activate on the start date.';
      }
    }
    if (pass.endDate != null) {
      final end = DateTime(pass.endDate!.year, pass.endDate!.month,
          pass.endDate!.day, 23, 59, 59);
      if (now.isAfter(end) || pass.isExpired) {
        return 'Your Health Pass expired on ${df.format(pass.endDate!)}. Please renew your pass to resume live chat and calling.';
      }
    }
    if (pass.status.toUpperCase() != 'ACTIVE') {
      return 'Your Health Pass status is currently ${pass.status}. An active pass is required to access chat and calling.';
    }
    return null;
  }

  void _openChatScreen() {
    if (!_hasActiveSubscription) {
      _showAccessLockedDialog(
        title: 'Health Pass Required for Chat',
        message: _passValidityNotice ??
            'Direct live chat with your clinical dietitian is exclusively available for active Health Pass members during pass validity.',
      );
      return;
    }
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

  void _handleCallAccess() {
    if (!_hasActiveSubscription) {
      _showAccessLockedDialog(
        title: 'Health Pass Required for Calls',
        message: _passValidityNotice ??
            'Direct calling and video sessions with your clinical dietitian are available during your Health Pass validity dates.',
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.consultationBook,
      arguments: {'dietitian': widget.dietitian},
    );
  }

  void _showAccessLockedDialog(
      {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.slate700),
            ),
            if (_activePass?.startDate != null ||
                _activePass?.endDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pass Dates: ${_formatPassDates()}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.healthPass);
            },
            child: Text(
              _activePass?.isExpired == true
                  ? 'Renew Pass'
                  : 'Get / View Health Pass',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.dietitian.name.startsWith('Dr')
                    ? widget.dietitian.name
                    : 'Dr. ${widget.dietitian.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ],
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
          if (widget.dietitian.qualification != null && widget.dietitian.qualification!.trim().isNotEmpty) ...[
            Text(
              widget.dietitian.qualification!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Quick Hero CTAs (Chat & Book Call - Gated by Health Pass validity)
          const SizedBox(height: 6),
          if (_isLoadingPass) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ] else if (_hasActiveSubscription) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openChatScreen,
                  icon: const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white),
                  label: const Text('Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _handleCallAccess,
                  icon: const Icon(Icons.video_call_rounded, size: 16, color: Color(0xFF4F46E5)),
                  label: const Text(
                    'Book Video Call',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 12, color: AppColors.primaryDark),
                  const SizedBox(width: 4),
                  Text(
                    'Access Active: ${_formatPassDates()}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFFB45309)),
                      SizedBox(width: 6),
                      Text(
                        'Chat & Calls: Active Pass Required',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _passValidityNotice ?? 'Access is available during Health Pass validity dates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.slate300 : const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _openChatScreen,
                  icon: const Icon(Icons.lock_rounded, size: 13, color: AppColors.slate500),
                  label: const Text('Live Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate600,
                    side: const BorderSide(color: AppColors.slate300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.healthPass),
                  icon: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                  label: const Text('Get Health Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final ratingVal = (widget.dietitian.rating != null && widget.dietitian.rating! > 0)
        ? '${widget.dietitian.rating!.toStringAsFixed(1)} ★'
        : '4.9 ★';
    final expYears = widget.dietitian.experienceYears;
    final expVal = (expYears != null && expYears > 0) ? '$expYears Yrs' : '5+ Yrs';

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
          _buildStatItem('Rating', ratingVal, AppColors.accent, isDark),
          _buildStatDivider(isDark),
          _buildStatItem('Experience', expVal, AppColors.primary, isDark),
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
        children: _buildCredentialRows(isDark),
      ),
    );
  }

  // Only shows rows for fields the dietitian's real profile actually has —
  // never a plausible-sounding invented default.
  List<Widget> _buildCredentialRows(bool isDark) {
    final rows = <MapEntry<String, String>>[
      if (widget.dietitian.qualification != null &&
          widget.dietitian.qualification!.trim().isNotEmpty)
        MapEntry('Qualification', widget.dietitian.qualification!),
      MapEntry('Experience',
          '${widget.dietitian.experienceYears} Years in Clinical Practice'),
      if (widget.dietitian.languages != null &&
          widget.dietitian.languages!.trim().isNotEmpty)
        MapEntry('Languages', widget.dietitian.languages!),
      const MapEntry(
          'Consultation Mode', 'HD Video Session (45 min) + Diet Chart'),
      if (_hasActiveSubscription)
        MapEntry(
          'Direct Chat & Call',
          '✓ Active (${_formatPassDates()})',
        )
      else
        const MapEntry(
          'Direct Chat & Call',
          '🔒 Locked (Active Pass Required)',
        ),
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      widgets.add(_buildSafeDetailRow(rows[i].key, rows[i].value, isDark));
      if (i != rows.length - 1) widgets.add(_buildDetailDivider(isDark));
    }
    return widgets;
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
    final dateFormat = DateFormat('dd MMM yyyy');
    final isActive = _hasActiveSubscription;
    final pass = _activePass;

    if (_isLoadingPass) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate800 : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Validity Indicator Banner
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFECFDF5)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  size: 14,
                  color: isActive ? AppColors.primaryDark : const Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isActive && pass != null
                        ? 'Health Pass Active (${pass.startDate != null ? dateFormat.format(pass.startDate!) : "Start"} – ${pass.endDate != null ? dateFormat.format(pass.endDate!) : "End"})'
                        : (_passValidityNotice ?? 'Active Health Pass required for direct chat & call access.'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primaryDark : const Color(0xFF92400E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              // Instant Chat Button (Gated)
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: _openChatScreen,
                  icon: Icon(
                    isActive ? Icons.chat_bubble_outline_rounded : Icons.lock_outline_rounded,
                    size: 16,
                    color: isActive ? AppColors.primary : AppColors.slate400,
                  ),
                  label: Text(
                    isActive ? 'Live Chat' : 'Chat (Locked)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.primary : AppColors.slate500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isActive ? AppColors.primary : AppColors.slate300,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Book Video Call / Call Access
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: _handleCallAccess,
                  icon: Icon(
                    isActive ? Icons.video_call_rounded : Icons.lock_outline_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: Text(
                    isActive ? 'Video Call' : 'Call (Locked)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? const Color(0xFF4F46E5) : AppColors.slate600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
