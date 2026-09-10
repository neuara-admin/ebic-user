import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dish_model.dart';
import '../../shared/widgets/ebic_button.dart';

class AddItemsSheet extends StatefulWidget {
  final String orderId;
  final VoidCallback onItemsAdded;

  const AddItemsSheet({
    super.key,
    required this.orderId,
    required this.onItemsAdded,
  });

  @override
  State<AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends State<AddItemsSheet> {
  final ApiClient _api = ApiClient();
  List<DishModel> _availableDishes = [];
  final Map<String, int> _selectedQuantities = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchQuickAddons();
  }

  Future<void> _fetchQuickAddons() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.catalogueDishes);
      if (res.success && res.data != null) {
        setState(() {
          _availableDishes = res.data!
              .map((json) => DishModel.fromJson(json as Map<String, dynamic>))
              .take(6)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _submitAddons() async {
    if (_selectedQuantities.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final items = _selectedQuantities.entries
          .where((e) => e.value > 0)
          .map((e) => {'dishId': e.key, 'quantity': e.value})
          .toList();

      if (items.isEmpty) {
        Navigator.pop(context);
        return;
      }

      await _api.post<Map<String, dynamic>>(
        ApiEndpoints.chefBookingAddItems(widget.orderId),
        body: {'items': items},
        requiresIdempotency: true,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onItemsAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your preparation list & cooking time have been updated!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _selectedQuantities.values.fold(0, (sum, q) => sum + q);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add More Dishes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Add-on Window Open',
                  style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your chef is en route. You can add quick sides or beverages before cooking starts.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const Divider(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _availableDishes.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (ctx, idx) {
                      final dish = _availableDishes[idx];
                      final qty = _selectedQuantities[dish.id] ?? 0;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${dish.prepTimeMinutes + dish.cookTimeMinutes} mins • ₹${dish.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (qty > 0) ...[
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.slate400),
                                  onPressed: () {
                                    setState(() {
                                      if (qty > 1) {
                                        _selectedQuantities[dish.id] = qty - 1;
                                      } else {
                                        _selectedQuantities.remove(dish.id);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.add_circle, size: 24, color: AppColors.primary),
                                onPressed: () {
                                  setState(() {
                                    _selectedQuantities[dish.id] = qty + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          EbicButton(
            label: totalItems == 0 ? 'Select Dishes to Add' : 'Add $totalItems Items to Dispatch',
            isLoading: _isSubmitting,
            onPressed: totalItems == 0 ? null : _submitAddons,
          ),
        ],
      ),
    );
  }
}
