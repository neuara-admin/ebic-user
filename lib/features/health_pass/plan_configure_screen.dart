import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/health_pass_model.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'data/health_pass_repository.dart';

/// Module 4 — Sections 36 & 37: Health Pass Duration & Member Selection
class HealthPassConfigureScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const HealthPassConfigureScreen({super.key, required this.arguments});

  @override
  State<HealthPassConfigureScreen> createState() => _HealthPassConfigureScreenState();
}

class _HealthPassConfigureScreenState extends State<HealthPassConfigureScreen> {
  final HealthPassRepository _repository = HealthPassRepository();
  final ApiClient _api = ApiClient();

  late String _planCode;
  HealthPassPlanModel? _plan;
  int _selectedDurationMonths = 1;
  final Set<String> _selectedMemberIds = {};

  List<HouseholdMemberModel> _householdMembers = [];
  HealthPassQuoteModel? _liveQuote;

  bool _isLoading = true;
  bool _isQuoting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _planCode = widget.arguments['planCode']?.toString() ?? 'CARE_V1';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _repository.fetchPlans();
      if (plans.isNotEmpty) {
        _plan = plans.cast<HealthPassPlanModel?>().firstWhere(
          (p) => p != null && p.code == _planCode,
          orElse: () => plans.first,
        );
        if (_plan != null && _plan!.durations.isNotEmpty) {
          _selectedDurationMonths = _plan!.durations.first.durationMonths;
        }
      }

      // Load household members
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        _householdMembers = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Default select the primary/self member
        if (_householdMembers.isNotEmpty) {
          _selectedMemberIds.add(_householdMembers.first.id);
        }
      }

      await _refreshQuote();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMembersOnly() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        setState(() {
          _householdMembers = res.data!
              .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
              .toList();

          if (_selectedMemberIds.isEmpty && _householdMembers.isNotEmpty) {
            _selectedMemberIds.add(_householdMembers.first.id);
          }
        });
        await _refreshQuote();
      }
    } catch (_) {}
  }

  Future<void> _navigateToAddMember() async {
    final added = await Navigator.pushNamed(context, AppRoutes.memberForm);
    if (added == true && mounted) {
      await _loadMembersOnly();
    }
  }

  Future<void> _deleteMember(HouseholdMemberModel member) async {
    if (member.isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account owner profile cannot be removed.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Member?'),
        content: Text('Are you sure you want to remove ${member.name} from your household?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _api.delete<Map<String, dynamic>>(
        ApiEndpoints.householdMemberDetail(member.id),
      );

      if (res.success) {
        setState(() {
          _selectedMemberIds.remove(member.id);
        });
        await MemberContext().loadMembers(forceRefresh: true);
        await _loadMembersOnly();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.name} removed from household.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'Failed to delete member.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting member: $e')),
        );
      }
    }
  }

  Future<void> _refreshQuote() async {
    if (_selectedMemberIds.isEmpty || _plan == null) return;
    setState(() => _isQuoting = true);
    try {
      final quote = await _repository.getQuote(
        planCode: _plan!.code,
        durationMonths: _selectedDurationMonths,
        memberIds: _selectedMemberIds.toList(),
      );
      if (mounted) {
        setState(() {
          _liveQuote = quote;
          _isQuoting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isQuoting = false);
    }
  }

  void _onDurationSelected(int months) {
    setState(() => _selectedDurationMonths = months);
    AnalyticsService().logHealthPassDurationSelected(months);
    _refreshQuote();
  }

  void _toggleMember(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        if (_selectedMemberIds.length > 1) {
          _selectedMemberIds.remove(memberId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('At least one household member must be covered.')),
          );
          return;
        }
      } else {
        if (_plan != null && _selectedMemberIds.length >= _plan!.maxMembers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_plan!.name} supports a maximum of ${_plan!.maxMembers} members.')),
          );
          return;
        }
        _selectedMemberIds.add(memberId);
      }
    });
    AnalyticsService().logHealthPassMembersSelected(_selectedMemberIds.length);
    _refreshQuote();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_plan != null ? 'Customize ${_plan!.name}' : 'Customize Health Pass'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_plan?.imageUrl != null || (_plan?.images.isNotEmpty ?? false)) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        _plan!.imageUrl ?? _plan!.images.first.url,
                                        height: 125,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 12,
                                        bottom: 10,
                                        right: 12,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _plan!.displayName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                backgroundColor: Colors.white.withOpacity(0.25),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.info_outline, color: Colors.white, size: 13),
                                              label: const Text(
                                                'View Benefits',
                                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.healthPassBenefits,
                                                  arguments: {
                                                    'planCode': _plan!.code,
                                                    'planName': _plan!.displayName,
                                                    'plan': _plan,
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Section 36: Duration Selection
                              const Text(
                                'CHOOSE DURATION',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildDurationGrid(isDark),
                              const SizedBox(height: 24),

                              // Section 37: Member Selection
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'COVERED FAMILY MEMBERS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.slate500,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedMemberIds.length} of ${_plan?.maxMembers ?? 5} members selected',
                                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _navigateToAddMember,
                                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppColors.primary),
                                    label: const Text(
                                      'Add Member',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      backgroundColor: isDark ? AppColors.slate800 : AppColors.primarySubtle,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You are covered as the primary member. Additional family members can be added at special family rates.',
                                style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.slate400 : AppColors.slate600, height: 1.3),
                              ),
                              const SizedBox(height: 12),
                              _buildMembersList(isDark),
                              const SizedBox(height: 24),

                              // Live Pricing Preview Card
                              _buildPricingPreviewCard(isDark),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomBar(isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDurationGrid(bool isDark) {
    if (_plan == null || _plan!.durations.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: _plan!.durations.length,
      itemBuilder: (context, index) {
        final d = _plan!.durations[index];
        final isSelected = d.durationMonths == _selectedDurationMonths;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onDurationSelected(d.durationMonths),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.emerald700.withOpacity(0.2) : AppColors.emerald50)
                  : (isDark ? AppColors.slate900 : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      d.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? AppColors.primary : (isDark ? Colors.white : AppColors.slate900),
                      ),
                    ),
                    if (d.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Save ${d.discountPercent.toInt()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.durationMonths} ${d.durationMonths == 1 ? 'month' : 'months'} validity',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersList(bool isDark) {
    if (_householdMembers.isEmpty) {
      return EbicCard(
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.people_outline, color: AppColors.slate400, size: 28),
              const SizedBox(height: 8),
              const Text('No household members found.', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
              const SizedBox(height: 10),
              EbicButton(
                label: 'Add Family Member',
                isOutlined: true,
                onPressed: _navigateToAddMember,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _householdMembers.map((member) {
        final isSelected = _selectedMemberIds.contains(member.id);
        final resolvedAvatar = AppConfig.resolveMediaUrl(member.avatarUrl);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : (isSelected ? const Color(0xFFF0FDF4) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.slate800 : AppColors.slate200),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleMember(member.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.slate200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: resolvedAvatar != null && resolvedAvatar.isNotEmpty
                        ? Image.network(
                            resolvedAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                member.initials,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.slate700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              member.initials,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.slate700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: member.isSelf ? AppColors.emerald50 : AppColors.slate100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                member.isSelf ? 'SELF' : member.relationship.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: member.isSelf ? AppColors.primaryDark : AppColors.slate600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.gender} • ${member.age > 0 ? '${member.age} yrs' : 'Age not specified'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.slate500, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (!member.isSelf)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
                      tooltip: 'Remove from household',
                      onPressed: () => _deleteMember(member),
                    ),
                  Checkbox(
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    value: isSelected,
                    onChanged: (_) => _toggleMember(member.id),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricingPreviewCard(bool isDark) {
    if (_liveQuote == null) {
      return const SizedBox.shrink();
    }

    final q = _liveQuote!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800.withOpacity(0.5) : AppColors.slate50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Price Breakdown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ),
                      if (_isQuoting) ...[
                        const SizedBox(width: 6),
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ESTIMATE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _priceRow('Plan Subscription (${q.durationMonths} ${q.durationMonths == 1 ? 'Month' : 'Months'})', '₹${q.subtotal.toInt()}', isDark),
                if (q.memberCharges > 0)
                  _priceRow('Additional Family Members (${q.memberCount - 1})', '+₹${q.memberCharges.toInt()}', isDark),
                if (q.memberDiscount > 0)
                  _priceRow('Family Savings', '-₹${q.memberDiscount.toInt()}', isDark, color: AppColors.emerald700),
                if (q.durationDiscount > 0)
                  _priceRow('Multi-Month Savings', '-₹${q.durationDiscount.toInt()}', isDark, color: AppColors.emerald700),
                if (q.platformFee > 0)
                  _priceRow('Platform & Service Fee', '+₹${q.platformFee.toInt()}', isDark),
                if (q.otherCharges > 0)
                  _priceRow('Other Charges', '+₹${q.otherCharges.toInt()}', isDark),
                if (q.tax > 0)
                  _priceRow(
                    q.gstPercent > 0 ? 'Taxes & GST (${q.gstPercent.toInt()}%)' : 'Taxes & GST',
                    '+₹${q.tax.toInt()}',
                    isDark,
                  ),
              ],
            ),
          ),

          // Dashed separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                26,
                (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 1.5,
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                  ),
                ),
              ),
            ),
          ),

          // Total box
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Payable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Includes all taxes & GST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${q.finalAmount.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.slate600)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? (isDark ? Colors.white : AppColors.slate800))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                Text(
                  _liveQuote != null ? '₹${_liveQuote!.finalAmount.toInt()}' : '—',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: EbicButton(
              label: 'Continue to Review',
              onPressed: _liveQuote == null || _isQuoting
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.healthPassReview,
                        arguments: {
                          'plan': _plan,
                          'durationMonths': _selectedDurationMonths,
                          'memberIds': _selectedMemberIds.toList(),
                          'members': _householdMembers.where((m) => _selectedMemberIds.contains(m.id)).toList(),
                          'quote': _liveQuote,
                        },
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}
