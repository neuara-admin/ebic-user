import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/health_profile_model.dart';
import '../models/health_goal_model.dart';
import '../models/health_allergy_model.dart';
import '../models/health_metric_entry_model.dart';
import '../models/health_permission_model.dart';
import '../models/health_completion_model.dart';

class HealthRemoteDataSource {
  final ApiClient _api = ApiClient();

  Future<HealthProfileModel?> getProfile(String memberId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '${ApiEndpoints.healthProfile}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return HealthProfileModel.fromJson(res.data!);
    }
    return null;
  }

  Future<HealthProfileModel?> updateProfile(Map<String, dynamic> payload) async {
    final res = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.healthProfile,
      body: payload,
    );
    if (res.success && res.data != null) {
      return HealthProfileModel.fromJson(res.data!);
    }
    return null;
  }

  Future<HealthCompletionModel?> getProfileCompletion(String memberId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '${ApiEndpoints.healthProfileCompletion}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return HealthCompletionModel.fromJson(res.data!);
    }
    return null;
  }

  Future<List<HealthGoalModel>> getGoals(String memberId) async {
    final res = await _api.get<List<dynamic>>(
      '${ApiEndpoints.healthGoals}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return res.data!
          .map((item) => HealthGoalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<HealthGoalModel?> createGoal(Map<String, dynamic> goalData) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.healthGoals,
      body: goalData,
    );
    if (res.success && res.data != null) {
      return HealthGoalModel.fromJson(res.data!);
    }
    return null;
  }

  Future<HealthGoalModel?> updateGoal(String goalId, Map<String, dynamic> goalData) async {
    final res = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.healthGoalDetail(goalId),
      body: goalData,
    );
    if (res.success && res.data != null) {
      return HealthGoalModel.fromJson(res.data!);
    }
    return null;
  }

  Future<bool> deleteGoal(String goalId) async {
    final res = await _api.delete<dynamic>(ApiEndpoints.healthGoalDetail(goalId));
    return res.success;
  }

  Future<List<HealthAllergyModel>> getAllergies(String memberId) async {
    final res = await _api.get<List<dynamic>>(
      '${ApiEndpoints.healthAllergies}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return res.data!
          .map((item) => HealthAllergyModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<HealthAllergyModel?> addAllergy(Map<String, dynamic> allergyData) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.healthAllergies,
      body: allergyData,
    );
    if (res.success && res.data != null) {
      return HealthAllergyModel.fromJson(res.data!);
    }
    return null;
  }

  Future<bool> deleteAllergy(String memberId, String allergenId) async {
    final res = await _api.delete<dynamic>(
      '${ApiEndpoints.healthAllergyDetail(allergenId)}?memberId=$memberId',
    );
    return res.success;
  }

  Future<List<HealthMetricEntryModel>> getMetrics(String memberId, [String? metricType]) async {
    var url = '${ApiEndpoints.healthMetrics}?memberId=$memberId';
    if (metricType != null && metricType.isNotEmpty) {
      url += '&metricType=$metricType';
    }
    final res = await _api.get<List<dynamic>>(url);
    if (res.success && res.data != null) {
      return res.data!
          .map((item) => HealthMetricEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<HealthMetricEntryModel>> getMetricHistory(String memberId, String metricType) async {
    final res = await _api.get<List<dynamic>>(
      '${ApiEndpoints.healthMetricHistory(metricType)}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return res.data!
          .map((item) => HealthMetricEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<HealthMetricEntryModel?> addMetric(Map<String, dynamic> metricData) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.healthMetrics,
      body: metricData,
    );
    if (res.success && res.data != null) {
      return HealthMetricEntryModel.fromJson(res.data!);
    }
    return null;
  }

  Future<List<HealthPermissionModel>> getPermissions(String memberId) async {
    final res = await _api.get<List<dynamic>>(
      '${ApiEndpoints.healthPermissions}?memberId=$memberId',
    );
    if (res.success && res.data != null) {
      return res.data!
          .map((item) => HealthPermissionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<HealthPermissionModel?> updatePermission(
    String dataType,
    Map<String, dynamic> permissionData,
  ) async {
    final res = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.healthPermissionDetail(dataType),
      body: permissionData,
    );
    if (res.success && res.data != null) {
      return HealthPermissionModel.fromJson(res.data!);
    }
    return null;
  }

  Future<Map<String, dynamic>> getDietaryPreferencesMaster() async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.healthDietaryPreferences);
    if (res.success && res.data != null) {
      return res.data!;
    }
    return {};
  }
}
