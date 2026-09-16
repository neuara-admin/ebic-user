import '../../domain/entities/health_progress_entity.dart';
import '../../domain/repositories/health_progress_repository.dart';
import '../datasources/health_progress_remote_datasource.dart';

class HealthProgressRepositoryImpl implements HealthProgressRepository {
  final HealthProgressRemoteDataSource _dataSource;

  HealthProgressRepositoryImpl([HealthProgressRemoteDataSource? dataSource])
      : _dataSource = dataSource ?? HealthProgressRemoteDataSource();

  @override
  Future<HealthProgressDashboardEntity> getDashboard(
    String memberId, {
    String? period,
    String? startDate,
    String? endDate,
  }) {
    return _dataSource.fetchDashboard(memberId, period: period, startDate: startDate, endDate: endDate);
  }

  @override
  Future<WeightProgressEntity> getMetricTrend(String memberId, String metricType, {String? period}) {
    return _dataSource.fetchMetricTrend(memberId, metricType, period: period);
  }

  @override
  Future<List<TimelineItemEntity>> getTimeline(String memberId) {
    return _dataSource.fetchTimeline(memberId);
  }

  @override
  Future<bool> recordMealAdherence(String memberId, String status, {String? mealId, String? notes}) {
    return _dataSource.recordMealAdherence(memberId, status, mealId: mealId, notes: notes);
  }

  @override
  Future<bool> logWaterQuick(String memberId, double litres) {
    return _dataSource.logWaterQuick(memberId, litres);
  }
}
