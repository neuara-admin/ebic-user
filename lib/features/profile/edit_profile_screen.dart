import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/context/member_context.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/height_weight_input_widget.dart';
import '../../shared/widgets/dietary_health_selection_widget.dart';
import '../../shared/widgets/gender_selection_widget.dart';
import '../../shared/widgets/clinical_notes_input_widget.dart';
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
          if (self.clinicalNotes != null && self.clinicalNotes!.isNotEmpty && _notesCtrl.text.isEmpty) {
            _notesCtrl.text = self.clinicalNotes!;
          }
          if (self.healthGoals != null && self.healthGoals!.isNotEmpty) {
            final goals = self.healthGoals!.split(',').map((g) => g.trim()).toList();
            for (final g in goals) {
              if (DietaryHealthSelectionWidget.goalOptions.contains(g)) {
                if (!_selectedGoals.contains(g)) _selectedGoals.add(g);
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
          if (_notesCtrl.text.isEmpty && data['clinicalNotes'] != null && data['clinicalNotes'].toString().isNotEmpty) {
            _notesCtrl.text = data['clinicalNotes'].toString();
          }
          if (data['healthGoals'] != null) {
            final raw = data['healthGoals'].toString();
            final goals = raw.split(',').map((s) => s.trim()).toList();
            for (final g in goals) {
              if (DietaryHealthSelectionWidget.goalOptions.contains(g)) {
                if (!_selectedGoals.contains(g)) _selectedGoals.add(g);
              }
            }
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
      final memberPayload = <String, dynamic>{
        'name': trimmedName,
        'relationship': 'SELF',
        'isSelf': true,
        'sex': _selectedGender,
        if (_selectedDob != null)
          'dateOfBirth':
              '${_selectedDob!.year.toString().padLeft(4, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}',
        'avatarUrl': _avatarUrl,
        ...(height != null ? {'heightCm': height} : {}),
        ...(weight != null ? {'currentWeightKg': weight} : {}),
        'dietaryPreferences': _selectedDietary,
        'allergies': _selectedAllergies.where((a) => a != 'None').toList(),
        if (_selectedGoals.isNotEmpty) 'healthGoals': _selectedGoals.join(', '),
        if (_notesCtrl.text.trim().isNotEmpty) 'clinicalNotes': _notesCtrl.text.trim(),
        'medicalConditions': _selectedConditions.where((c) => c != 'None').toList(),
      };

      // 3. Update or create self household member
      if (_selfMember != null) {
        final memberRes = await _api.patch<Map<String, dynamic>>(
          ApiEndpoints.householdMember(_selfMember!.id),
          body: memberPayload,
        );
        if (!memberRes.success) {
          setState(() {
            _isSaving = false;
            _errorMessage = memberRes.message ?? 'Failed to update member health profile.';
          });
          return;
        }
      } else {
        final memberRes = await _api.post<Map<String, dynamic>>(
          ApiEndpoints.householdMembers,
          body: memberPayload,
        );
        if (!memberRes.success) {
          setState(() {
            _isSaving = false;
            _errorMessage = memberRes.message ?? 'Failed to create member health profile.';
          });
          return;
        }
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
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                    ? Image.network(
                                        AppConfig.resolveMediaUrl(_avatarUrl) ?? _avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
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
                                        ),
                                      )
                                    : Center(
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
                                      ),
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
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date of Birth',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                                  suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.slate500),
                                  errorText: _dobError,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedDob != null
                                            ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                                            : 'Tap to select birth date',
                                        style: TextStyle(
                                          color: _selectedDob != null ? AppColors.slate900 : AppColors.slate400,
                                          fontSize: 14,
                                          fontWeight: _selectedDob != null ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_computedAge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySubtle,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          '$_computedAge yrs',
                                          style: const TextStyle(
                                            color: AppColors.primaryDark,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Gender Selection
                            GenderSelectionWidget(
                              selectedGender: _selectedGender,
                              genders: _genders,
                              onGenderChanged: (g) => setState(() => _selectedGender = g),
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
                        child: HeightWeightInputWidget(
                          initialHeightCm: double.tryParse(_heightCtrl.text.trim()) ?? 175.0,
                          initialWeightKg: double.tryParse(_weightCtrl.text.trim()) ?? 68.0,
                          onHeightChanged: (h) {
                            _heightCtrl.text = h != null ? h.toStringAsFixed(1) : '';
                            setState(() {});
                          },
                          onWeightChanged: (w) {
                            _weightCtrl.text = w != null ? w.toStringAsFixed(1) : '';
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Dietary Preferences Section
                DietaryHealthSelectionWidget(
                  selectedDietary: _selectedDietary,
                  onDietaryChanged: (val) => setState(() => _selectedDietary = val),
                  selectedAllergies: _selectedAllergies,
                  onAllergiesChanged: (val) => setState(() => _selectedAllergies = val),
                  selectedGoals: _selectedGoals,
                  onGoalsChanged: (val) => setState(() => _selectedGoals = val),
                  selectedConditions: _selectedConditions,
                  onConditionsChanged: (val) => setState(() => _selectedConditions = val),
                ),
                const SizedBox(height: 18),

                // Clinical Notes
                ClinicalNotesInputWidget(controller: _notesCtrl),
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
