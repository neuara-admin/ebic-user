import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'widgets/avatar_picker_sheet.dart';

/// Module 3 — Sections 20, 21, 26, 27: Add & Edit Household Member Form Screen
/// Supports complete personal details, profile image upload, and clinical health information
/// (height, weight, live BMI, dietary options, food allergies, health goals, and medical conditions).
class MemberFormScreen extends StatefulWidget {
  final HouseholdMemberModel? memberToEdit;

  const MemberFormScreen({super.key, this.memberToEdit});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  // Personal Information
  late TextEditingController _nameCtrl;
  String _selectedRelationship = 'CHILD';
  String _selectedGender = 'Female';
  DateTime? _selectedDob;
  String? _avatarUrl;

  // Health Information
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _notesCtrl;

  List<String> _selectedDietary = [];
  List<String> _selectedAllergies = [];
  List<String> _selectedGoals = [];
  List<String> _selectedConditions = [];

  bool _isSaving = false;
  String? _errorMessage;
  String? _dobError;
  List<HouseholdMemberModel> _householdMembers = [];

  final List<Map<String, String>> _relationships = [
    {'code': 'SELF', 'label': 'Self (Account Owner)'},
    {'code': 'SPOUSE', 'label': 'Spouse / Partner'},
    {'code': 'CHILD', 'label': 'Child'},
    {'code': 'PARENT', 'label': 'Parent'},
    {'code': 'SIBLING', 'label': 'Sibling'},
    {'code': 'OTHER', 'label': 'Other Dependent'},
  ];

  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  final List<String> _dietaryOptions = [
    'Vegetarian',
    'Non-Vegetarian',
    'Eggetarian',
    'Vegan',
    'Jain',
    'Keto / Low-Carb',
    'Diabetic-Friendly',
    'High-Protein',
  ];

  final List<String> _allergyOptions = [
    'None',
    'Lactose / Dairy',
    'Gluten / Celiac',
    'Peanuts',
    'Tree Nuts',
    'Shellfish',
    'Soy',
    'Eggs',
    'Fish',
  ];

  final List<String> _goalOptions = [
    'Weight Management',
    'Blood Sugar Control',
    'Heart Health',
    'PCOS / PCOD Support',
    'Digestive Health',
    'Muscle Gain',
    'General Vitality',
  ];

  final List<String> _conditionOptions = [
    'None',
    'Type 2 Diabetes',
    'Hypertension',
    'Hypothyroid',
    'High Cholesterol',
    'Fatty Liver',
    'Acid Reflux / GERD',
  ];

  bool get _isEditing => widget.memberToEdit != null;

  List<Map<String, String>> get _availableRelationships {
    final m = widget.memberToEdit;
    final hasSpouse = _householdMembers.any((existing) {
      if (m != null && existing.id == m.id) return false;
      return existing.relationship.toUpperCase() == 'SPOUSE';
    });

    return _relationships.where((r) {
      final code = r['code']!;
      if (code == 'SELF') return m?.isSelf == true;
      if (code == 'SPOUSE' && hasSpouse) return false;
      return true;
    }).toList();
  }

  void _initSelectedRelationship() {
    final available = _availableRelationships;
    final m = widget.memberToEdit;
    if (m != null) {
      final rel = m.relationship.toUpperCase();
      if (available.any((r) => r['code'] == rel)) {
        _selectedRelationship = rel;
      } else {
        _selectedRelationship = available.isNotEmpty ? available.first['code']! : 'OTHER';
      }
    } else {
      if (!available.any((r) => r['code'] == _selectedRelationship)) {
        _selectedRelationship = available.isNotEmpty ? available.first['code']! : 'CHILD';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final m = widget.memberToEdit;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _avatarUrl = m?.avatarUrl;

    _heightCtrl = TextEditingController(
      text: m?.heightCm != null ? m!.heightCm!.toStringAsFixed(0) : '',
    );
    _weightCtrl = TextEditingController(
      text: m?.weightKg != null ? m!.weightKg!.toStringAsFixed(1) : '',
    );
    _notesCtrl = TextEditingController(text: m?.healthGoals ?? '');

    _selectedDietary = List<String>.from(m?.dietaryPreferences ?? []);
    _selectedAllergies = List<String>.from(m?.allergies ?? []);
    _selectedConditions = List<String>.from(m?.medicalConditions ?? []);

    if (m?.healthGoals != null && m!.healthGoals!.trim().isNotEmpty) {
      final goals = m.healthGoals!.split(',').map((s) => s.trim());
      for (final g in goals) {
        if (_goalOptions.contains(g)) {
          _selectedGoals.add(g);
        }
      }
    }

    _householdMembers = MemberContext().members;
    _initSelectedRelationship();

    if (m != null) {
      if (m.sex != null && _genders.contains(m.sex)) {
        _selectedGender = m.sex!;
      }
      if (m.dateOfBirth != null) {
        try {
          _selectedDob = DateTime.parse(m.dateOfBirth!);
        } catch (_) {}
      }
      _fetchMemberHealthProfile(m.id);
    }

    _fetchHouseholdMembers();
  }

  Future<void> _fetchMemberHealthProfile(String memberId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.memberHealthProfile(memberId),
      );
      if (res.success && res.data != null && mounted) {
        final data = res.data!;
        setState(() {
          if (_heightCtrl.text.isEmpty && data['heightCm'] != null) {
            _heightCtrl.text = data['heightCm'].toString();
          }
          if (_weightCtrl.text.isEmpty && data['currentWeightKg'] != null) {
            _weightCtrl.text = data['currentWeightKg'].toString();
          }
          if (_notesCtrl.text.isEmpty && data['healthGoals'] != null) {
            _notesCtrl.text = data['healthGoals'].toString();
          }
          if (data['allergens'] is List && _selectedAllergies.isEmpty) {
            _selectedAllergies = (data['allergens'] as List)
                .map((a) {
                  if (a is Map && a['allergen'] is Map) {
                    return (a['allergen']['name'] ?? a['allergen']['code'] ?? '').toString();
                  }
                  return (a['name'] ?? a['code'] ?? a.toString()).toString();
                })
                .where((s) => s.isNotEmpty)
                .toList();
          }
          if (data['dietaryRestrictions'] is List && _selectedDietary.isEmpty) {
            _selectedDietary = (data['dietaryRestrictions'] as List)
                .map((d) {
                  if (d is Map && d['dietaryTag'] is Map) {
                    return (d['dietaryTag']['name'] ?? d['dietaryTag']['code'] ?? '').toString();
                  }
                  return (d['name'] ?? d['code'] ?? d.toString()).toString();
                })
                .where((s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchHouseholdMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null && mounted) {
        setState(() {
          _householdMembers = res.data!
              .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _initSelectedRelationship();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int? get _computedAge {
    if (_selectedDob == null) return null;
    final now = DateTime.now();
    int age = now.year - _selectedDob!.year;
    if (now.month < _selectedDob!.month ||
        (now.month == _selectedDob!.month && now.day < _selectedDob!.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  double? get _liveBmi {
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    if (h != null && w != null && h > 40 && w > 10) {
      final hm = h / 100.0;
      final val = w / (hm * hm);
      return double.parse(val.toStringAsFixed(1));
    }
    return null;
  }

  String? get _liveBmiCategory {
    final b = _liveBmi;
    if (b == null) return null;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get _liveBmiColor {
    final cat = _liveBmiCategory;
    switch (cat) {
      case 'Underweight':
        return Colors.blue;
      case 'Normal weight':
        return const Color(0xFF059669);
      case 'Overweight':
        return const Color(0xFFD97706);
      case 'Obese':
        return const Color(0xFFDC2626);
      default:
        return AppColors.slate500;
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'SELECT DATE OF BIRTH',
    );

    if (picked != null) {
      if (picked.isAfter(now)) {
        setState(() {
          _dobError = 'Date of birth cannot be in the future';
        });
      } else {
        setState(() {
          _selectedDob = picked;
          _dobError = null;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final newUrl = await AvatarPickerSheet.show(
      context,
      currentAvatarUrl: _avatarUrl,
      updateCurrentUser: widget.memberToEdit?.isSelf == true,
    );

    if (newUrl != null && mounted) {
      setState(() {
        _avatarUrl = newUrl.toString().isEmpty ? null : newUrl.toString();
      });
    }
  }

  Future<void> _saveMember() async {
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) return;

    if (_selectedDob == null) {
      setState(() => _dobError = 'Please select date of birth');
      return;
    }

    if (_selectedDob!.isAfter(DateTime.now())) {
      setState(() => _dobError = 'Date of birth cannot be in the future');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _dobError = null;
    });

    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());

    final combinedGoals = [
      ..._selectedGoals,
      if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
    ].join(', ');

    final payload = {
      'name': _nameCtrl.text.trim(),
      'relationship': _selectedRelationship,
      'sex': _selectedGender,
      'dateOfBirth': _selectedDob!.toIso8601String().split('T').first,
      'avatarUrl': _avatarUrl,
      'heightCm': ?height,
      'currentWeightKg': ?weight,
      if (combinedGoals.isNotEmpty) 'healthGoals': combinedGoals,
      'dietaryPreferences': _selectedDietary,
      'allergies': _selectedAllergies.where((a) => a != 'None').toList(),
      'medicalConditions': _selectedConditions.where((c) => c != 'None').toList(),
    };

    try {
      if (_isEditing) {
        final res = await _api.patch<Map<String, dynamic>>(
          ApiEndpoints.householdMemberDetail(widget.memberToEdit!.id),
          body: payload,
        );

        if (res.success) {
          await MemberContext().loadMembers(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_nameCtrl.text.trim()} updated successfully.')),
            );
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _isSaving = false;
            _errorMessage = res.message ?? 'Failed to update member.';
          });
        }
      } else {
        final res = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.householdMembers,
          body: payload,
        );

        if (res.success) {
          await MemberContext().loadMembers(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_nameCtrl.text.trim()} added to household.')),
            );
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _isSaving = false;
            _errorMessage = res.message ?? 'Failed to add member.';
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

  Future<void> _deleteMember() async {
    if (!_isEditing || widget.memberToEdit == null) return;
    final member = widget.memberToEdit!;
    if (member.isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account owner profile cannot be removed from household.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Household Member?'),
        content: Text(
          'Are you sure you want to remove ${member.name} from your household?',
        ),
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

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.delete<Map<String, dynamic>>(
        ApiEndpoints.householdMemberDetail(member.id),
      );

      if (res.success) {
        await MemberContext().loadMembers(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.name} removed from household.')),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = res.message ?? 'Failed to delete member.';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error deleting member: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;
    final fullAvatarUrl = hasAvatar
        ? (_avatarUrl!.startsWith('http')
            ? _avatarUrl!
            : '${AppConfig.apiBaseUrl.replaceAll(RegExp(r'/v1/?$'), '')}${_avatarUrl!.startsWith('/') ? '' : '/'}$_avatarUrl')
        : null;

    final liveBmi = _liveBmi;
    final liveCat = _liveBmiCategory;
    final bmiColor = _liveBmiColor;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Household Member' : 'Add Household Member'),
        actions: [
          if (_isEditing && widget.memberToEdit?.isSelf != true)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Delete Member',
              onPressed: _isSaving ? null : _deleteMember,
            ),
        ],
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

                // 1. Profile Image Upload Header
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primarySubtle,
                                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                                image: fullAvatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(fullAvatarUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: fullAvatarUrl == null
                                  ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _pickAvatar,
                        child: Text(
                          hasAvatar ? 'Change Profile Photo' : 'Upload Profile Photo',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Personal Information Section
                const Text(
                  'PERSONAL INFORMATION',
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
                      // Full Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Priya Sharma',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Member name is required';
                          }
                          final trimmed = val.trim();
                          if (trimmed.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          if (trimmed.length > 80) {
                            return 'Name cannot exceed 80 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Relationship Dropdown
                      DropdownButtonFormField<String>(
                        value: _availableRelationships.any((r) => r['code'] == _selectedRelationship)
                            ? _selectedRelationship
                            : (_availableRelationships.isNotEmpty ? _availableRelationships.first['code'] : 'OTHER'),
                        decoration: const InputDecoration(
                          labelText: 'Relationship to Account Owner *',
                          prefixIcon: Icon(Icons.family_restroom, size: 20),
                        ),
                        items: _availableRelationships.map((r) {
                          return DropdownMenuItem<String>(
                            value: r['code'],
                            child: Text(r['label']!),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRelationship = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender / Sex',
                          prefixIcon: Icon(Icons.transgender, size: 20),
                        ),
                        items: _genders.map((g) {
                          return DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGender = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth Field
                      InkWell(
                        onTap: _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth *',
                            prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                            errorText: _dobError,
                          ),
                          child: Text(
                            _selectedDob != null
                                ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year} (${_computedAge ?? 0} years)'
                                : 'Select date of birth',
                            style: TextStyle(
                              color: _selectedDob != null ? AppColors.slate900 : AppColors.slate400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Physical & Body Metrics Section
                const Text(
                  'BODY MEASUREMENTS & HEALTH VITALS',
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Height (cm)',
                                hintText: 'e.g. 172',
                                prefixIcon: Icon(Icons.height_rounded, size: 20),
                                suffixText: 'cm',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                hintText: 'e.g. 68.5',
                                prefixIcon: Icon(Icons.scale_rounded, size: 20),
                                suffixText: 'kg',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      if (liveBmi != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: bmiColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: bmiColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.monitor_weight_outlined, size: 18, color: bmiColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Calculated BMI: $liveBmi',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: bmiColor),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: bmiColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  liveCat ?? '',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Dietary Preferences Section
                const Text(
                  'DIETARY PREFERENCES',
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
                      const Text(
                        'Select preferred meal types for personalized recipe matching:',
                        style: TextStyle(fontSize: 12, color: AppColors.slate600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dietaryOptions.map((diet) {
                          final isSelected = _selectedDietary.contains(diet);
                          return FilterChip(
                            label: Text(diet),
                            selected: isSelected,
                            selectedColor: AppColors.primarySubtle,
                            checkmarkColor: AppColors.primaryDark,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDietary.add(diet);
                                } else {
                                  _selectedDietary.remove(diet);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 5. Food Allergies & Intolerances
                const Text(
                  'FOOD ALLERGIES & RESTRICTIONS',
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
                      const Text(
                        'Kitchen chef and clinical dietitians will strictly exclude these ingredients:',
                        style: TextStyle(fontSize: 12, color: AppColors.slate600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allergyOptions.map((allergy) {
                          final isSelected = _selectedAllergies.contains(allergy);
                          return FilterChip(
                            label: Text(allergy),
                            selected: isSelected,
                            selectedColor: allergy == 'None'
                                ? AppColors.slate200
                                : const Color(0xFFFEE2E2),
                            checkmarkColor: allergy == 'None' ? AppColors.slate800 : AppColors.danger,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? (allergy == 'None' ? AppColors.slate900 : AppColors.danger)
                                  : AppColors.slate700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (allergy == 'None') {
                                  if (selected) {
                                    _selectedAllergies = ['None'];
                                  } else {
                                    _selectedAllergies.remove('None');
                                  }
                                } else {
                                  _selectedAllergies.remove('None');
                                  if (selected) {
                                    _selectedAllergies.add(allergy);
                                  } else {
                                    _selectedAllergies.remove(allergy);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Health Goals & Medical Conditions
                const Text(
                  'HEALTH GOALS & CONDITIONS',
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
                      const Text(
                        'Primary Health Goals:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _goalOptions.map((g) {
                          final isSelected = _selectedGoals.contains(g);
                          return FilterChip(
                            label: Text(g),
                            selected: isSelected,
                            selectedColor: AppColors.primarySubtle,
                            checkmarkColor: AppColors.primaryDark,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedGoals.add(g);
                                } else {
                                  _selectedGoals.remove(g);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Known Medical Conditions:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.slate800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _conditionOptions.map((c) {
                          final isSelected = _selectedConditions.contains(c);
                          return FilterChip(
                            label: Text(c),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFEF3C7),
                            checkmarkColor: const Color(0xFFB45309),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              color: isSelected ? const Color(0xFFB45309) : AppColors.slate700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (c == 'None') {
                                  if (selected) {
                                    _selectedConditions = ['None'];
                                  } else {
                                    _selectedConditions.remove('None');
                                  }
                                } else {
                                  _selectedConditions.remove('None');
                                  if (selected) {
                                    _selectedConditions.add(c);
                                  } else {
                                    _selectedConditions.remove(c);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Additional Dietitian Notes / Details',
                          hintText: 'e.g. Needs low-sodium meals, vegetarian on Tuesdays',
                          prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                EbicButton(
                  label: _isEditing ? 'Update Household Member' : 'Add Household Member',
                  isLoading: _isSaving,
                  onPressed: _saveMember,
                ),

                if (_isEditing && widget.memberToEdit?.isSelf != true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete Household Member', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : _deleteMember,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
