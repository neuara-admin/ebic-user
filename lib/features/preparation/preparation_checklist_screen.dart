import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/preparation_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

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

    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.chefBookingPreparation(widget.orderId),
      );

      if (res.success && res.data != null) {
        setState(() {
          _checklist = OrderPreparationChecklistModel.fromJson(res.data!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message ?? 'Unable to load preparation checklist';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
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
    } catch (e) {
      // Revert on failure
      setState(() {
        item.status = item.isReady ? 'PENDING' : 'READY';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update ingredient status: $e')),
      );
    }
  }

  Future<void> _markAllReady() async {
    setState(() => _isUpdatingAll = true);
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.chefBookingMarkAllReady(widget.orderId),
        body: {},
      );

      if (res.success && res.data != null) {
        setState(() {
          _checklist = OrderPreparationChecklistModel.fromJson(res.data!);
          _isUpdatingAll = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All ingredients marked as READY! Chef notified.'),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        }
      } else {
        setState(() => _isUpdatingAll = false);
      }
    } catch (e) {
      setState(() => _isUpdatingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _checklist?.items ?? [];
    final readyCount = items.where((i) => i.isReady).length;
    final totalCount = items.length;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Prepare for Your Chef'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChecklist,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      EbicButton(label: 'Retry', onPressed: _fetchChecklist),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Section 40 Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        color: AppColors.primarySubtle,
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: AppColors.primaryDark, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Please keep required kitchen ingredients ready before your chef arrives.',
                                style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress counter & Mark All Ready
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$readyCount of $totalCount ready',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  totalCount > 0 && readyCount == totalCount
                                      ? '🎉 Kitchen is 100% prepared!'
                                      : 'Tap checkbox once item is washed/placed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: totalCount > 0 && readyCount == totalCount ? AppColors.primary : AppColors.slate500,
                                    fontWeight: totalCount > 0 && readyCount == totalCount ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            EbicButton(
                              label: 'Mark All Ready',
                              variant: EbicButtonVariant.outline,
                              isLoading: _isUpdatingAll,
                              onPressed: readyCount == totalCount ? null : _markAllReady,
                            ),
                          ],
                        ),
                      ),

                      // Ingredients List (Section 38 & 39)
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final item = items[idx];
                            return _buildIngredientCard(item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildIngredientCard(PreparationItemModel item) {
    Color cardBg = Colors.white;
    if (item.isReady) cardBg = AppColors.emerald50.withOpacity(0.4);
    if (item.isUnavailable || item.isRemoved) cardBg = AppColors.slate100;

    return EbicCard(
      backgroundColor: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isReady,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: item.isRemoved
                    ? null
                    : (_) => _toggleItemStatus(item),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: item.isRemoved ? TextDecoration.lineThrough : null,
                            color: item.isRemoved ? AppColors.slate400 : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '— ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.customerProvides ? 'Customer Provides' : 'EBIC Provides',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                        ),
                        if (item.optional) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.slate400)),
                          const Text('Optional', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                        ],
                        if (item.status != 'PENDING' && item.status != 'READY') ...[
                          const Text(' • ', style: TextStyle(color: AppColors.slate400)),
                          Text(
                            item.status.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!item.isReady && !item.isRemoved)
                TextButton(
                  onPressed: () => _showUnavailableOptions(item),
                  child: const Text(
                    "Don't Have",
                    style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (item.preparationInstructions != null && item.preparationInstructions!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Note: ${item.preparationInstructions}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
