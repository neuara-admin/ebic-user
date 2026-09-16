class WeightTrendPointEntity {
  final String date;
  final double value;
  final String? source;

  const WeightTrendPointEntity({
    required this.date,
    required this.value,
    this.source,
  });

  factory WeightTrendPointEntity.fromJson(Map<String, dynamic> json) {
    return WeightTrendPointEntity(
      date: json['date']?.toString() ?? '',
      value: (json['value'] is num) ? (json['value'] as num).toDouble() : 0.0,
      source: json['source']?.toString(),
    );
  }
}

class WeightProgressEntity {
  final bool hasData;
  final bool hasSufficientDataForTrend;
  final String unit;
  final double? currentValue;
  final double? previousValue;
  final double periodChange;
  final String trendDirection; // INCREASING, DECREASING, STABLE
  final double? bmi;
  final double? min;
  final double? max;
  final double? average;
  final List<WeightTrendPointEntity> points;

  const WeightProgressEntity({
    required this.hasData,
    required this.hasSufficientDataForTrend,
    this.unit = 'kg',
    this.currentValue,
    this.previousValue,
    this.periodChange = 0.0,
    this.trendDirection = 'STABLE',
    this.bmi,
    this.min,
    this.max,
    this.average,
    this.points = const [],
  });

  factory WeightProgressEntity.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return WeightProgressEntity(
      hasData: json['hasData'] == true,
      hasSufficientDataForTrend: json['hasSufficientDataForTrend'] == true,
      unit: json['unit']?.toString() ?? 'kg',
      currentValue: (json['currentValue'] is num) ? (json['currentValue'] as num).toDouble() : null,
      previousValue: (json['previousValue'] is num) ? (json['previousValue'] as num).toDouble() : null,
      periodChange: (json['periodChange'] is num) ? (json['periodChange'] as num).toDouble() : 0.0,
      trendDirection: json['trendDirection']?.toString() ?? 'STABLE',
      bmi: (json['bmi'] is num) ? (json['bmi'] as num).toDouble() : null,
      min: (json['min'] is num) ? (json['min'] as num).toDouble() : null,
      max: (json['max'] is num) ? (json['max'] as num).toDouble() : null,
      average: (json['average'] is num) ? (json['average'] as num).toDouble() : null,
      points: rawPoints.whereType<Map<String, dynamic>>().map(WeightTrendPointEntity.fromJson).toList(),
    );
  }
}

class GoalProgressItemEntity {
  final String id;
  final String goalType;
  final String title;
  final String? description;
  final String direction; // INCREASE, DECREASE, MAINTAIN, RANGE
  final double? currentValue;
  final double? targetValue;
  final String unit;
  final int progressPercentage;
  final String status;

  const GoalProgressItemEntity({
    required this.id,
    required this.goalType,
    required this.title,
    this.description,
    required this.direction,
    this.currentValue,
    this.targetValue,
    required this.unit,
    required this.progressPercentage,
    required this.status,
  });

  factory GoalProgressItemEntity.fromJson(Map<String, dynamic> json) {
    return GoalProgressItemEntity(
      id: json['id']?.toString() ?? '',
      goalType: json['goalType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      direction: json['direction']?.toString() ?? 'INCREASE',
      currentValue: (json['currentValue'] is num) ? (json['currentValue'] as num).toDouble() : null,
      targetValue: (json['targetValue'] is num) ? (json['targetValue'] as num).toDouble() : null,
      unit: json['unit']?.toString() ?? '',
      progressPercentage: (json['progressPercentage'] is num) ? (json['progressPercentage'] as num).toInt() : 0,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class HydrationProgressEntity {
  final bool hasData;
  final double todayLitres;
  final double targetLitres;
  final int percentage;
  final double averageDaily;
  final String unit;

  const HydrationProgressEntity({
    required this.hasData,
    this.todayLitres = 0.0,
    this.targetLitres = 2.5,
    this.percentage = 0,
    this.averageDaily = 0.0,
    this.unit = 'L',
  });

  factory HydrationProgressEntity.fromJson(Map<String, dynamic> json) {
    return HydrationProgressEntity(
      hasData: json['hasData'] == true,
      todayLitres: (json['todayLitres'] is num) ? (json['todayLitres'] as num).toDouble() : 0.0,
      targetLitres: (json['targetLitres'] is num) ? (json['targetLitres'] as num).toDouble() : 2.5,
      percentage: (json['percentage'] is num) ? (json['percentage'] as num).toInt() : 0,
      averageDaily: (json['averageDaily'] is num) ? (json['averageDaily'] as num).toDouble() : 0.0,
      unit: json['unit']?.toString() ?? 'L',
    );
  }
}

class ActivityProgressEntity {
  final bool hasData;
  final int? todaySteps;
  final int? dailyAverage;
  final int targetSteps;
  final String? source;

  const ActivityProgressEntity({
    required this.hasData,
    this.todaySteps,
    this.dailyAverage,
    this.targetSteps = 10000,
    this.source,
  });

  factory ActivityProgressEntity.fromJson(Map<String, dynamic> json) {
    return ActivityProgressEntity(
      hasData: json['hasData'] == true,
      todaySteps: (json['todaySteps'] is num) ? (json['todaySteps'] as num).toInt() : null,
      dailyAverage: (json['dailyAverage'] is num) ? (json['dailyAverage'] as num).toInt() : null,
      targetSteps: (json['targetSteps'] is num) ? (json['targetSteps'] as num).toInt() : 10000,
      source: json['source']?.toString(),
    );
  }
}

class SleepProgressEntity {
  final bool hasData;
  final double? lastNightHours;
  final double? averageHours;
  final String? source;

  const SleepProgressEntity({
    required this.hasData,
    this.lastNightHours,
    this.averageHours,
    this.source,
  });

  factory SleepProgressEntity.fromJson(Map<String, dynamic> json) {
    return SleepProgressEntity(
      hasData: json['hasData'] == true,
      lastNightHours: (json['lastNightHours'] is num) ? (json['lastNightHours'] as num).toDouble() : null,
      averageHours: (json['averageHours'] is num) ? (json['averageHours'] as num).toDouble() : null,
      source: json['source']?.toString(),
    );
  }
}

class MealAdherenceEntity {
  final int plannedMeals;
  final int confirmedMeals;
  final int skippedMeals;
  final int adherenceRatePercentage;

  const MealAdherenceEntity({
    this.plannedMeals = 0,
    this.confirmedMeals = 0,
    this.skippedMeals = 0,
    this.adherenceRatePercentage = 0,
  });

  factory MealAdherenceEntity.fromJson(Map<String, dynamic> json) {
    return MealAdherenceEntity(
      plannedMeals: (json['plannedMeals'] is num) ? (json['plannedMeals'] as num).toInt() : 0,
      confirmedMeals: (json['confirmedMeals'] is num) ? (json['confirmedMeals'] as num).toInt() : 0,
      skippedMeals: (json['skippedMeals'] is num) ? (json['skippedMeals'] as num).toInt() : 0,
      adherenceRatePercentage: (json['adherenceRatePercentage'] is num)
          ? (json['adherenceRatePercentage'] as num).toInt()
          : 0,
    );
  }
}

class HealthInsightEntity {
  final String type;
  final String title;
  final String description;
  final String category;

  const HealthInsightEntity({
    required this.type,
    required this.title,
    required this.description,
    required this.category,
  });

  factory HealthInsightEntity.fromJson(Map<String, dynamic> json) {
    return HealthInsightEntity(
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'SYSTEM',
    );
  }
}

class HealthProgressDashboardEntity {
  final String memberId;
  final String memberName;
  final String periodKey;
  final int periodDays;
  final WeightProgressEntity weight;
  final HydrationProgressEntity hydration;
  final ActivityProgressEntity activity;
  final SleepProgressEntity sleep;
  final List<GoalProgressItemEntity> goals;
  final MealAdherenceEntity adherence;
  final List<HealthInsightEntity> insights;

  const HealthProgressDashboardEntity({
    required this.memberId,
    required this.memberName,
    required this.periodKey,
    required this.periodDays,
    required this.weight,
    required this.hydration,
    required this.activity,
    required this.sleep,
    required this.goals,
    required this.adherence,
    required this.insights,
  });

  factory HealthProgressDashboardEntity.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>? ?? {};
    final rawGoals = json['goals'] as List<dynamic>? ?? [];
    final rawInsights = json['insights'] as List<dynamic>? ?? [];
    final period = json['period'] as Map<String, dynamic>? ?? {};

    return HealthProgressDashboardEntity(
      memberId: json['memberId']?.toString() ?? '',
      memberName: json['memberName']?.toString() ?? 'Member',
      periodKey: period['key']?.toString() ?? '30D',
      periodDays: (period['days'] is num) ? (period['days'] as num).toInt() : 30,
      weight: WeightProgressEntity.fromJson(metrics['weight'] as Map<String, dynamic>? ?? {}),
      hydration: HydrationProgressEntity.fromJson(metrics['hydration'] as Map<String, dynamic>? ?? {}),
      activity: ActivityProgressEntity.fromJson(metrics['activity'] as Map<String, dynamic>? ?? {}),
      sleep: SleepProgressEntity.fromJson(metrics['sleep'] as Map<String, dynamic>? ?? {}),
      goals: rawGoals.whereType<Map<String, dynamic>>().map(GoalProgressItemEntity.fromJson).toList(),
      adherence: MealAdherenceEntity.fromJson(json['adherence'] as Map<String, dynamic>? ?? {}),
      insights: rawInsights.whereType<Map<String, dynamic>>().map(HealthInsightEntity.fromJson).toList(),
    );
  }
}

class TimelineItemEntity {
  final String id;
  final String eventType;
  final String title;
  final String description;
  final DateTime timestamp;
  final String icon;

  const TimelineItemEntity({
    required this.id,
    required this.eventType,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
  });

  factory TimelineItemEntity.fromJson(Map<String, dynamic> json) {
    return TimelineItemEntity(
      id: json['id']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      icon: json['icon']?.toString() ?? 'scale',
    );
  }
}
