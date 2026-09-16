import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../domain/entities/health_progress_entity.dart';

class HealthProgressRemoteDataSource {
  final ApiClient _api = ApiClient();

  Future<HealthProgressDashboardEntity> fetchDashboard(
    String memberId, {
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, dynamic>{'memberId': memberId};
    if (period != null && period.isNotEmpty) query['period'] = period;
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;

    final res = await _api.get(ApiEndpoints.healthProgressDashboard, queryParameters: query);
    if (res.success && res.data != null) {
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : (res.data is Map && (res.data as Map)['data'] is Map
              ? (res.data as Map)['data'] as Map<String, dynamic>
              : <String, dynamic>{});
      return HealthProgressDashboardEntity.fromJson(data);
    }
    throw Exception(res.error?.message ?? 'Failed to load progress dashboard');
  }

  Future<WeightProgressEntity> fetchMetricTrend(
    String memberId,
    String metricType, {
    String? period,
  }) async {
    final query = <String, dynamic>{'memberId': memberId};
    if (period != null) query['period'] = period;

    final res = await _api.get(ApiEndpoints.healthProgressMetric(metricType), queryParameters: query);
    if (res.success && res.data != null) {
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : (res.data is Map && (res.data as Map)['data'] is Map
              ? (res.data as Map)['data'] as Map<String, dynamic>
              : <String, dynamic>{});
      return WeightProgressEntity.fromJson(data);
    }
    throw Exception(res.error?.message ?? 'Failed to load metric trend');
  }

  Future<List<TimelineItemEntity>> fetchTimeline(String memberId) async {
    final res = await _api.get(
      ApiEndpoints.healthProgressTimeline,
      queryParameters: {'memberId': memberId},
    );
    if (res.success && res.data != null) {
      List<dynamic> list = [];
      if (res.data is List) {
        list = res.data as List<dynamic>;
      } else if (res.data is Map && (res.data as Map)['data'] is List) {
        list = (res.data as Map)['data'] as List<dynamic>;
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(TimelineItemEntity.fromJson)
          .toList();
    }
    return [];
  }

  Future<bool> recordMealAdherence(
    String memberId,
    String status, {
    String? mealId,
    String? notes,
  }) async {
    final res = await _api.post(
      ApiEndpoints.healthProgressAdherence,
      body: {
        'memberId': memberId,
        'status': status,
        'date': DateTime.now().toIso8601String(),
        'dietPlanMealId': mealId,
        'notes': notes,
      },
    );
    return res.success;
  }

  Future<bool> logWaterQuick(String memberId, double litres) async {
    final res = await _api.post(
      ApiEndpoints.healthMetrics,
      body: {
        'memberId': memberId,
        'metricType': 'WATER',
        'value': litres,
        'unit': 'L',
        'source': 'MANUAL',
        'recordedAt': DateTime.now().toIso8601String(),
      },
    );
    return res.success;
  }
}
