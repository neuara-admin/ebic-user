import '../../data/models/health_profile_model.dart';
import '../../data/models/health_goal_model.dart';
import '../../data/models/health_allergy_model.dart';
import '../../data/models/health_metric_entry_model.dart';
import '../../data/models/health_permission_model.dart';
import '../../data/models/health_completion_model.dart';

abstract class HealthRepository {
  Future<HealthProfileModel?> getProfile(String memberId);
  Future<HealthProfileModel?> updateProfile(Map<String, dynamic> payload);
  Future<HealthCompletionModel?> getProfileCompletion(String memberId);
  Future<List<HealthGoalModel>> getGoals(String memberId);
  Future<HealthGoalModel?> createGoal(Map<String, dynamic> goalData);
  Future<HealthGoalModel?> updateGoal(String goalId, Map<String, dynamic> goalData);
  Future<bool> deleteGoal(String goalId);
  Future<List<HealthAllergyModel>> getAllergies(String memberId);
  Future<HealthAllergyModel?> addAllergy(Map<String, dynamic> allergyData);
  Future<bool> deleteAllergy(String memberId, String allergenId);
  Future<List<HealthMetricEntryModel>> getMetrics(String memberId, [String? metricType]);
  Future<List<HealthMetricEntryModel>> getMetricHistory(String memberId, String metricType);
  Future<HealthMetricEntryModel?> addMetric(Map<String, dynamic> metricData);
  Future<List<HealthPermissionModel>> getPermissions(String memberId);
  Future<HealthPermissionModel?> updatePermission(String dataType, Map<String, dynamic> permissionData);
  Future<Map<String, dynamic>> getDietaryPreferencesMaster();
}
