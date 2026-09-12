import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/address_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'widgets/kitchen_map_picker_sheet.dart';

/// Module 3 — Sections 29, 30, 31: Add & Edit Delivery Kitchen Address Screen
class AddressFormScreen extends StatefulWidget {
  final AddressModel? addressToEdit;

  const AddressFormScreen({super.key, this.addressToEdit});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Kitchen Types (replacing improper Work/Office)
  String _selectedType = 'HOME';
  late TextEditingController _recipientNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _line1Ctrl;
  late TextEditingController _line2Ctrl;
  late TextEditingController _landmarkCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _postalCtrl;
  late TextEditingController _customLabelCtrl;

  bool _isDefault = false;

  // Exact Coordinates from Map (Defaults to Jubilee Hills, Hyderabad)
  double _lat = 17.4319;
  double _lng = 78.4073;
  bool _isMapSelected = false;
  String? _detectedHubName;
  bool _isServiceableAtCoords = true;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.addressToEdit != null;

  static const List<Map<String, dynamic>> _addressTypes = [
    {
      'code': 'HOME',
      'label': 'Home',
      'icon': Icons.home_rounded,
    },
    {
      'code': 'OTHER',
      'label': 'Other',
      'icon': Icons.location_on_rounded,
    },
  ];

  static const List<String> _quickLabelSuggestions = [
    "Parents' Home",
    'Villa',
    'Farmhouse',
    'Guest House',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.addressToEdit;
    final user = _auth.user;

    final existingLabel = a?.label ?? 'HOME';
    if (existingLabel.toUpperCase() == 'HOME') {
      _selectedType = 'HOME';
      _customLabelCtrl = TextEditingController();
    } else {
      _selectedType = 'OTHER';
      _customLabelCtrl = TextEditingController(
        text: existingLabel.toUpperCase() == 'OTHER' ? '' : existingLabel,
      );
    }

    _recipientNameCtrl = TextEditingController(
      text: a?.recipientName ?? user?['name'] ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: a?.phone ?? user?['phone'] ?? user?['phoneNumber'] ?? '',
    );
    _line1Ctrl = TextEditingController(text: a?.line1 ?? '');
    _line2Ctrl = TextEditingController(text: a?.line2 ?? '');
    _landmarkCtrl = TextEditingController(text: a?.landmark ?? '');
    _cityCtrl = TextEditingController(text: a?.city ?? 'Hyderabad');
    _stateCtrl = TextEditingController(text: a?.state ?? 'Telangana');
    _postalCtrl = TextEditingController(text: a?.postalCode ?? '500033');

    _isDefault = a?.isDefault ?? false;

    if (a != null) {
      _lat = a.lat;
      _lng = a.lng;
      _isMapSelected = true;
      _detectedHubName = a.hubName;
      _isServiceableAtCoords = a.isServiceable;
    } else {
      _checkServiceabilityForCurrentCoords();
    }
  }

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _customLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkServiceabilityForCurrentCoords() async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.serviceabilityCheck,
        body: {'latitude': _lat, 'longitude': _lng},
        requiresAuth: false,
      );
      if (res.success && res.data != null && mounted) {
        final isServ = res.data!['serviceable'] == true;
        final hub = res.data!['hub'] as Map<String, dynamic>?;
        setState(() {
          _isServiceableAtCoords = isServ;
          _detectedHubName = hub?['name'] ?? res.data!['hubName'];
        });
      }
    } catch (_) {}
  }

  Future<void> _openMapPicker() async {
    final result = await KitchenMapPickerSheet.show(
      context,
      initialLat: _lat,
      initialLng: _lng,
    );

    if (result != null && mounted) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
        _isMapSelected = true;
        _isServiceableAtCoords = result.isServiceable;
        _detectedHubName = result.hubName;

        // Auto-fill fields from map reverse geocoding if available
        if (result.street != null && result.street!.isNotEmpty) {
          if (_line1Ctrl.text.trim().isEmpty) {
            _line1Ctrl.text = result.street!;
          } else if (!_line1Ctrl.text.contains(result.street!)) {
            _line2Ctrl.text = result.street!;
          }
        }
        if (result.locality != null && result.locality!.isNotEmpty) {
          _line2Ctrl.text = result.locality!;
        }
        if (result.city != null && result.city!.isNotEmpty) {
          _cityCtrl.text = result.city!;
        }
        if (result.postalCode != null && result.postalCode!.isNotEmpty) {
          _postalCtrl.text = result.postalCode!;
        }
        if (result.state != null && result.state!.isNotEmpty) {
          _stateCtrl.text = result.state!;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isServiceable
                ? 'Exact kitchen coordinates locked: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)} (${result.hubName ?? "Serviceable Hub"})'
                : 'Exact kitchen coordinates locked: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
          ),
          backgroundColor: result.isServiceable ? AppColors.emerald700 : AppColors.slate800,
        ),
      );
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final label = _selectedType == 'HOME'
        ? 'Home'
        : (_customLabelCtrl.text.trim().isNotEmpty ? _customLabelCtrl.text.trim() : 'Other');

    final payload = <String, dynamic>{
      'label': label,
      'line1': _line1Ctrl.text.trim(),
      'city': _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Hyderabad',
      'state': _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : 'Telangana',
      'postalCode': _postalCtrl.text.trim(),
      'country': 'India',
      'lat': _lat,
      'lng': _lng,
      'geocodingStatus': _isMapSelected ? 'VERIFIED' : 'PENDING',
      'isDefault': _isDefault,
    };

    if (_recipientNameCtrl.text.trim().isNotEmpty) {
      payload['recipientName'] = _recipientNameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim().isNotEmpty) {
      payload['phone'] = _phoneCtrl.text.trim();
    }
    if (_line2Ctrl.text.trim().isNotEmpty) {
      payload['line2'] = _line2Ctrl.text.trim();
      payload['locality'] = _line2Ctrl.text.trim();
    }
    if (_landmarkCtrl.text.trim().isNotEmpty) {
      payload['landmark'] = _landmarkCtrl.text.trim();
    }

    try {
      if (_isEditing) {
        final res = await _api.patch<Map<String, dynamic>>(
          ApiEndpoints.customerAddressDetail(widget.addressToEdit!.id),
          body: payload,
        );

        if (res.success && res.data != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kitchen address updated successfully.')),
            );
            Navigator.pop(context, true);
          }
          return;
        }

        // If the address to update is not found on the backend (e.g. database reseeded/session mismatch),
        // gracefully fallback to creating it so user input is never lost.
        if (res.error?.code == 'RESOURCE_NOT_FOUND' || res.error?.code == 'HTTP_404') {
          final createRes = await _api.post<Map<String, dynamic>>(
            ApiEndpoints.customerAddresses,
            body: payload,
          );
          if (createRes.success && createRes.data != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kitchen address saved successfully.')),
              );
              Navigator.pop(context, true);
            }
            return;
          }
        }

        final errorMsg = res.error?.message ?? res.message ?? 'Failed to update address.';
        debugPrint('Address update failed: ${res.error?.code} - $errorMsg');
        setState(() {
          _isSaving = false;
          _errorMessage = errorMsg;
        });
      } else {
        // Section 43: Create address with backend authoritative serviceability check
        final res = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.customerAddresses,
          body: payload,
        );

        if (res.success && res.data != null) {
          final hubName = res.data!['hub']?['name'] ?? _detectedHubName ?? 'EBIC Hub';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kitchen address saved & assigned to $hubName!'),
                backgroundColor: AppColors.emerald700,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          final errorMsg = res.error?.message ?? res.message ?? 'Address could not be saved.';
          debugPrint('Address save failed: ${res.error?.code} - $errorMsg details: ${res.error?.details}');
          setState(() {
            _isSaving = false;
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Kitchen Address' : 'Add Kitchen Address'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rose50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 1. EXACT KITCHEN MAP LOCATION PICKER (Section 29 & 43) ────────
                const Text(
                  'EXACT KITCHEN PINPOINT (MAP LOCATION)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                EbicCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.map_rounded, color: AppColors.primaryDark, size: 22),
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
                                        _isMapSelected ? 'Location Selected' : 'Set Exact Location',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (_isMapSelected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle, color: AppColors.emerald700, size: 16),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lat: ${_lat.toStringAsFixed(4)}, Lng: ${_lng.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.pin_drop, size: 16),
                            label: Text(_isMapSelected ? 'Change Pin' : 'Pick on Map'),
                            onPressed: _openMapPicker,
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // Serviceability readout from backend
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isServiceableAtCoords ? AppColors.emerald50 : AppColors.amber50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isServiceableAtCoords
                                ? AppColors.emerald700.withOpacity(0.2)
                                : AppColors.amber700.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isServiceableAtCoords ? Icons.verified : Icons.info_outline,
                              size: 16,
                              color: _isServiceableAtCoords ? AppColors.emerald700 : AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isServiceableAtCoords
                                    ? '✓ Serviceable by ${_detectedHubName ?? "Hyderabad Hub"} (Private chefs available)'
                                    : '⚠ Outside current active hub polygon (Tap "Pick on Map" to reposition)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isServiceableAtCoords ? AppColors.emerald700 : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. ADDRESS TYPE: HOME OR OTHER (Section 29 & 42) ─────────
                const Text(
                  'SAVE ADDRESS AS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: _addressTypes.map((kt) {
                    final code = kt['code'] as String;
                    final label = kt['label'] as String;
                    final icon = kt['icon'] as IconData;
                    final isSelected = _selectedType == code;

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 18,
                          color: isSelected ? AppColors.primaryDark : AppColors.slate600,
                        ),
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.primarySubtle,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.slate200,
                          width: isSelected ? 1.5 : 1,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedType = code);
                        },
                      ),
                    );
                  }).toList(),
                ),

                if (_selectedType == 'OTHER') ...[
                  const SizedBox(height: 14),
                  EbicCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _customLabelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Custom Label Name',
                            hintText: "e.g. Parents' Home, Villa, Farmhouse",
                            prefixIcon: Icon(Icons.bookmark_border_rounded, size: 20),
                          ),
                          validator: (val) {
                            if (_selectedType == 'OTHER' && (val == null || val.trim().isEmpty)) {
                              return 'Please enter a name for this address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Quick suggestions:',
                          style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _quickLabelSuggestions.map((sug) {
                            return ActionChip(
                              label: Text(sug),
                              labelStyle: const TextStyle(fontSize: 11, color: AppColors.slate700),
                              backgroundColor: AppColors.slate100,
                              onPressed: () {
                                setState(() {
                                  _customLabelCtrl.text = sug;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── 3. RESIDENTIAL KITCHEN DETAILS (Section 42 & 44) ───────────────
                const Text(
                  'KITCHEN & RESIDENCE DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                EbicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _line1Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Flat / Villa / House No. & Building *',
                          hintText: 'e.g. Flat 402, Green Meadows',
                          prefixIcon: Icon(Icons.home_outlined, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'House / flat number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _line2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Street, Road, Locality *',
                          hintText: 'e.g. Road No. 36, Jubilee Hills',
                          prefixIcon: Icon(Icons.place_outlined, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Street or locality is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _landmarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prominent Landmark (Optional)',
                          hintText: 'e.g. Near Peddamma Temple / Opposite Metro',
                          prefixIcon: Icon(Icons.flag_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                prefixIcon: Icon(Icons.location_city, size: 20),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _postalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Postal PIN *',
                                prefixIcon: Icon(Icons.markunread_mailbox_outlined, size: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length != 6) {
                                  return 'Enter 6-digit PIN';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 4. KITCHEN CONTACT PERSON ──────────────────────────────────────
                const Text(
                  'KITCHEN CONTACT ON CHEF ARRIVAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                EbicCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _recipientNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person Name',
                          hintText: 'e.g. Rahul Sharma',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone (For Chef entry & gate pass)',
                          hintText: 'e.g. +91 98765 43210',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 5. DEFAULT KITCHEN ADDRESS TOGGLE (Section 55 & 56) ───────────
                EbicCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Set as Primary Cooking Kitchen',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    subtitle: const Text(
                      'Default kitchen automatically selected for Chef visits & meal preparations',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                    value: _isDefault,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isDefault = val),
                  ),
                ),
                const SizedBox(height: 24),

                EbicButton(
                  label: _isEditing ? 'Save Kitchen Changes' : 'Verify Hub & Save Kitchen Address',
                  icon: Icons.check_circle_outline,
                  isLoading: _isSaving,
                  onPressed: _saveAddress,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
