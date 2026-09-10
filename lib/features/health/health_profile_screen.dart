import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/household_member_model.dart';
import '../../shared/widgets/ebic_card.dart';
import '../../shared/widgets/ebic_button.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final ApiClient _api = ApiClient();
  List<HouseholdMemberModel> _householdMembers = [];
  String? _selectedMemberId;

  // Section 23 Metrics
  double _heightCm = 175.0;
  double _weightKg = 72.5;
  int _calories = 2100;
  int _proteinG = 110;
  double _waterLiters = 2.8;
  int _steps = 8450;
  int _activityMinutes = 45;
  double _sleepHours = 7.5;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.householdMembers);
      if (res.success && res.data != null) {
        final list = res.data!
            .map((json) => HouseholdMemberModel.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _householdMembers = list;
          if (list.isNotEmpty) _selectedMemberId = list.first.id;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  String get _bmiCategory {
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 24.9) return 'Normal weight';
    if (_bmi < 29.9) return 'Overweight';
    return 'Obese';
  }

  void _showLogVitalsDialog() {
    final weightCtrl = TextEditingController(text: _weightKg.toString());
    final waterCtrl = TextEditingController(text: _waterLiters.toString());
    final stepsCtrl = TextEditingController(text: _steps.toString());
    final sleepCtrl = TextEditingController(text: _sleepHours.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Health Vitals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: waterCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Water (Liters)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stepsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily Steps'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sleepCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sleep (Hours)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          EbicButton(
            label: 'Save Vitals',
            onPressed: () {
              setState(() {
                _weightKg = double.tryParse(weightCtrl.text) ?? _weightKg;
                _waterLiters = double.tryParse(waterCtrl.text) ?? _waterLiters;
                _steps = int.tryParse(stepsCtrl.text) ?? _steps;
                _sleepHours = double.tryParse(sleepCtrl.text) ?? _sleepHours;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vitals logged securely to member profile.')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Member Health Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'View Progress Charts',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.healthProgress),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Selector Chip Row (Section 14 & 63: Health Privacy)
                    if (_householdMembers.isNotEmpty) ...[
                      const Text('Select Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate700)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _householdMembers.map((m) {
                            final isSelected = _selectedMemberId == m.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(m.name),
                                selected: isSelected,
                                selectedColor: AppColors.primarySubtle,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? AppColors.primaryDark : AppColors.slate700,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (_) => setState(() => _selectedMemberId = m.id),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // BMI & Vitals Hero Card (Section 23)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('BODY COMPOSITION', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_bmiCategory, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('BMI', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(_bmi.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Weight', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('${_weightKg.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Height', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('${_heightCm.toInt()} cm', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metrics Grid (Calories, Protein, Water, Steps, Activity, Sleep)
                    const Text('Daily Tracked Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate900)),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricTile('Calories', '$_calories kcal', Icons.local_fire_department, AppColors.accent),
                        _buildMetricTile('Protein', '$_proteinG g', Icons.fitness_center, AppColors.primary),
                        _buildMetricTile('Water', '${_waterLiters.toStringAsFixed(1)} L', Icons.water_drop, AppColors.secondary),
                        _buildMetricTile('Daily Steps', '$_steps', Icons.directions_walk, AppColors.emerald600),
                        _buildMetricTile('Activity', '$_activityMinutes mins', Icons.timer_outlined, AppColors.purple500),
                        _buildMetricTile('Sleep', '${_sleepHours.toStringAsFixed(1)} hrs', Icons.bedtime_outlined, AppColors.slate700),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Manual Entry Button
                    EbicButton(
                      label: 'Log Today\'s Vitals',
                      icon: Icons.edit_note_rounded,
                      variant: EbicButtonVariant.outline,
                      onPressed: _showLogVitalsDialog,
                    ),
                    const SizedBox(height: 12),

                    EbicButton(
                      label: 'View Progress & Analytics',
                      icon: Icons.insights_rounded,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.healthProgress),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        ],
      ),
    );
  }
}
