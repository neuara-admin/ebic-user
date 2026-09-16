import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import 'models/diet_plan_models.dart';

class DietPlanService {
  final ApiClient _api = ApiClient();

  /// Section 75-77: Fetch active diet plan for member
  Future<DietPlanDetailModel?> getActivePlan({String? memberId}) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dietPlanActive,
        queryParameters: memberId != null ? {'memberId': memberId} : null,
      );
      if (res.success && res.data != null) {
        return DietPlanDetailModel.fromJson(res.data!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Section 82: Fetch 7-day calendar schedule
  Future<Map<String, dynamic>?> getCalendar(String planId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dietPlanCalendar(planId),
      );
      if (res.success && res.data != null) {
        return res.data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Section 80: Fetch specific meal details, ingredients, prep notes, macros & eligibility
  Future<DietPlanMealModel?> getMealDetails(String planId, String mealId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.dietPlanMealDetail(planId, mealId),
      );
      if (res.success && res.data != null) {
        return DietPlanMealModel.fromJson(res.data!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Section 78 & 13: Fetch structured daily nutrition targets
  Future<List<DietPlanNutritionTargetModel>> getNutritionTargets(String planId) async {
    try {
      final res = await _api.get<List<dynamic>>(
        ApiEndpoints.dietPlanNutritionTargets(planId),
      );
      if (res.success && res.data != null) {
        return res.data!
            .map((e) => DietPlanNutritionTargetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Section 84/42: Record customer meal feedback
  Future<bool> recordMealFeedback(
    String planId,
    String mealId, {
    required String feedbackType,
    String? notes,
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.dietPlanMealFeedback(planId, mealId),
        body: {
          'feedbackType': feedbackType,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return res.success;
    } catch (_) {
      return false;
    }
  }

  /// Section 84/43: Track meal adherence (PLANNED, CONFIRMED_CONSUMED, SKIPPED)
  Future<bool> recordMealAdherence(
    String planId,
    String mealId, {
    required String status,
    String? date,
    String? notes,
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.dietPlanMealAdherence(planId, mealId),
        body: {
          'status': status,
          ...?(date != null ? {'date': date} : null),
          ...?(notes != null && notes.isNotEmpty ? {'notes': notes} : null),
        },
      );
      return res.success;
    } catch (_) {
      return false;
    }
  }

  /// Section 85: List past plans / version history
  Future<List<Map<String, dynamic>>> getPlanHistory({String? memberId}) async {
    try {
      final res = await _api.get<List<dynamic>>(
        ApiEndpoints.dietPlans,
        queryParameters: memberId != null ? {'memberId': memberId} : null,
      );
      if (res.success && res.data != null) {
        return res.data!.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
