class ApiEndpoints {
  // Auth
  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String authSessions = '/auth/sessions';
  static const String accountRecovery = '/auth/recovery/start';

  // Customer Profile, Account Lifecycle & Address
  static const String me = '/me';
  static const String requestEmailOtp = '/me/email/otp/request';
  static const String verifyEmailOtp = '/me/email/otp/verify';
  static const String uploadAvatar = '/me/avatar';
  static const String preferences = '/me/preferences';
  static const String customerPreferences = '/me/preferences';
  static const String deactivateAccount = '/me/deactivate';
  static const String deletionCheck = '/me/deletion-check';
  static const String deleteRequest = '/me/delete-request';
  static const String addresses = '/me/addresses';
  static const String customerAddresses = '/me/addresses';
  static String address(String id) => '/me/addresses/$id';
  static String customerAddressDetail(String id) => '/me/addresses/$id';
  static String customerAddressSetDefault(String id) => '/me/addresses/$id/default';
  static String addressServiceabilityCheck(String id) => '/me/addresses/$id/serviceability-check';
  static const String serviceabilityCheck = '/serviceability/check';

  // Maps (server-side geocoding — no client API key needed)
  static const String mapsGeocode = '/maps/geocode';
  static const String mapsReverseGeocode = '/maps/reverse';
  static const String mapsAutocomplete = '/maps/autocomplete';

  // Household & Members
  static const String householdMembers = '/household/members';
  static String householdMember(String id) => '/household/members/$id';
  static String householdMemberDetail(String id) => '/household/members/$id';
  static String householdMemberAvatar(String id) => '/household/members/$id/avatar';

  // Member Health & Documents (Module 8 & Module 9)
  static const String healthDocuments = '/health/documents';
  static const String healthDocumentCategories = '/health/documents/categories';
  static const String healthDocumentUploadSession = '/health/documents/upload-session';
  static const String healthDocumentUploadDirect = '/health/documents/upload';
  static String healthDocumentComplete(String id) => '/health/documents/$id/complete';
  static String healthDocumentDetail(String id) => '/health/documents/$id';
  static String healthDocumentAccess(String id) => '/health/documents/$id/access';
  static String healthDocumentPermissions(String id) => '/health/documents/$id/permissions';
  static String healthDocumentPermission(String id, String permId) =>
      '/health/documents/$id/permissions/$permId';

  static String memberHealthProfile(String memberId) =>
      '/household/members/$memberId/health/profile';
  static String memberHealthMetrics(String memberId) =>
      '/household/members/$memberId/health/metrics';
  static String memberHealthDocuments(String memberId) =>
      '/health/documents?memberId=$memberId';

  static const String healthProfile = '/health/profile';
  static const String healthProfileCompletion = '/health/profile/completion';
  static const String healthGoals = '/health/goals';
  static String healthGoalDetail(String id) => '/health/goals/$id';
  static const String healthDietaryPreferences = '/health/dietary-preferences';
  static const String healthProfileDietaryPreferences = '/health/profile/dietary-preferences';
  static const String healthAllergies = '/health/allergies';
  static String healthAllergyDetail(String allergenId) => '/health/allergies/$allergenId';
  static const String healthMetrics = '/health/metrics';
  static String healthMetricHistory(String metricType) => '/health/metrics/$metricType/history';
  static const String healthPermissions = '/health/permissions';
  static String healthPermissionDetail(String dataType) => '/health/permissions/$dataType';

  // Health Progress & Insights (Module 10)
  static const String healthProgressDashboard = '/health/progress/dashboard';
  static String healthProgressMetric(String type) => '/health/progress/metrics/$type';
  static const String healthProgressGoals = '/health/progress/goals';
  static const String healthProgressHydration = '/health/progress/hydration';
  static const String healthProgressAdherence = '/health/progress/adherence';
  static const String healthProgressInsights = '/health/progress/insights';
  static const String healthProgressTimeline = '/health/progress/timeline';

  // Catalogue & Taxonomy
  static const String catalogueAllergens = '/catalogue/allergens';
  static const String catalogueDietaryTags = '/catalogue/dietary-tags';
  static const String dishes = '/catalogue/dishes';
  static const String catalogueDishes = '/catalogue/dishes';
  static String dish(String id) => '/catalogue/dishes/$id';
  static const String categories = '/catalogue/categories';
  static const String catalogueCategories = '/catalogue/categories';
  static const String catalogueBookingValidate = '/catalogue/booking/validate';
  static const String catalogueBookingQuote = '/catalogue/booking/quote';

  // Chef Bookings & Orders
  static const String orders = '/orders';
  static String order(String id) => '/orders/$id';
  static String orderDetail(String id) => '/orders/$id';
  static const String ordersCookingTime = '/orders/cooking-time';
  static String orderPreparation(String id) => '/orders/$id/preparation';
  static String orderPreparationMarkAllReady(String id) =>
      '/orders/$id/preparation/mark-all-ready';
  static String orderPayInitiate(String id) => '/orders/$id/pay/initiate';
  static String orderPayVerify(String id) => '/orders/$id/pay/verify';
  static String orderRating(String id) => '/orders/$id/rating';

  // Dedicated Chef Bookings aliases
  static const String chefBookings = '/chef-bookings';
  static String chefBooking(String id) => '/chef-bookings/$id';
  static const String chefBookingsQuote = '/chef-bookings/quote';
  static const String chefBookingsServiceability = '/chef-bookings/serviceability';
  static const String chefBookingsCookingTime = '/chef-bookings/cooking-time';
  static String chefBookingTimeline(String id) => '/chef-bookings/$id/timeline';
  static String chefBookingPreparation(String id) => '/chef-bookings/$id/preparation';
  static String chefBookingMarkAllReady(String id) =>
      '/chef-bookings/$id/preparation/mark-all-ready';
  static String chefBookingItems(String id) => '/chef-bookings/$id/items';
  static String chefBookingAddItems(String id) => '/chef-bookings/$id/items';
  static String chefBookingCancel(String id) => '/chef-bookings/$id/cancel';

  // Dynamic Quotes
  static const String calculateQuote = '/pricing/quotes';
  static String recalculateQuote(String id) => '/pricing/quotes/$id/recalculate';

  // Health Pass (Module 4 Sections 33–49)
  static const String healthPassPlans = '/health-pass/plans';
  static const String healthPassPlansComparison = '/health-pass/plans/comparison';
  static String healthPassPlanDetail(String id) => '/health-pass/plans/$id';
  static const String myHealthPass = '/health-pass/my';
  static const String healthPassCurrent = '/health-pass/current';
  static const String healthPassHistory = '/health-pass/history';
  static const String healthPassQuote = '/health-pass/quote';
  static const String healthPassPurchase = '/health-pass/purchase';
  static String healthPassDetail(String id) => '/health-pass/$id';
  static String healthPassUsage(String id) => '/health-pass/$id/usage';
  static String healthPassRenewQuote(String id) => '/health-pass/$id/renew/quote';
  static String healthPassRenew(String id) => '/health-pass/$id/renew';
  static String healthPassPayInitiate(String id) => '/health-pass/$id/pay/initiate';
  static String healthPassPayVerify(String id) => '/health-pass/$id/pay/verify';

  // Health Pass Chef Booking (Module 12 Sections 49–51)
  static const String healthPassChefEligibility = '/health-pass/chef-booking/eligibility';
  static const String healthPassChefEntitlements = '/health-pass/chef-booking/entitlements';
  static const String healthPassChefQuoteContext = '/health-pass/chef-booking/quote-context';

  // Dietitian & Consultations
  static const String dietitians = '/dietitians';
  static String dietitian(String id) => '/dietitians/$id';
  static String dietitianAvailability(String id) => '/dietitians/$id/availability';
  static const String consultations = '/consultations';
  static String consultation(String id) => '/consultations/$id';
  static const String consultationEligibility = '/consultations/eligibility';
  static const String consultationTypes = '/consultations/types';
  static const String consultationAvailabilityDates = '/consultations/availability/dates';
  static const String consultationAvailabilitySlots = '/consultations/availability/slots';
  static const String consultationHistory = '/consultations/history';
  static String consultationJoin(String id) => '/consultations/$id/join';
  static String cancelConsultation(String id) => '/consultations/$id/cancel';
  static String consultationCancel(String id) => '/consultations/$id/cancel';
  static String consultationReschedule(String id) => '/consultations/$id/reschedule';
  static const String todayDietPlan = '/diet-plans/today';
  static const String dietPlanToday = '/diet-plans/today';
  static const String dietPlans = '/diet-plans';
  static const String dietPlanActive = '/diet-plans/active';
  static String memberDietPlans(String memberId) =>
      '/diet-plans?memberId=$memberId';
  static String dietPlanDetail(String id) => '/diet-plans/$id';
  static String dietPlanCalendar(String id) => '/diet-plans/$id/calendar';
  static String dietPlanMealDetail(String id, String mealId) =>
      '/diet-plans/$id/meals/$mealId';
  static String dietPlanNutritionTargets(String id) =>
      '/diet-plans/$id/nutrition-targets';
  static String dietPlanMealFeedback(String id, String mealId) =>
      '/diet-plans/$id/meals/$mealId/feedback';
  static String dietPlanMealAdherence(String id, String mealId) =>
      '/diet-plans/$id/meals/$mealId/adherence';

  // Wallet & Credits
  static const String credits = '/wallet/balance';
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';

  // Support
  static const String supportTickets = '/support/tickets';
  static String supportTicket(String id) => '/support/tickets/$id';

  // Notifications
  static const String notifications = '/notifications';

  // Promotions & Coupons
  static const String validatePromotion = '/promotions/validate';
  static const String promotionsValidate = '/promotions/validate';
  static const String cancellationReasons = '/cancellations/reasons';
  static const String evaluateCancellation = '/cancellation-policies/evaluate';
  static const String cancellationEvaluate = '/cancellation-policies/evaluate';
}
