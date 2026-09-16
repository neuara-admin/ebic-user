import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_profile_model.dart';

class DietaryPreferencesScreen extends StatefulWidget {
  final String memberId;
  final HealthProfileModel profile;

  const DietaryPreferencesScreen({
    super.key,
    required this.memberId,
    required this.profile,
  });

  @override
  State<DietaryPreferencesScreen> createState() => _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  List<dynamic> _masterTags = [];
  final Set<String> _selectedTagIds = {};
  late TextEditingController _dislikesController;
  late TextEditingController _cuisinesController;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final r in widget.profile.dietaryRestrictions) {
      _selectedTagIds.add(r.dietaryTagId);
    }
    final lifestyle = widget.profile.lifestyle;
    _dislikesController = TextEditingController(text: lifestyle['foodDislikes']?.toString() ?? '');
    _cuisinesController = TextEditingController(text: lifestyle['cuisinePreferences']?.toString() ?? '');
    _loadMaster();
  }

  @override
  void dispose() {
    _dislikesController.dispose();
    _cuisinesController.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    try {
      final res = await _dataSource.getDietaryPreferencesMaster();
      if (mounted) {
        setState(() {
          _masterTags = res['dietaryTags'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final existingLifestyle = Map<String, dynamic>.from(widget.profile.lifestyle);
      existingLifestyle['foodDislikes'] = _dislikesController.text.trim();
      existingLifestyle['cuisinePreferences'] = _cuisinesController.text.trim();

      await _dataSource.updateProfile({
        'memberId': widget.memberId,
        'dietaryRestrictionTagIds': _selectedTagIds.toList(),
        'lifestyle': existingLifestyle,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dietary preferences saved successfully.'),
            backgroundColor: AppColors.emerald600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Dietary Preferences'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _savePreferences,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dietary Tags & Regimens',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select any dietary requirements that EBIC meals must satisfy.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _masterTags.map((tag) {
                      final tagId = tag['id'].toString();
                      final isSelected = _selectedTagIds.contains(tagId);
                      return FilterChip(
                        label: Text(tag['name'].toString()),
                        selected: isSelected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedTagIds.add(tagId);
                            } else {
                              _selectedTagIds.remove(tagId);
                            }
                          });
                        },
                        selectedColor: AppColors.primarySubtle,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.slate200,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Food Dislikes / Ingredients to Avoid',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Non-allergic ingredients you dislike (e.g. bitter gourd, bell peppers, excessive cilantro).',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dislikesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mushrooms, bitter gourd, raw onion',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slate200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Preferred Cuisines & Flavor Profiles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cuisines you enjoy the most for your regular meal rotation.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cuisinesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. North Indian, Mediterranean, South Indian, Asian bowls',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slate200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
