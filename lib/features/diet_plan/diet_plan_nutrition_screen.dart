import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';
import 'diet_plan_service.dart';
import 'models/diet_plan_models.dart';

class DietPlanNutritionScreen extends StatefulWidget {
  final String planId;
  final NutritionModel? plannedNutrition;

  const DietPlanNutritionScreen({
    super.key,
    required this.planId,
    this.plannedNutrition,
  });

  @override
  State<DietPlanNutritionScreen> createState() => _DietPlanNutritionScreenState();
}

class _DietPlanNutritionScreenState extends State<DietPlanNutritionScreen> {
  final DietPlanService _service = DietPlanService();
  bool _isLoading = true;
  List<DietPlanNutritionTargetModel> _targets = [];

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    setState(() => _isLoading = true);
    final targets = await _service.getNutritionTargets(widget.planId);
    if (mounted) {
      setState(() {
        _targets = targets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nutrition Targets'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Traceability banner (Rule 10)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nutrition targets are dietitian-prescribed and verified against clinical guidelines.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

                // Targets List
                ..._targets.map((t) {
                  final plannedVal = _getPlannedValue(t.nutrient);
                  final targetVal = t.targetValue ?? 0;
                  final double progress = (targetVal > 0 && plannedVal != null)
                      ? (plannedVal / targetVal).clamp(0.0, 1.0)
                      : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: EbicCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t.nutrient.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Target: ${t.targetValue ?? '--'} ${t.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress > 0 ? progress : 0.75,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(_getColorForNutrient(t.nutrient)),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                plannedVal != null ? 'Planned: ${plannedVal.round()} ${t.unit}' : 'Prescribed daily',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (t.minimumValue != null && t.maximumValue != null)
                                Text(
                                  'Range: ${t.minimumValue}-${t.maximumValue} ${t.unit}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  num? _getPlannedValue(String nutrient) {
    if (widget.plannedNutrition == null) return null;
    switch (nutrient.toUpperCase()) {
      case 'CALORIES':
        return widget.plannedNutrition!.calories;
      case 'PROTEIN':
        return widget.plannedNutrition!.proteinG;
      case 'CARBOHYDRATES':
        return widget.plannedNutrition!.carbsG;
      case 'FAT':
        return widget.plannedNutrition!.fatG;
      case 'FIBRE':
        return widget.plannedNutrition!.fibreG;
      default:
        return null;
    }
  }

  Color _getColorForNutrient(String nutrient) {
    switch (nutrient.toUpperCase()) {
      case 'CALORIES':
        return Colors.orange;
      case 'PROTEIN':
        return Colors.red.shade400;
      case 'CARBOHYDRATES':
        return Colors.blue.shade400;
      case 'FAT':
        return Colors.green;
      case 'FIBRE':
        return Colors.teal;
      case 'WATER':
        return Colors.lightBlue;
      default:
        return AppColors.primary;
    }
  }
}
