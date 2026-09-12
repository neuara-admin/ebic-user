import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_card.dart';

/// Module 3 — Sections 29, 30 & 31: Saved Delivery Kitchen Addresses Screen
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final ApiClient _api = ApiClient();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  String? _recheckingAddressId;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.customerAddresses);
      if (res.success && res.data != null) {
        setState(() {
          _addresses = res.data!
              .map((json) => AddressModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _addresses = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultAddress(AddressModel addr) async {
    try {
      final res = await _api.patch<Map<String, dynamic>>(
        ApiEndpoints.customerAddressSetDefault(addr.id),
      );

      if (res.success) {
        _fetchAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${addr.kitchenLabelDisplayName} set as primary kitchen.'),
              backgroundColor: AppColors.emerald700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _recheckServiceability(AddressModel addr) async {
    setState(() => _recheckingAddressId = addr.id);

    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.addressServiceabilityCheck(addr.id),
      );

      if (res.success && res.data != null && mounted) {
        final result = ServiceabilityResult.fromJson(res.data!);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  result.isServiceable ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  color: result.isServiceable ? AppColors.emerald700 : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isServiceable ? 'Kitchen Serviceable' : 'Service Notice',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _fetchAddresses();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _recheckingAddressId = null);
    }
  }

  Future<void> _deleteAddress(AddressModel addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Kitchen Address?'),
        content: Text('Are you sure you want to remove ${addr.kitchenLabelDisplayName} (${addr.line1})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        ApiEndpoints.customerAddressDetail(addr.id),
      );

      if (res.success) {
        _fetchAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kitchen address deleted successfully.')),
          );
        }
      } else {
        // Section 58: Active booking conflict handling
        final msg = res.message ?? 'Failed to delete address';
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Cannot Delete Kitchen', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Text(
                msg.contains('Active chef bookings') || msg.contains('bookings reference')
                    ? 'This address is linked to an active or upcoming chef booking. To preserve historical booking records, it cannot be deleted right now.'
                    : msg,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Saved Kitchen Addresses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              // Section 79: Empty state
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.slate100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.soup_kitchen_outlined, size: 48, color: AppColors.slate400),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No saved kitchen addresses',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add your home or vacation kitchen address to check certified chef serviceability and book meals.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate500, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final added = await Navigator.pushNamed(context, AppRoutes.addressForm);
                            if (added == true) _fetchAddresses();
                          },
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add Kitchen Address'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAddresses,
                  color: AppColors.primary,
                  child: SafeArea(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (ctx, idx) {
                        final addr = _addresses[idx];
                        return _buildAddressCard(addr);
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
        label: const Text('Add Kitchen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final added = await Navigator.pushNamed(context, AppRoutes.addressForm);
          if (added == true) _fetchAddresses();
        },
      ),
    );
  }

  Widget _buildAddressCard(AddressModel addr) {
    final isRechecking = _recheckingAddressId == addr.id;

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kitchen Type Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  addr.kitchenIcon,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            addr.kitchenLabelDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Section 51 & 52: Serviceability Status Badge
                        _buildServiceabilityBadge(addr),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addr.formattedAddress,
                      style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.3),
                    ),
                    if (addr.recipientName != null && addr.recipientName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Contact: ${addr.recipientName} ${addr.phone != null ? "(${addr.phone})" : ""}',
                              style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (addr.hubName != null && addr.hubName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.hub_outlined, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Assigned Hub: ${addr.hubName}',
                              style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Edit Address
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.slate600, size: 18),
                tooltip: 'Edit Kitchen',
                onPressed: () async {
                  final updated = await Navigator.pushNamed(
                    context,
                    AppRoutes.addressForm,
                    arguments: addr,
                  );
                  if (updated == true) _fetchAddresses();
                },
              ),
              // Delete Address
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.slate400, size: 20),
                tooltip: 'Delete Kitchen',
                onPressed: () => _deleteAddress(addr),
              ),
            ],
          ),
          const Divider(height: 20),
          // Section 55 & 56: Default Address Indicator & Selector (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (addr.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emerald700.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: AppColors.emerald700),
                      SizedBox(width: 4),
                      Text(
                        'PRIMARY KITCHEN',
                        style: TextStyle(color: AppColors.emerald700, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () => _setDefaultAddress(addr),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Set as Primary',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate700),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: isRechecking ? null : () => _recheckServiceability(addr),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRechecking)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          else
                            const Icon(Icons.refresh, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          const Text('Live Check', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${addr.lat.toStringAsFixed(3)}, ${addr.lng.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceabilityBadge(AddressModel addr) {
    final isServ = addr.isServiceable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isServ ? AppColors.emerald50 : AppColors.rose50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isServ ? 'SERVICEABLE' : 'UNSERVICEABLE',
        style: TextStyle(
          color: isServ ? AppColors.emerald700 : AppColors.danger,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
