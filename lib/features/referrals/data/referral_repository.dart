import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import 'referral_models.dart';

class ReferralRepository {
  static final ReferralRepository _instance = ReferralRepository._internal();
  factory ReferralRepository() => _instance;
  ReferralRepository._internal();

  final ApiClient _api = ApiClient();

  /// Fetch full dashboard for Refer & Earn screen
  Future<ApiResponse<ReferralDashboardModel>> getDashboard() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.referralsMe);
      if (res.success && res.data != null) {
        return ApiResponse(success: true, data: ReferralDashboardModel.fromJson(res.data!));
      }
      return ApiResponse(success: false, message: res.message ?? 'Failed to load referral dashboard');
    } catch (e) {
      debugPrint('Error getting referral dashboard: $e');
      return ApiResponse(success: false, message: 'Error connecting to referral service');
    }
  }

  /// Ensure or generate customer's unique referral code
  Future<ApiResponse<Map<String, dynamic>>> getOrCreateReferralCode() async {
    try {
      final res = await _api.post<Map<String, dynamic>>(ApiEndpoints.referralsCode);
      if (res.success && res.data != null) {
        return ApiResponse(success: true, data: res.data!);
      }
      return ApiResponse(success: false, message: res.message ?? 'Failed to generate referral code');
    } catch (e) {
      debugPrint('Error generating referral code: $e');
      return ApiResponse(success: false, message: 'Error generating referral code');
    }
  }

  /// Fetch paginated referral history with optional status filter
  Future<ApiResponse<List<ReferralItemModel>>> getHistory({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
        queryParams['status'] = status.toUpperCase();
      }
      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.referralsHistory}?$queryString';

      final res = await _api.get<dynamic>(url);
      if (res.success && res.data != null) {
        List<dynamic> list = [];
        if (res.data is Map && res.data['items'] is List) {
          list = res.data['items'] as List<dynamic>;
        } else if (res.data is List) {
          list = res.data as List<dynamic>;
        }
        final items = list
            .map((item) => item is Map<String, dynamic> ? ReferralItemModel.fromJson(item) : null)
            .whereType<ReferralItemModel>()
            .toList();
        return ApiResponse(success: true, data: items);
      }
      return ApiResponse(success: false, message: res.message ?? 'Failed to load referral history');
    } catch (e) {
      debugPrint('Error getting referral history: $e');
      return ApiResponse(success: false, message: 'Error loading referral history');
    }
  }

  /// Claim / attribute a referral code upon onboarding or settings
  Future<ApiResponse<Map<String, dynamic>>> claimReferral(String referralCode) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.referralsClaim,
        body: {'referralCode': referralCode.trim().toUpperCase()},
      );
      if (res.success && res.data != null) {
        return ApiResponse(success: true, data: res.data!);
      }
      return ApiResponse(success: false, message: res.message ?? 'Could not claim referral code');
    } catch (e) {
      debugPrint('Error claiming referral code: $e');
      return ApiResponse(success: false, message: 'Error claiming referral code');
    }
  }

  /// Track click / install from referral deep link
  Future<ApiResponse<Map<String, dynamic>>> trackReferralLink(
    String referralCode, {
    String? campaignCode,
  }) async {
    try {
      final payload = <String, dynamic>{
        'referralCode': referralCode.trim().toUpperCase(),
      };
      if (campaignCode != null) {
        payload['campaignCode'] = campaignCode;
      }
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.referralsTrack,
        body: payload,
      );
      if (res.success && res.data != null) {
        return ApiResponse(success: true, data: res.data!);
      }
      return ApiResponse(success: false, message: res.message ?? 'Invalid referral code');
    } catch (e) {
      debugPrint('Error tracking referral link: $e');
      return ApiResponse(success: false, message: 'Error verifying referral link');
    }
  }
}
