import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum BmiCategory {
  underweight('Underweight', Color(0xFF2563EB), Color(0xFFDBEAFE), 'Below healthy weight. Nutrient-dense meals and strength training recommended.'),
  normal('Normal weight', Color(0xFF059669), Color(0xFFD1FAE5), 'Healthy weight range. Maintain balanced nutrition and daily activity.'),
  overweight('Overweight', Color(0xFFD97706), Color(0xFFFEF3C7), 'Above optimal range. Focus on portion control, fiber-rich meals, and cardio.'),
  obese('Obese', Color(0xFFDC2626), Color(0xFFFEE2E2), 'Higher health risk range. Personalized clinical diet plan and physician guidance recommended.');

  final String label;
  final Color color;
  final Color bgColor;
  final String recommendation;

  const BmiCategory(this.label, this.color, this.bgColor, this.recommendation);
}

/// Reusable BMI calculator and visual health gauge widget.
/// Supports both full card mode with visual segmented bar gauge and compact badge mode.
class BmiHealthWidget extends StatelessWidget {
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final bool compact;
  final bool showRecommendation;

  const BmiHealthWidget({
    super.key,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.compact = false,
    this.showRecommendation = true,
  });

  /// Factory for a compact pill/badge representation (ideal for member list cards).
  const factory BmiHealthWidget.badge({
    Key? key,
    double? heightCm,
    double? weightKg,
    double? bmi,
  }) = _BmiHealthBadgeWidget;

  /// Convert cm to feet and inches: (feet, inches)
  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return (feet: feet, inches: inches);
  }

  /// Convert feet and inches to cm
  static double feetInchesToCm(int feet, int inches) {
    final totalInches = (feet * 12) + inches;
    final cm = totalInches * 2.54;
    return double.parse(cm.toStringAsFixed(1));
  }

  /// Format height showing both feet/inches and cm (e.g., "5'9\" (175 cm)")
  static String formatHeight(double? heightCm) {
    if (heightCm == null || heightCm <= 0) return 'Not set';
    final ftIn = cmToFeetInches(heightCm);
    return "${ftIn.feet}'${ftIn.inches}\" (${heightCm.round()} cm)";
  }

  /// Convert kg to lbs
  static double kgToLbs(double kg) {
    return double.parse((kg * 2.20462).toStringAsFixed(1));
  }

  /// Convert lbs to kg
  static double lbsToKg(double lbs) {
    return double.parse((lbs / 2.20462).toStringAsFixed(1));
  }

  /// Format weight showing both kg and lbs (e.g. "68.5 kg (151 lbs)")
  static String formatWeight(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return 'Not set';
    final lbs = kgToLbs(weightKg).round();
    return "${weightKg.toStringAsFixed(1)} kg ($lbs lbs)";
  }

  /// Calculate BMI from height (cm) and weight (kg).
  static double? calculateBmi(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 40 || weightKg <= 10) {
      return null;
    }
    final heightM = heightCm / 100.0;
    final val = weightKg / (heightM * heightM);
    return double.parse(val.toStringAsFixed(1));
  }

  /// Get BMI Category from BMI score.
  static BmiCategory? getCategory(double? bmi) {
    if (bmi == null || bmi <= 0) return null;
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25.0) return BmiCategory.normal;
    if (bmi < 30.0) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  /// Get color corresponding to BMI.
  static Color getColor(double? bmi) {
    final cat = getCategory(bmi);
    return cat?.color ?? AppColors.slate500;
  }

  double? get effectiveBmi {
    if (bmi != null) return bmi;
    return calculateBmi(heightCm, weightKg);
  }

  @override
  Widget build(BuildContext context) {
    final val = effectiveBmi;
    if (val == null) {
      return const SizedBox.shrink();
    }

    final category = getCategory(val) ?? BmiCategory.normal;

    if (compact) {
      return _buildCompactBadge(val, category);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: category.color.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Value and Category Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.monitor_weight_outlined, size: 16, color: category.color),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BODY MASS INDEX',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                val.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: category.color,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'kg/m²',
                                style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: category.color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category == BmiCategory.normal ? Icons.check_circle : Icons.info_outline,
                      color: Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Segmented Bar Gauge
          _buildSegmentedGauge(val),

          const SizedBox(height: 8),

          // Scale Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('< 18.5', style: TextStyle(fontSize: 9, color: AppColors.slate500)),
              Text('18.5–24.9', style: TextStyle(fontSize: 9, color: AppColors.slate500, fontWeight: FontWeight.w600)),
              Text('25–29.9', style: TextStyle(fontSize: 9, color: AppColors.slate500)),
              Text('30+', style: TextStyle(fontSize: 9, color: AppColors.slate500)),
            ],
          ),

          if (showRecommendation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: category.color.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: category.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.recommendation,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedGauge(double bmiValue) {
    // Relative position on a scale from 15 to 35
    final clamped = bmiValue.clamp(15.0, 35.0);
    final percent = (clamped - 15.0) / 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final needleLeft = (totalWidth * percent - 6).clamp(0.0, totalWidth - 12);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Segmented Gradient Bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  // Underweight segment (15 to 18.5 -> 3.5 / 20 = 17.5%)
                  Expanded(
                    flex: 175,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Normal segment (18.5 to 25 -> 6.5 / 20 = 32.5%)
                  Expanded(
                    flex: 325,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 2),
                  // Overweight segment (25 to 30 -> 5.0 / 20 = 25.0%)
                  Expanded(
                    flex: 250,
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 2),
                  // Obese segment (30 to 35 -> 5.0 / 20 = 25.0%)
                  Expanded(
                    flex: 250,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Needle Indicator
            Positioned(
              left: needleLeft,
              top: -4,
              child: Container(
                width: 12,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.arrow_drop_down, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactBadge(double val, BmiCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: category.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'BMI ${val.toStringAsFixed(1)} • ${category.label}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiHealthBadgeWidget extends BmiHealthWidget {
  const _BmiHealthBadgeWidget({
    super.key,
    super.heightCm,
    super.weightKg,
    super.bmi,
  }) : super(compact: true, showRecommendation: false);
}
