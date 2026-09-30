import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/health_remote_datasource.dart';

enum HealthMetricCategory {
  activity,
  sleep,
  heart,
  body,
  nutrition,
  hydration,
  exercise,
  progress,
}

class HealthMetricDetailScreen extends StatefulWidget {
  final HealthMetricCategory category;

  HealthMetricDetailScreen({
    super.key,
    HealthMetricCategory? category,
    String? metricType,
  }) : category = category ?? _categoryFromType(metricType);

  static HealthMetricCategory _categoryFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'sleep':
        return HealthMetricCategory.sleep;
      case 'heart':
        return HealthMetricCategory.heart;
      case 'body':
      case 'weight':
        return HealthMetricCategory.body;
      case 'nutrition':
        return HealthMetricCategory.nutrition;
      case 'hydration':
      case 'water':
        return HealthMetricCategory.hydration;
      case 'exercise':
        return HealthMetricCategory.exercise;
      case 'progress':
        return HealthMetricCategory.progress;
      case 'activity':
      case 'steps':
      default:
        return HealthMetricCategory.activity;
    }
  }

  @override
  State<HealthMetricDetailScreen> createState() => _HealthMetricDetailScreenState();
}

class _HealthMetricDetailScreenState extends State<HealthMetricDetailScreen> {
  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? res;

    switch (widget.category) {
      case HealthMetricCategory.activity:
        res = await _dataSource.getActivityMetrics();
        break;
      case HealthMetricCategory.sleep:
        res = await _dataSource.getSleepMetrics();
        break;
      case HealthMetricCategory.heart:
        res = await _dataSource.getHeartMetrics();
        break;
      case HealthMetricCategory.body:
        res = await _dataSource.getBodyMetrics();
        break;
      case HealthMetricCategory.hydration:
        res = await _dataSource.getHydrationMetrics();
        break;
      case HealthMetricCategory.exercise:
        res = await _dataSource.getExerciseMetrics();
        break;
      case HealthMetricCategory.nutrition:
        res = await _dataSource.getNutritionMetrics();
        break;
      case HealthMetricCategory.progress:
        res = await _dataSource.getHealthOverview();
        break;
    }

    if (mounted) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  String get _title {
    switch (widget.category) {
      case HealthMetricCategory.activity:
        return 'Daily Activity';
      case HealthMetricCategory.sleep:
        return 'Sleep Architecture';
      case HealthMetricCategory.heart:
        return 'Heart & Pulse';
      case HealthMetricCategory.body:
        return 'Body Composition';
      case HealthMetricCategory.hydration:
        return 'Hydration Tracking';
      case HealthMetricCategory.exercise:
        return 'Exercise & Workouts';
      case HealthMetricCategory.nutrition:
        return 'Nutritional Intake';
      case HealthMetricCategory.progress:
        return 'Weekly Progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.slate900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildCategoryContent(),
              ),
            ),
    );
  }

  Widget _buildCategoryContent() {
    switch (widget.category) {
      case HealthMetricCategory.activity:
        return _buildActivityView();
      case HealthMetricCategory.sleep:
        return _buildSleepView();
      case HealthMetricCategory.heart:
        return _buildHeartView();
      case HealthMetricCategory.body:
        return _buildBodyView();
      case HealthMetricCategory.hydration:
        return _buildHydrationView();
      case HealthMetricCategory.exercise:
        return _buildExerciseView();
      case HealthMetricCategory.nutrition:
        return _buildNutritionView();
      case HealthMetricCategory.progress:
        return _buildProgressView();
    }
  }

  Widget _buildActivityView() {
    final steps = _data?['todaySteps'] ?? 0;
    final avgSteps = _data?['weeklyAverageSteps'] ?? 0;
    final distanceKm = _data?['todayDistanceKm'] ?? 0.0;
    final calories = _data?['todayActiveCalories'] ?? 0;
    final exercise = _data?['todayExerciseMinutes'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'TODAY STEPS',
          value: '$steps',
          subtitle: 'Goal: 10,000 steps',
          icon: Icons.directions_walk_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard('Weekly Average', '$avgSteps steps', Icons.trending_up_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard('Distance', '$distanceKm km', Icons.straighten_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard('Active Calories', '$calories kcal', Icons.local_fire_department_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard('Exercise Time', '$exercise min', Icons.timer_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepView() {
    final lastNightMin = _data?['lastNightMinutes'] ?? 0;
    final avgMin = _data?['weeklyAverageMinutes'] ?? 0;

    final hours = lastNightMin ~/ 60;
    final mins = lastNightMin % 60;

    final avgHours = avgMin ~/ 60;
    final avgMins = avgMin % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'LAST NIGHT SLEEP',
          value: '${hours}h ${mins}m',
          subtitle: 'Optimal recovery range: 7 - 9 hours',
          icon: Icons.bedtime_rounded,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 16),
        _buildMiniStatCard('7-Day Average', '${avgHours}h ${avgMins}m', Icons.show_chart_rounded),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Sleep Stage Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'Sleep stages (Deep, REM, Core, Light) are automatically imported from your authorized watch or connected sleep sensor.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeartView() {
    final resting = _data?['restingHeartRate'];
    final avg = _data?['averageHeartRate'];
    final readings = (_data?['recentReadings'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'RESTING HEART RATE',
          value: resting != null ? '$resting bpm' : 'Measuring...',
          subtitle: 'Normal healthy resting baseline: 60 - 80 bpm',
          icon: Icons.favorite_rounded,
          color: const Color(0xFFEF4444),
        ),
        const SizedBox(height: 16),
        if (avg != null) ...[
          _buildMiniStatCard('Daily Average Pulse', '$avg bpm', Icons.timeline_rounded),
          const SizedBox(height: 16),
        ],
        const Text(
          'RECENT READINGS FROM CONNECTED SOURCES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate500, letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        if (readings.isEmpty)
          const Text('No recent pulse readings captured.', style: TextStyle(color: AppColors.slate500))
        else
          ...readings.map(
            (r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Text('${r['bpm']} bpm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  Text(
                    '${r['provider'] ?? 'Source'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Widget _buildBodyView() {
    final weight = _parseDouble(_data?['currentWeightKg']);
    final rawBmi = _parseDouble(_data?['bmi']);
    final height = _parseDouble(_data?['heightCm']);

    double? bmi = rawBmi;
    if ((bmi == null || bmi <= 0) && weight != null && height != null && height > 0) {
      final hM = height / 100.0;
      bmi = double.parse((weight / (hM * hM)).toStringAsFixed(1));
    }

    String bmiCategory = 'Pending';
    Color bmiColor = const Color(0xFF0D9488);
    if (bmi != null && bmi > 0) {
      if (bmi < 18.5) {
        bmiCategory = 'Underweight';
        bmiColor = const Color(0xFF0284C7);
      } else if (bmi < 25.0) {
        bmiCategory = 'Normal';
        bmiColor = const Color(0xFF059669);
      } else if (bmi < 30.0) {
        bmiCategory = 'Overweight';
        bmiColor = const Color(0xFFD97706);
      } else {
        bmiCategory = 'Obese';
        bmiColor = const Color(0xFFDC2626);
      }
    }

    // Spectrum Progress: 4 distinct clinical zones
    double? meterProgress;
    if (bmi != null && bmi > 0) {
      if (bmi < 18.5) {
        meterProgress = ((bmi - 12.0) / (18.5 - 12.0) * 0.25).clamp(0.04, 0.23);
      } else if (bmi < 25.0) {
        meterProgress = 0.25 + ((bmi - 18.5) / (25.0 - 18.5) * 0.25).clamp(0.01, 0.23);
      } else if (bmi < 30.0) {
        meterProgress = 0.50 + ((bmi - 25.0) / (30.0 - 25.0) * 0.25).clamp(0.01, 0.23);
      } else {
        meterProgress = (0.75 + ((bmi - 30.0) / 10.0) * 0.25).clamp(0.77, 0.96);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'CURRENT BODY WEIGHT',
          value: weight != null ? '${weight.toStringAsFixed(1)} kg' : 'Syncing...',
          subtitle: bmi != null
              ? 'Body Mass Index: ${bmi.toStringAsFixed(1)} kg/m² ($bmiCategory)'
              : 'BMI automatically calculated',
          icon: Icons.monitor_weight_rounded,
          color: const Color(0xFF0D9488),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Height',
                height != null ? '${height.toInt()} cm' : 'Not set',
                Icons.height_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                'BMI Category',
                bmi != null ? '$bmiCategory (${bmi.toStringAsFixed(1)})' : 'Pending',
                Icons.health_and_safety_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // BMI Spectrum Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BMI CLINICAL SPECTRUM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.slate500,
                    ),
                  ),
                  if (bmi != null && bmi > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bmiColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${bmi.toStringAsFixed(1)} • $bmiCategory',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: bmiColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Bar + Pointer Stack
              SizedBox(
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 25,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF38BDF8),
                                    borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Expanded(
                                flex: 25,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (meterProgress != null)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: meterProgress,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 6,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.slate900,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Under (<18.5)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Normal (18.5-24.9)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Over (25-29.9)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Obese (≥30)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationView() {
    final todayMl = _data?['todayMl'] ?? 0;
    final percent = _data?['todayPercent'] ?? 0;
    final avgMl = _data?['weeklyAverageMl'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'TODAY HYDRATION',
          value: '${(todayMl / 1000).toStringAsFixed(1)} L',
          subtitle: '$percent% of daily 2.5 L target',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 16),
        _buildMiniStatCard('7-Day Daily Average', '${(avgMl / 1000).toStringAsFixed(1)} L', Icons.water_rounded),
      ],
    );
  }

  Widget _buildExerciseView() {
    final minutes = _data?['todayMinutes'] ?? 0;
    final avgMin = _data?['weeklyAverageMinutes'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'EXERCISE TIME',
          value: '$minutes min',
          subtitle: 'Daily target: 30 minutes active training',
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 16),
        _buildMiniStatCard('Weekly Average', '$avgMin min/day', Icons.speed_rounded),
      ],
    );
  }

  Widget _buildNutritionView() {
    final calories = _data?['todayCalories'] ?? 0;
    final protein = _data?['todayProteinGrams'] ?? 0;
    final carbs = _data?['todayCarbsGrams'] ?? 0;
    final fat = _data?['todayFatGrams'] ?? 0;
    final fiber = _data?['todayFiberGrams'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'NUTRITION INTAKE',
          value: '$calories kcal',
          subtitle: 'Verified by clinical meal assignments',
          icon: Icons.restaurant_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMiniStatCard('Protein', '$protein g', Icons.egg_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniStatCard('Carbs', '$carbs g', Icons.grain_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMiniStatCard('Healthy Fats', '$fat g', Icons.water_drop_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniStatCard('Fiber', '$fiber g', Icons.eco_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressView() {
    final week = _data?['week'] as Map<String, dynamic>?;
    final steps = week?['totalSteps'] ?? 0;
    final weightTrend = week?['weightTrendKg'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetricCard(
          title: 'WEEKLY HEALTH PROGRESS',
          value: '$steps steps',
          subtitle: 'Weight trend: ${weightTrend >= 0 ? '+' : ''}$weightTrend kg',
          icon: Icons.insights_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        _buildMiniStatCard('Dietitian Consultation', 'Synced with Clinical Diet Plan', Icons.medical_services_rounded),
      ],
    );
  }

  Widget _buildHeroMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.4,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600)),
              Icon(icon, size: 16, color: AppColors.slate400),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
          ),
        ],
      ),
    );
  }
}
