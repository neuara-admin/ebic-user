import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_button.dart';
import '../../shared/widgets/ebic_card.dart';
import 'widgets/avatar_picker_sheet.dart';
import 'widgets/email_otp_sheet.dart';

/// Module 3 — Sections 23 & 24: Customer Profile & Personal Information Screen
/// Supports complete personal details, basic health vitals (height, weight, DOB, live BMI),
/// dietary preferences, food allergies, health goals, and medical conditions.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  // Personal Information
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late String _phone;
  String? _avatarUrl;
  bool _isPhoneVerified = true;
  bool _isEmailVerified = false;

  DateTime? _selectedDob;
  String _selectedGender = 'Female';
  String? _dobError;

  // Basic Health Information
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _notesCtrl;

  List<String> _selectedDietary = [];
  List<String> _selectedAllergies = [];
  List<String> _selectedGoals = [];
  List<String> _selectedConditions = [];

  HouseholdMemberModel? _selfMember;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    final user = _auth.user;
    _nameCtrl = TextEditingController(text: user?['name'] ?? '');
    _emailCtrl = TextEditingController(text: user?['email'] ?? '');
    _phone = user?['phone'] ?? user?['phoneNumber'] ?? '';
    _avatarUrl = user?['avatarUrl'];
    _isEmailVerified = user?['emailVerified'] == true;
    _isPhoneVerified = user?['phoneVerified'] == true;

    _heightCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    _heightCtrl.addListener(_onMetricChanged);
    _weightCtrl.addListener(_onMetricChanged);

    _fetchFreshProfileAndHealth();
  }

  void _onMetricChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _heightCtrl.removeListener(_onMetricChanged);
    _weightCtrl.removeListener(_onMetricChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
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

  Future<void> _fetchFreshProfileAndHealth() async {
    setState(() => _isLoading = true);
    try {
      // 1. User profile
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
      if (res.success && res.data != null) {
        _nameCtrl.text = res.data!['name'] ?? _nameCtrl.text;
        _emailCtrl.text = res.data!['email'] ?? _emailCtrl.text;
        _phone = res.data!['phone'] ?? _phone;
        _avatarUrl = res.data!['avatarUrl'] ?? _avatarUrl;
        _isPhoneVerified = res.data!['phoneVerified'] ?? true;
        _isEmailVerified = res.data!['emailVerified'] == true;
      }

      // 2. Self Household Member & Health Data
      final membersRes = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (membersRes.success && membersRes.data != null) {
        final allMembers = membersRes.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();

        HouseholdMemberModel? self;
        for (final m in allMembers) {
          if (m.isSelf || m.relationship.toUpperCase() == 'SELF') {
            self = m;
            break;
          }
        }
        self ??= allMembers.isNotEmpty ? allMembers.first : null;

        if (self != null) {
          _selfMember = self;
          if (self.sex != null && _genders.contains(self.sex)) {
            _selectedGender = self.sex!;
          }
          if (self.dateOfBirth != null) {
            try {
              _selectedDob = DateTime.parse(self.dateOfBirth!);
            } catch (_) {}
          }
          if (self.heightCm != null && _heightCtrl.text.isEmpty) {
            _heightCtrl.text = self.heightCm!.toStringAsFixed(0);
          }
          if (self.weightKg != null && _weightCtrl.text.isEmpty) {
            _weightCtrl.text = self.weightKg!.toStringAsFixed(1);
          }
          if (_selectedDietary.isEmpty) {
            _selectedDietary = List<String>.from(self.dietaryPreferences);
          }
          if (_selectedAllergies.isEmpty) {
            _selectedAllergies = List<String>.from(self.allergies);
          }
          if (_selectedConditions.isEmpty) {
            _selectedConditions = List<String>.from(self.medicalConditions);
          }
          if (self.healthGoals != null && self.healthGoals!.isNotEmpty) {
            final goals = self.healthGoals!.split(',').map((g) => g.trim());
            for (final g in goals) {
              if (_goalOptions.contains(g) && !_selectedGoals.contains(g)) {
                _selectedGoals.add(g);
              }
            }
          }

          // Also pull member health profile directly for completeness
          await _fetchMemberHealthProfile(self.id);
        }
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      setState(() {
        _selectedDob = picked;
        _dobError = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDob != null && _selectedDob!.isAfter(DateTime.now())) {
      setState(() => _dobError = 'Date of birth cannot be in the future');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final trimmedName = _nameCtrl.text.trim();
      final trimmedEmail = _emailCtrl.text.trim();

      // 1. Update user profile
      final userRes = await _api.patch<Map<String, dynamic>>(
        ApiEndpoints.me,
        body: {
          'name': trimmedName,
          'email': trimmedEmail.isNotEmpty ? trimmedEmail : null,
          'avatarUrl': _avatarUrl,
        },
      );

      if (!userRes.success || userRes.data == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = userRes.message ?? 'Failed to update profile.';
        });
        return;
      }

      // 2. Parse health payload
      final height = double.tryParse(_heightCtrl.text.trim());
      final weight = double.tryParse(_weightCtrl.text.trim());
      final combinedGoals = [
        ..._selectedGoals,
        if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
      ].join(', ');

      final memberPayload = <String, dynamic>{
        'name': trimmedName,
        'relationship': 'SELF',
        'isSelf': true,
        'sex': _selectedGender,
        'dateOfBirth': _selectedDob != null
            ? '${_selectedDob!.year.toString().padLeft(4, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
            : null,
        'avatarUrl': _avatarUrl,
        'heightCm': ?height,
        'currentWeightKg': ?weight,
        'dietaryPreferences': _selectedDietary,
        'allergies': _selectedAllergies,
        'healthGoals': combinedGoals.isNotEmpty ? combinedGoals : null,
        'medicalConditions': _selectedConditions,
      };

      // 3. Update or create self household member
      if (_selfMember != null) {
        await _api.patch<Map<String, dynamic>>(
          ApiEndpoints.householdMember(_selfMember!.id),
          body: memberPayload,
        );
      } else {
        await _api.post<Map<String, dynamic>>(
          ApiEndpoints.householdMembers,
          body: memberPayload,
        );
      }

      // 4. Update local auth state & token storage
      final updatedUser = Map<String, dynamic>.from(_auth.user ?? {});
      updatedUser['name'] = userRes.data!['name'];
      updatedUser['email'] = userRes.data!['email'];
      updatedUser['phone'] = userRes.data!['phone'] ?? _phone;
      updatedUser['avatarUrl'] = userRes.data!['avatarUrl'];
      updatedUser['emailVerified'] = userRes.data!['emailVerified'];
      updatedUser['phoneVerified'] = userRes.data!['phoneVerified'];
      _auth.updateCurrentUser(updatedUser);

      await TokenStorage.saveUser(
        id: userRes.data!['id'] ?? updatedUser['id'] ?? '',
        phone: updatedUser['phone'] ?? '',
        name: updatedUser['name'],
        email: updatedUser['email'],
        avatarUrl: userRes.data!['avatarUrl'],
      );

      // 5. Refresh MemberContext
      await MemberContext().loadMembers(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile and health details updated successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
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
        title: const Text('Edit Account Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar Banner with change option
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final updated = await AvatarPickerSheet.show(
                              context,
                              currentAvatarUrl: _avatarUrl,
                              updateCurrentUser: true,
                            );
                            if (updated != null && mounted) {
                              setState(() {
                                _avatarUrl = updated.toString().isNotEmpty ? updated.toString() : null;
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(AppConfig.resolveMediaUrl(_avatarUrl)!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                    ? Center(
                                        child: Text(
                                          _nameCtrl.text.trim().isNotEmpty
                                              ? _nameCtrl.text.trim()[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

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

                      // 1. Personal Information Section
                      const Text(
                        'PERSONAL INFORMATION',
                        style: TextStyle(
                          fontSize: 11,
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
                                labelText: 'Full Legal Name',
                                hintText: 'Enter your full legal name',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                if (val.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Date of Birth
                            InkWell(
                              onTap: _pickDateOfBirth,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date of Birth',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                                  suffixIcon: _computedAge != null
                                      ? Container(
                                          margin: const EdgeInsets.only(right: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySubtle,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$_computedAge yrs',
                                            style: const TextStyle(
                                              color: AppColors.primaryDark,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.arrow_drop_down),
                                  errorText: _dobError,
                                ),
                                child: Text(
                                  _selectedDob != null
                                      ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                                      : 'Tap to select birth date',
                                  style: TextStyle(
                                    color: _selectedDob != null ? AppColors.slate900 : AppColors.slate400,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Gender Selection
                            const Text(
                              'Gender / Biological Sex',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _genders.map((g) {
                                final isSelected = _selectedGender.toLowerCase() == g.toLowerCase();
                                return ChoiceChip(
                                  label: Text(g),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedGender = g);
                                  },
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.slate700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Basic Health & Biometrics Section
                      const Text(
                        'BASIC HEALTH & BIOMETRICS',
                        style: TextStyle(
                          fontSize: 11,
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
                                      hintText: 'e.g. 175',
                                      prefixIcon: Icon(Icons.height_rounded, size: 20),
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty) {
                                        final h = double.tryParse(val.trim());
                                        if (h == null || h < 40 || h > 260) {
                                          return 'Invalid (40-260 cm)';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (kg)',
                                      hintText: 'e.g. 70',
                                      prefixIcon: Icon(Icons.monitor_weight_outlined, size: 20),
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty) {
                                        final w = double.tryParse(val.trim());
                                        if (w == null || w < 10 || w > 300) {
                                          return 'Invalid (10-300 kg)';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Live Calculated BMI preview
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: _liveBmi != null
                                    ? _liveBmiColor.withOpacity(0.08)
                                    : AppColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _liveBmi != null
                                      ? _liveBmiColor.withOpacity(0.3)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: _liveBmi != null ? _liveBmiColor : AppColors.slate400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _liveBmi != null
                                              ? 'Calculated BMI: $_liveBmi kg/m²'
                                              : 'BMI Calculation',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _liveBmi != null ? AppColors.slate900 : AppColors.slate600,
                                          ),
                                        ),
                                        Text(
                                          _liveBmi != null
                                              ? 'Category: ${_liveBmiCategory ?? "Normal"}'
                                              : 'Enter height and weight above to calculate live BMI',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _liveBmi != null ? _liveBmiColor : AppColors.slate400,
                                            fontWeight: _liveBmi != null ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_liveBmi != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _liveBmiColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _liveBmiCategory ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
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

                      // 3. Dietary Preferences Section
                      const Text(
                        'DIETARY PREFERENCES',
                        style: TextStyle(
                          fontSize: 11,
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
                              'Select your dietary lifestyle options:',
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
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedDietary.add(diet);
                                      } else {
                                        _selectedDietary.remove(diet);
                                      }
                                    });
                                  },
                                  selectedColor: AppColors.primarySubtle,
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Food Allergies Section
                      const Text(
                        'FOOD ALLERGIES & INTOLERANCES',
                        style: TextStyle(
                          fontSize: 11,
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
                              'Select any food allergies for dietary safety:',
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
                                  onSelected: (selected) {
                                    setState(() {
                                      if (allergy == 'None') {
                                        if (selected) {
                                          _selectedAllergies = ['None'];
                                        } else {
                                          _selectedAllergies.clear();
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
                                  selectedColor: allergy == 'None'
                                      ? AppColors.emerald50
                                      : const Color(0xFFFEF2F2),
                                  checkmarkColor: allergy == 'None'
                                      ? AppColors.emerald700
                                      : AppColors.danger,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? (allergy == 'None' ? AppColors.emerald700 : AppColors.danger)
                                        : AppColors.slate700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Health Goals & Medical Conditions
                      const Text(
                        'HEALTH GOALS & CONDITIONS',
                        style: TextStyle(
                          fontSize: 11,
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
                              'Primary Health Goals',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _goalOptions.map((goal) {
                                final isSelected = _selectedGoals.contains(goal);
                                return FilterChip(
                                  label: Text(goal),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedGoals.add(goal);
                                      } else {
                                        _selectedGoals.remove(goal);
                                      }
                                    });
                                  },
                                  selectedColor: AppColors.primarySubtle,
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                            const Divider(height: 24),

                            const Text(
                              'Known Medical Conditions',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _conditionOptions.map((cond) {
                                final isSelected = _selectedConditions.contains(cond);
                                return FilterChip(
                                  label: Text(cond),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (cond == 'None') {
                                        if (selected) {
                                          _selectedConditions = ['None'];
                                        } else {
                                          _selectedConditions.clear();
                                        }
                                      } else {
                                        _selectedConditions.remove('None');
                                        if (selected) {
                                          _selectedConditions.add(cond);
                                        } else {
                                          _selectedConditions.remove(cond);
                                        }
                                      }
                                    });
                                  },
                                  selectedColor: cond == 'None'
                                      ? AppColors.emerald50
                                      : const Color(0xFFFFFBEB),
                                  checkmarkColor: cond == 'None'
                                      ? AppColors.emerald700
                                      : const Color(0xFFD97706),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? (cond == 'None' ? AppColors.emerald700 : const Color(0xFFB45309))
                                        : AppColors.slate700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Clinical Notes
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Clinical Notes / Specific Details (Optional)',
                                hintText: 'Any symptoms, food dislikes, or medical guidelines...',
                                prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 6. Contact & Authentication Section
                      const Text(
                        'AUTHENTICATION & CONTACT',
                        style: TextStyle(
                          fontSize: 11,
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
                            // Email
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (val) {
                                final currentSavedEmail = _auth.user?['email'] as String? ?? '';
                                final isSavedAndVerified = _auth.user?['emailVerified'] == true;
                                if (val.trim() != currentSavedEmail) {
                                  if (_isEmailVerified) {
                                    setState(() => _isEmailVerified = false);
                                  }
                                } else if (isSavedAndVerified && !_isEmailVerified) {
                                  setState(() => _isEmailVerified = true);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'name@example.com',
                                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                suffixIcon: _emailCtrl.text.trim().isNotEmpty
                                    ? (_isEmailVerified
                                        ? const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: AppColors.emerald700, size: 16),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Verified',
                                                  style: TextStyle(
                                                    color: AppColors.emerald700,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: () async {
                                              final email = _emailCtrl.text.trim();
                                              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                              if (!emailRegex.hasMatch(email)) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Please enter a valid email address first.')),
                                                );
                                                return;
                                              }
                                              final verified = await EmailOtpSheet.show(context, email: email);
                                              if (verified == true && mounted) {
                                                setState(() => _isEmailVerified = true);
                                              }
                                            },
                                            child: const Text(
                                              'Verify OTP',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ))
                                    : null,
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                            const Divider(height: 24),

                            // Phone
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.phone_iphone_rounded, color: AppColors.slate700, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Registered Phone', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _phone.isNotEmpty ? _phone : 'No phone registered',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.emerald700.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_isPhoneVerified ? Icons.check : Icons.warning_amber, size: 12, color: _isPhoneVerified ? AppColors.emerald700 : AppColors.warning),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isPhoneVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        style: TextStyle(color: _isPhoneVerified ? AppColors.emerald700 : AppColors.warning, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Phone number changes require security verification with SMS OTP and are managed via Account Security.',
                        style: TextStyle(fontSize: 11, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 32),

                      EbicButton(
                        label: 'Save Profile Changes',
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
