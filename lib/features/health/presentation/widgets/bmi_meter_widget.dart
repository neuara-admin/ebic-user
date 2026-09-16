import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'provenance_badge.dart';

class BmiMeterWidget extends StatelessWidget {
  final double? bmi;
  final double? heightCm;
  final double? weightKg;

  const BmiMeterWidget({
    super.key,
    required this.bmi,
    this.heightCm,
    this.weightKg,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = bmi != null && bmi! > 0;
    final bmiValue = bmi ?? 0.0;

    Color categoryColor;
    String categoryText;
    double meterProgress; // 0.0 to 1.0 (range 15 to 35)

    if (!hasData) {
      categoryColor = AppColors.slate400;
      categoryText = 'Height & Weight Required';
      meterProgress = 0.0;
    } else if (bmiValue < 18.5) {
      categoryColor = const Color(0xFF0284C7); // Sky 600
      categoryText = 'Underweight';
      meterProgress = ((bmiValue - 15) / 20).clamp(0.05, 0.25);
    } else if (bmiValue < 25.0) {
      categoryColor = AppColors.emerald600;
      categoryText = 'Normal weight';
      meterProgress = 0.25 + ((bmiValue - 18.5) / 6.5) * 0.25;
    } else if (bmiValue < 30.0) {
      categoryColor = AppColors.amber500;
      categoryText = 'Overweight';
      meterProgress = 0.50 + ((bmiValue - 25.0) / 5.0) * 0.25;
    } else {
      categoryColor = AppColors.danger;
      categoryText = 'Obese';
      meterProgress = (0.75 + ((bmiValue - 30.0) / 10.0) * 0.25).clamp(0.75, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.speed_rounded, color: categoryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body Mass Index (BMI)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'Derived from height & weight',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const ProvenanceBadge(source: 'DERIVED', isCompact: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hasData ? bmiValue.toStringAsFixed(1) : '--',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: hasData ? AppColors.slate950 : AppColors.slate400,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'kg/m²',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate400,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  categoryText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Multi-segmented colored progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 25, child: Container(color: const Color(0xFFBAE6FD))), // Underweight
                      Expanded(flex: 25, child: Container(color: const Color(0xFFA7F3D0))), // Normal
                      Expanded(flex: 25, child: Container(color: const Color(0xFFFDE68A))), // Overweight
                      Expanded(flex: 25, child: Container(color: const Color(0xFFFECDD3))), // Obese
                    ],
                  ),
                  if (hasData)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: meterProgress,
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: categoryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('<18.5', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
              Text('18.5 - 24.9', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
              Text('25 - 29.9', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
              Text('≥30', style: TextStyle(fontSize: 10, color: AppColors.slate400)),
            ],
          ),
          if (heightCm != null || weightKg != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 10),
            Row(
              children: [
                if (heightCm != null)
                  Expanded(
                    child: Text(
                      'Height: ${heightCm!.toStringAsFixed(0)} cm',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700),
                    ),
                  ),
                if (weightKg != null)
                  Expanded(
                    child: Text(
                      'Weight: ${weightKg!.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
