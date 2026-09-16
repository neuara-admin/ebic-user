import '../../domain/repositories/health_repository.dart';
import '../datasources/health_remote_datasource.dart';
import '../models/health_profile_model.dart';
import '../models/health_goal_model.dart';
import '../models/health_allergy_model.dart';
import '../models/health_metric_entry_model.dart';
import '../models/health_permission_model.dart';
import '../models/health_completion_model.dart';

class HealthRepositoryImpl implements HealthRepository {
  final HealthRemoteDataSource _dataSource;

  HealthRepositoryImpl({HealthRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? HealthRemoteDataSource();

  @override
  Future<HealthProfileModel?> getProfile(String memberId) => _dataSource.getProfile(memberId);

  @override
  Future<HealthProfileModel?> updateProfile(Map<String, dynamic> payload) =>
      _dataSource.updateProfile(payload);

  @override
  Future<HealthCompletionModel?> getProfileCompletion(String memberId) =>
      _dataSource.getProfileCompletion(memberId);

  @override
  Future<List<HealthGoalModel>> getGoals(String memberId) => _dataSource.getGoals(memberId);

  @override
  Future<HealthGoalModel?> createGoal(Map<String, dynamic> goalData) =>
      _dataSource.createGoal(goalData);

  @override
  Future<HealthGoalModel?> updateGoal(String goalId, Map<String, dynamic> goalData) =>
      _dataSource.updateGoal(goalId, goalData);

  @override
  Future<bool> deleteGoal(String goalId) => _dataSource.deleteGoal(goalId);

  @override
  Future<List<HealthAllergyModel>> getAllergies(String memberId) =>
      _dataSource.getAllergies(memberId);

  @override
  Future<HealthAllergyModel?> addAllergy(Map<String, dynamic> allergyData) =>
      _dataSource.addAllergy(allergyData);

  @override
  Future<bool> deleteAllergy(String memberId, String allergenId) =>
      _dataSource.deleteAllergy(memberId, allergenId);

  @override
  Future<List<HealthMetricEntryModel>> getMetrics(String memberId, [String? metricType]) =>
      _dataSource.getMetrics(memberId, metricType);

  @override
  Future<List<HealthMetricEntryModel>> getMetricHistory(String memberId, String metricType) =>
      _dataSource.getMetricHistory(memberId, metricType);

  @override
  Future<HealthMetricEntryModel?> addMetric(Map<String, dynamic> metricData) =>
      _dataSource.addMetric(metricData);

  @override
  Future<List<HealthPermissionModel>> getPermissions(String memberId) =>
      _dataSource.getPermissions(memberId);

  @override
  Future<HealthPermissionModel?> updatePermission(
          String dataType, Map<String, dynamic> permissionData) =>
      _dataSource.updatePermission(dataType, permissionData);

  @override
  Future<Map<String, dynamic>> getDietaryPreferencesMaster() =>
      _dataSource.getDietaryPreferencesMaster();
}
