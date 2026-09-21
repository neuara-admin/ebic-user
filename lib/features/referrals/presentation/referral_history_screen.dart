import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ebic_button.dart';
import '../data/referral_models.dart';
import '../data/referral_repository.dart';
import 'widgets/referral_detail_sheet.dart';

class ReferralHistoryScreen extends StatefulWidget {
  const ReferralHistoryScreen({super.key});

  @override
  State<ReferralHistoryScreen> createState() => _ReferralHistoryScreenState();
}

class _ReferralHistoryScreenState extends State<ReferralHistoryScreen> {
  final ReferralRepository _repo = ReferralRepository();
  bool _isLoading = true;
  String? _errorMessage;
  List<ReferralItemModel> _items = [];
  String _selectedFilter = 'ALL'; // ALL | PENDING | QUALIFIED | REWARDED

  final List<String> _filters = ['ALL', 'PENDING', 'QUALIFIED', 'REWARDED'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _repo.getHistory(
      status: _selectedFilter == 'ALL' ? null : _selectedFilter,
    );

    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _items = res.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.message ?? 'Failed to load referral history';
        _isLoading = false;
      });
    }
  }

  void _onFilterSelected(String filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Referral History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.slate900 : Colors.white,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      filter == 'ALL' ? 'All' : (filter[0] + filter.substring(1).toLowerCase()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? AppColors.slate300 : AppColors.slate700),
                      ),
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => _onFilterSelected(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Total count bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Referrals: ${_items.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),

          // Main list or states
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _items.isEmpty
                        ? _buildEmptyState(isDark)
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            color: AppColors.primary,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _buildReferralHistoryCard(item, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralHistoryCard(ReferralItemModel item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ReferralDetailSheet.show(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.friendName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(item.humanStatus, item.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Joined: ${item.joinedDateDisplay}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                  Text(
                    'Reward: ${item.humanRewardStatus}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: item.status == 'REWARDED'
                          ? AppColors.primary
                          : (item.status == 'QUALIFIED' ? AppColors.amber700 : AppColors.slate500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, String rawStatus) {
    Color bg;
    Color fg;

    switch (rawStatus.toUpperCase()) {
      case 'REWARDED':
        bg = AppColors.emerald50;
        fg = AppColors.emerald700;
        break;
      case 'QUALIFIED':
      case 'REWARD_PENDING':
        bg = AppColors.primarySubtle;
        fg = AppColors.primaryDark;
        break;
      case 'REGISTERED':
      case 'ATTRIBUTED':
      case 'ELIGIBLE':
        bg = AppColors.amber50;
        fg = AppColors.amber800;
        break;
      default:
        bg = AppColors.slate100;
        fg = AppColors.slate600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 52, color: isDark ? AppColors.slate600 : AppColors.slate300),
            const SizedBox(height: 14),
            Text(
              _selectedFilter == 'ALL'
                  ? 'No referrals yet'
                  : 'No ${_selectedFilter.toLowerCase()} referrals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.slate800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Invite your friends to EBIC and track their status and rewards here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.slate700),
            ),
            const SizedBox(height: 16),
            EbicButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _fetchHistory,
            ),
          ],
        ),
      ),
    );
  }
}
