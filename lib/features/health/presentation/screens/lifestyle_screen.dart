import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_profile_model.dart';

class LifestyleScreen extends StatefulWidget {
  final String memberId;
  final HealthProfileModel profile;

  const LifestyleScreen({
    super.key,
    required this.memberId,
    required this.profile,
  });

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  late String _activityLevel;
  late TextEditingController _workPatternCtrl;
  late TextEditingController _sleepCtrl;
  late TextEditingController _wakeCtrl;
  late TextEditingController _breakfastCtrl;
  late TextEditingController _lunchCtrl;
  late TextEditingController _dinnerCtrl;
  late TextEditingController _hydrationCtrl;
  bool _isSaving = false;

  final List<Map<String, String>> _activityOptions = [
    {'key': 'SEDENTARY', 'title': 'Sedentary', 'desc': 'Desk job, little to no regular exercise'},
    {'key': 'LIGHT', 'title': 'Lightly Active', 'desc': 'Light exercise/sports 1-3 days/week'},
    {'key': 'MODERATE', 'title': 'Moderately Active', 'desc': 'Moderate exercise/sports 3-5 days/week'},
    {'key': 'HIGH', 'title': 'Very Active', 'desc': 'Hard exercise/sports 6-7 days a week'},
    {'key': 'VERY_HIGH', 'title': 'Extremely Active', 'desc': 'Athletic training or physical labor job'},
  ];

  @override
  void initState() {
    super.initState();
    _activityLevel = widget.profile.activityLevel;
    if (_activityLevel == 'UNKNOWN' || _activityLevel.isEmpty) {
      _activityLevel = 'MODERATE';
    }
    final ls = widget.profile.lifestyle;
    _workPatternCtrl = TextEditingController(text: ls['workPattern']?.toString() ?? '');
    _sleepCtrl = TextEditingController(text: ls['typicalSleep']?.toString() ?? '11:00 PM');
    _wakeCtrl = TextEditingController(text: ls['typicalWake']?.toString() ?? '07:00 AM');
    _breakfastCtrl = TextEditingController(text: ls['typicalBreakfast']?.toString() ?? '08:30 AM');
    _lunchCtrl = TextEditingController(text: ls['typicalLunch']?.toString() ?? '01:30 PM');
    _dinnerCtrl = TextEditingController(text: ls['typicalDinner']?.toString() ?? '08:30 PM');
    _hydrationCtrl = TextEditingController(
      text: ls['hydrationTargetLiters']?.toString() ?? '2.5',
    );
  }

  @override
  void dispose() {
    _workPatternCtrl.dispose();
    _sleepCtrl.dispose();
    _wakeCtrl.dispose();
    _breakfastCtrl.dispose();
    _lunchCtrl.dispose();
    _dinnerCtrl.dispose();
    _hydrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLifestyle() async {
    setState(() => _isSaving = true);
    try {
      final existingLifestyle = Map<String, dynamic>.from(widget.profile.lifestyle);
      existingLifestyle['workPattern'] = _workPatternCtrl.text.trim();
      existingLifestyle['typicalSleep'] = _sleepCtrl.text.trim();
      existingLifestyle['typicalWake'] = _wakeCtrl.text.trim();
      existingLifestyle['typicalBreakfast'] = _breakfastCtrl.text.trim();
      existingLifestyle['typicalLunch'] = _lunchCtrl.text.trim();
      existingLifestyle['typicalDinner'] = _dinnerCtrl.text.trim();
      existingLifestyle['hydrationTargetLiters'] = double.tryParse(_hydrationCtrl.text.trim()) ?? 2.5;

      await _dataSource.updateProfile({
        'memberId': widget.memberId,
        'activityLevel': _activityLevel,
        'lifestyle': existingLifestyle,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lifestyle & timing saved successfully.'),
            backgroundColor: AppColors.emerald600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Lifestyle & Routine'),
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
            onPressed: _isSaving ? null : _saveLifestyle,
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
                : const Text('Save Lifestyle Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Used to calculate daily basal metabolic rate (BMR) and recommended calories.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const SizedBox(height: 12),

            ..._activityOptions.map((opt) {
              final isSelected = _activityLevel == opt['key'];
              return GestureDetector(
                onTap: () => setState(() => _activityLevel = opt['key']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySubtle : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.slate200,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppColors.primary : AppColors.slate400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['title']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryDark : AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt['desc']!,
                              style: TextStyle(fontSize: 11, color: AppColors.slate600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            const Text(
              'Typical Meal Timings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ensures diet-plan delivery and chef cooking arrival times are precisely aligned.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _breakfastCtrl,
                    decoration: InputDecoration(
                      labelText: 'Breakfast',
                      prefixIcon: const Icon(Icons.wb_sunny_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lunchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lunch',
                      prefixIcon: const Icon(Icons.wb_twilight_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dinnerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dinner',
                      prefixIcon: const Icon(Icons.nightlight_round_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hydrationCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Hydration Target',
                      suffixText: 'L',
                      prefixIcon: const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.secondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Sleep Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Rest duration helps determine late-evening digestion and intermittent fasting windows.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sleepCtrl,
                    decoration: InputDecoration(
                      labelText: 'Typical Sleep',
                      prefixIcon: const Icon(Icons.bedtime_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _wakeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Typical Wake',
                      prefixIcon: const Icon(Icons.alarm, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
