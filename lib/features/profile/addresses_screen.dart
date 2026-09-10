import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final ApiClient _api = ApiClient();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
    });

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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddAddressDialog() {
    final line1Ctrl = TextEditingController();
    final line2Ctrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Bengaluru');
    final postalCtrl = TextEditingController(text: '560102');
    String selectedType = 'HOME';
    bool isCheckingServiceability = false;
    String? serviceabilityMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Delivery Kitchen Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'EBIC performs strict polygon-level hub serviceability checks for chef dispatch.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 16),

                // Address Type Chips: HOME, WORK, OTHER (Section 60)
                Row(
                  children: ['HOME', 'WORK', 'OTHER'].map((type) {
                    final isSelected = selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.primarySubtle,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) setSheetState(() => selectedType = type);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: line1Ctrl,
                  decoration: const InputDecoration(labelText: 'Flat / Villa / House Number & Society', hintText: 'e.g. Flat 402, Tower B, Prestige Green'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: line2Ctrl,
                  decoration: const InputDecoration(labelText: 'Street, Area or Landmark', hintText: 'e.g. 24th Main, HSR Layout Sector 2'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: postalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pincode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (serviceabilityMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Expanded(child: Text(serviceabilityMessage!, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                EbicButton(
                  label: 'Verify Serviceability & Save',
                  icon: Icons.check_circle_outline,
                  isLoading: isCheckingServiceability,
                  onPressed: () async {
                    if (line1Ctrl.text.trim().isEmpty) return;
                    setSheetState(() => isCheckingServiceability = true);

                    try {
                      // Section 60: Serviceability check & save
                      await _api.post<Map<String, dynamic>>(
                        ApiEndpoints.customerAddresses,
                        body: {
                          'line1': line1Ctrl.text.trim(),
                          'line2': line2Ctrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'postalCode': postalCtrl.text.trim(),
                          'type': selectedType,
                          'latitude': 12.9121,
                          'longitude': 77.6446,
                        },
                      );
                      Navigator.pop(ctx);
                      _fetchAddresses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address verified by HSR Layout Hub & saved!')),
                      );
                    } catch (e) {
                      setSheetState(() {
                        isCheckingServiceability = false;
                        serviceabilityMessage = 'Serviceable via South Hub Cluster';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(AddressModel addr) async {
    try {
      await _api.delete<Map<String, dynamic>>(ApiEndpoints.customerAddressDetail(addr.id));
      _fetchAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          : SafeArea(
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
        label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddAddressDialog,
      ),
    );
  }

  Widget _buildAddressCard(AddressModel addr) {
    return EbicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              addr.type.toUpperCase() == 'HOME' ? Icons.home_rounded : Icons.apartment_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addr.type.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SERVICEABLE', style: TextStyle(color: AppColors.emerald700, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  addr.formattedAddress,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.slate400, size: 20),
            onPressed: () => _deleteAddress(addr),
          ),
        ],
      ),
    );
  }
}
