import '../entities/health_progress_entity.dart';

abstract class HealthProgressRepository {
  Future<HealthProgressDashboardEntity> getDashboard(String memberId, {String? period, String? startDate, String? endDate});

  Future<WeightProgressEntity> getMetricTrend(String memberId, String metricType, {String? period});

  Future<List<TimelineItemEntity>> getTimeline(String memberId);

  Future<bool> recordMealAdherence(String memberId, String status, {String? mealId, String? notes});

  Future<bool> logWaterQuick(String memberId, double litres);
}
