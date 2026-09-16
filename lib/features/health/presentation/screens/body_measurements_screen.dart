import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/models/health_profile_model.dart';
import '../widgets/bmi_meter_widget.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  final String memberId;
  final HealthProfileModel profile;

  const BodyMeasurementsScreen({
    super.key,
    required this.memberId,
    required this.profile,
  });

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  bool _isSaving = false;
  late HealthProfileModel _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _heightController = TextEditingController(
      text: _currentProfile.heightCm != null ? _currentProfile.heightCm!.toStringAsFixed(0) : '',
    );
    _weightController = TextEditingController(
      text: _currentProfile.currentWeightKg != null
          ? _currentProfile.currentWeightKg!.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveMeasurements() async {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height == null || height <= 0 || weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid positive height and weight values.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await _dataSource.updateProfile({
        'memberId': widget.memberId,
        'heightCm': height,
        'currentWeightKg': weight,
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          if (updated != null) _currentProfile = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurements updated successfully. BMI recalculated.'),
            backgroundColor: AppColors.emerald600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Body Measurements'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend-calculated BMI Meter
            BmiMeterWidget(
              bmi: _currentProfile.bmi,
              heightCm: _currentProfile.heightCm,
              weightKg: _currentProfile.currentWeightKg,
            ),
            const SizedBox(height: 24),

            // Form Inputs
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Vitals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Saving new weight records a new measurement entry for progress tracking without overwriting historical consultation records.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Height Field
                  TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                      prefixIcon: const Icon(Icons.height_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.slate50,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weight Field
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Current Weight',
                      suffixText: 'kg',
                      prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.slate50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveMeasurements,
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
                          : const Text(
                              'Save Measurements & Recalculate BMI',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
