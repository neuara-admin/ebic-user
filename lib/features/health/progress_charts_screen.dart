import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/ebic_card.dart';

class ProgressChartsScreen extends StatefulWidget {
  const ProgressChartsScreen({super.key});

  @override
  State<ProgressChartsScreen> createState() => _ProgressChartsScreenState();
}

class _ProgressChartsScreenState extends State<ProgressChartsScreen> {
  String _selectedRange = '30 Days'; // 7 Days, 30 Days, 3 Months

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Health Progress'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Range Filter Toggle: [ 7 Days ] [ 30 Days ] [ 3 Months ] (Section 25)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['7 Days', '30 Days', '3 Months'].map((range) {
                    final isSelected = _selectedRange == range;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedRange = range),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              range,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primaryDark : AppColors.slate600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Weight & BMI Trend Card
              _buildProgressCard(
                title: 'Body Weight Trend',
                currentValue: '72.5 kg',
                changeText: '↓ 1.8 kg (Last $_selectedRange)',
                isPositive: true,
                bars: [74.3, 73.9, 73.5, 73.1, 72.8, 72.5],
                labels: ['W1', 'W2', 'W3', 'W4', 'W5', 'Now'],
                barColor: AppColors.primary,
              ),
              const SizedBox(height: 16),

              // Steps & Activity Trend Card
              _buildProgressCard(
                title: 'Daily Steps Average',
                currentValue: '8,450 steps/day',
                changeText: '↑ 12% adherence to clinical goal',
                isPositive: true,
                bars: [6200, 7100, 8400, 9100, 7800, 8450],
                labels: ['M', 'T', 'W', 'T', 'F', 'S'],
                barColor: AppColors.emerald500,
              ),
              const SizedBox(height: 16),

              // Hydration / Water
              _buildProgressCard(
                title: 'Daily Water Intake',
                currentValue: '2.8 Liters',
                changeText: '93% of prescribed target met',
                isPositive: true,
                bars: [2.2, 2.5, 3.0, 2.7, 2.9, 2.8],
                labels: ['M', 'T', 'W', 'T', 'F', 'S'],
                barColor: AppColors.secondary,
              ),
              const SizedBox(height: 16),

              // Sleep Duration
              _buildProgressCard(
                title: 'Restorative Sleep',
                currentValue: '7.4 hrs/night',
                changeText: 'Consistent deep REM cycles',
                isPositive: true,
                bars: [6.5, 7.0, 7.8, 6.9, 7.5, 7.4],
                labels: ['M', 'T', 'W', 'T', 'F', 'S'],
                barColor: AppColors.purple500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String currentValue,
    required String changeText,
    required bool isPositive,
    required List<double> bars,
    required List<String> labels,
    required Color barColor,
  }) {
    final maxVal = bars.reduce((a, b) => a > b ? a : b);

    return EbicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
              Text(currentValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            changeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPositive ? AppColors.primaryDark : AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),

          // Mini bar chart representation
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (idx) {
                final barRatio = (bars[idx] / maxVal).clamp(0.15, 1.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: 60 * barRatio,
                      decoration: BoxDecoration(
                        color: idx == bars.length - 1 ? barColor : barColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[idx], style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
