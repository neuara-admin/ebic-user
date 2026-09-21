import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_profile_model.dart';
import '../widgets/unsaved_changes_dialog.dart';
import 'body_measurements_screen.dart';
import 'health_goals_screen.dart';
import 'dietary_preferences_screen.dart';
import 'allergies_screen.dart';
import 'lifestyle_screen.dart';
import 'health_data_permissions_screen.dart';

class HealthProfileEditScreen extends StatefulWidget {
  final String memberId;
  final HealthProfileModel initialProfile;

  const HealthProfileEditScreen({
    super.key,
    required this.memberId,
    required this.initialProfile,
  });

  @override
  State<HealthProfileEditScreen> createState() => _HealthProfileEditScreenState();
}

class _HealthProfileEditScreenState extends State<HealthProfileEditScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  late HealthProfileModel _profile;
  bool _isLoading = false;

  // Basic Info Controllers
  late TextEditingController _dobController;
  String _selectedSex = 'MALE';
  bool _isBasicDirty = false;
  bool _isSavingBasic = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _dobController = TextEditingController(text: _profile.dateOfBirth?.split('T').first ?? '');
    _selectedSex = _profile.biologicalSex ?? 'MALE';
  }

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    final p = await _dataSource.getProfile(widget.memberId);
    if (p != null && mounted) {
      setState(() {
        _profile = p;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBasicInfo() async {
    setState(() => _isSavingBasic = true);
    try {
      final updated = await _dataSource.updateProfile({
        'memberId': widget.memberId,
        'dateOfBirth': _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        'biologicalSex': _selectedSex,
      });

      if (mounted) {
        setState(() {
          _isSavingBasic = false;
          _isBasicDirty = false;
          if (updated != null) _profile = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Basic information saved.'),
            backgroundColor: AppColors.emerald600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingBasic = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isBasicDirty) {
      return await UnsavedChangesDialog.show(context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        appBar: AppBar(
          title: const Text('Edit Health Profile'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.slate900,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Sections',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Each section is saved directly to the backend with point-in-time auditing.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Basic Information In-Place Editor
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '1. Basic Information',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _dobController,
                            decoration: InputDecoration(
                              labelText: 'Date of Birth (YYYY-MM-DD)',
                              hintText: '1990-05-15',
                              prefixIcon: const Icon(Icons.cake_outlined, size: 18),
                              filled: true,
                              fillColor: AppColors.slate50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => setState(() => _isBasicDirty = true),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _selectedSex,
                            decoration: InputDecoration(
                              labelText: 'Biological Sex',
                              prefixIcon: const Icon(Icons.wc_outlined, size: 18),
                              filled: true,
                              fillColor: AppColors.slate50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MALE', child: Text('Male')),
                              DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Other / Prefer not to say')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSex = val;
                                  _isBasicDirty = true;
                                });
                              }
                            },
                          ),

                          if (_isBasicDirty) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSavingBasic ? null : _saveBasicInfo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _isSavingBasic
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Save Basic Info'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Body Measurements
                    _buildSectionTile(
                      step: '2',
                      title: 'Body Measurements',
                      subtitle: '${_profile.heightCm?.toStringAsFixed(0) ?? '--'} cm • ${_profile.currentWeightKg?.toStringAsFixed(1) ?? '--'} kg • BMI ${_profile.bmi?.toStringAsFixed(1) ?? '--'}',
                      icon: Icons.height_rounded,
                      color: AppColors.secondary,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BodyMeasurementsScreen(memberId: widget.memberId, profile: _profile),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),

                    // Section 3: Goals
                    _buildSectionTile(
                      step: '3',
                      title: 'Health Goals',
                      subtitle: '${_profile.goals.length} active goal${_profile.goals.length == 1 ? '' : 's'} defined',
                      icon: Icons.flag_rounded,
                      color: const Color(0xFFD97706),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HealthGoalsScreen(memberId: widget.memberId),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),

                    // Section 4: Dietary
                    _buildSectionTile(
                      step: '4',
                      title: 'Dietary Preferences',
                      subtitle: '${_profile.dietaryRestrictions.length} tags selected • dislikes & cuisines',
                      icon: Icons.restaurant_menu_rounded,
                      color: const Color(0xFF059669),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DietaryPreferencesScreen(memberId: widget.memberId, profile: _profile),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),

                    // Section 5: Allergies
                    _buildSectionTile(
                      step: '5',
                      title: 'Allergies & Food Safety',
                      subtitle: '${_profile.allergies.length} safety constraint${_profile.allergies.length == 1 ? '' : 's'} recorded',
                      icon: Icons.shield_rounded,
                      color: AppColors.danger,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllergiesScreen(memberId: widget.memberId),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),

                    // Section 6: Lifestyle
                    _buildSectionTile(
                      step: '6',
                      title: 'Lifestyle & Routine',
                      subtitle: '${_profile.formattedActivityLevel} • Meal times & sleep window',
                      icon: Icons.directions_run_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LifestyleScreen(memberId: widget.memberId, profile: _profile),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),

                    // Section 7: Health Data Permissions
                    _buildSectionTile(
                      step: '7',
                      title: 'Health Data Permissions',
                      subtitle: 'Manage dietitian & chef access permissions',
                      icon: Icons.lock_person_rounded,
                      color: AppColors.slate700,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HealthDataPermissionsScreen(memberId: widget.memberId),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTile({
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          '$step. $title',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
      ),
    );
  }
}
