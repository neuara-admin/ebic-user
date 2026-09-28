import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/preparation_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_view.dart';

class PreparationChecklistScreen extends StatefulWidget {
  final String orderId;

  const PreparationChecklistScreen({super.key, required this.orderId});

  @override
  State<PreparationChecklistScreen> createState() => _PreparationChecklistScreenState();
}

class _PreparationChecklistScreenState extends State<PreparationChecklistScreen> {
  final ApiClient _api = ApiClient();
  OrderPreparationChecklistModel? _checklist;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUpdatingAll = false;
  String _activeFilter = 'ALL'; // ALL, READY, PENDING

  @override
  void initState() {
    super.initState();
    _fetchChecklist();
  }

  Future<void> _fetchChecklist() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.orderId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'This booking has no preparation checklist.';
      });
      return;
    }

    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.chefBookingPreparation(widget.orderId),
      );
      if (!mounted) return;
      setState(() {
        if (res.success && res.data != null) {
          _checklist = OrderPreparationChecklistModel.fromJson(res.data!);
        } else {
          _errorMessage = res.error?.message ??
              res.message ??
              'Unable to load the preparation checklist.';
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load the preparation checklist.';
      });
    }
  }

  Future<void> _toggleItemStatus(PreparationItemModel item) async {
    final nextStatus = item.isReady ? 'PENDING' : 'READY';

    // Optimistic UI update
    setState(() {
      item.status = nextStatus;
    });

    try {
      await _api.patch<Map<String, dynamic>>(
        ApiEndpoints.chefBookingPreparation(widget.orderId),
        body: {
          'ingredientId': item.ingredientId.isNotEmpty ? item.ingredientId : item.id,
          'status': nextStatus,
        },
      );
    } catch (_) {
      // Keep optimistic state for smooth offline-resilient UI
    }
  }

  Future<void> _markAllReady() async {
    final items = _checklist?.items ?? [];
    if (items.isEmpty) return;

    setState(() {
      _isUpdatingAll = true;
      for (var item in items) {
        item.status = 'READY';
      }
    });

    try {
      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.chefBookingMarkAllReady(widget.orderId),
        body: {},
      );
    } catch (_) {}

    setState(() => _isUpdatingAll = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All ingredients marked as READY! Chef notified.'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  void _showUnavailableOptions(PreparationItemModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Missing Ingredient: ${item.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'If you do not have this ingredient at home, choose an option below:',
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.sync_alt_rounded, color: AppColors.primary),
                title: const Text('Request Approved Alternative'),
                subtitle: const Text('Chef will use a safe culinary substitute'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _updateStatus(item, 'SUBSTITUTION_REQUESTED');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove from Dish'),
                subtitle: const Text('Dish will be cooked without this ingredient'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _updateStatus(item, 'REMOVED');
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded, color: AppColors.slate700),
                title: const Text('Contact Support'),
                subtitle: const Text('Connect with executive operations support'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/support');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(PreparationItemModel item, String status) async {
    setState(() => item.status = status);
    try {
      await _api.patch<Map<String, dynamic>>(
        ApiEndpoints.chefBookingPreparation(widget.orderId),
        body: {
          'ingredientId': item.ingredientId.isNotEmpty ? item.ingredientId : item.id,
          'status': status,
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = _checklist?.items ?? [];
    final readyCount = allItems.where((i) => i.isReady).length;
    final totalCount = allItems.length;
    final progress = totalCount > 0 ? readyCount / totalCount : 0.0;

    final displayedItems = allItems.where((item) {
      if (_activeFilter == 'READY') return item.isReady;
      if (_activeFilter == 'PENDING') return !item.isReady;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ingredient Checklist'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Checklist',
            onPressed: _fetchChecklist,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? ErrorView(message: _errorMessage!, onRetry: _fetchChecklist)
          : allItems.isEmpty
          ? const EmptyStateView(
              icon: Icons.checklist_rounded,
              title: 'Checklist not ready yet',
              message: 'Your preparation checklist appears here once the kitchen confirms the ingredients for your booking.',
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Progress Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(
                              '$readyCount of $totalCount Ingredients Ready',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}% READY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                totalCount > 0 && readyCount == totalCount
                                    ? '🎉 Kitchen is 100% prepared for your chef!'
                                    : 'Keep items ready on your kitchen counter',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: readyCount == totalCount || _isUpdatingAll ? null : _markAllReady,
                              child: _isUpdatingAll
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : const Text('Mark All Ready', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Filter Tabs
                  Row(
                    children: [
                      _buildFilterChip('ALL', 'All ($totalCount)', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('READY', 'Ready ($readyCount)', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('PENDING', 'Pending (${totalCount - readyCount})', isDark),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Ingredients Items
                  if (displayedItems.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No ingredients under this filter.',
                          style: TextStyle(color: isDark ? Colors.white54 : AppColors.slate400),
                        ),
                      ),
                    ),
                  ] else ...[
                    ...displayedItems.map((item) => _buildIngredientCard(item, isDark)),
                  ],
                  const SizedBox(height: 16),

                  // 4. Kitchen Preparation Advice Card
                  EbicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cookware & Kitchen Checklist',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildChecklistBullet('Clean cooking counter and clear sink area for chef', isDark),
                        _buildChecklistBullet('Kadhai / Frying pan & pressure cooker accessible', isDark),
                        _buildChecklistBullet('Cooking gas cylinder / induction stove active', isDark),
                        _buildChecklistBullet('Drinking water and salt/pepper available', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.slate800 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.slate700),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistBullet(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white70 : AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(PreparationItemModel item, bool isDark) {
    Color cardBg = isDark ? AppColors.slate900 : Colors.white;
    if (item.isReady) {
      cardBg = isDark ? const Color(0xFF064E3B).withOpacity(0.2) : const Color(0xFFECFDF5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isReady
              ? const Color(0xFF10B981).withOpacity(0.5)
              : (isDark ? AppColors.slate800 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: item.isReady,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: item.isRemoved ? null : (_) => _toggleItemStatus(item),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          decoration: item.isRemoved ? TextDecoration.lineThrough : null,
                          color: item.isRemoved
                              ? AppColors.slate400
                              : (isDark ? Colors.white : AppColors.slate900),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.customerProvides ? 'Kitchen Pantry' : 'EBIC Provided',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppColors.slate600,
                        ),
                      ),
                    ),
                    if (item.preparationInstructions != null && item.preparationInstructions!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.preparationInstructions!,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.slate500, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!item.isReady && !item.isRemoved)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(50, 30),
              ),
              onPressed: () => _showUnavailableOptions(item),
              child: const Text(
                'Missing?',
                style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
