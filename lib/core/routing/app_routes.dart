class AppRoutes {
  // Entry & Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String accountRecovery = '/recovery';
  static const String accountDeactivation = '/profile/deactivate';
  static const String accountDeletion = '/profile/delete';

  // Shell / Bottom Navigation
  static const String mainShell = '/main';
  static const String home = '/home';
  static const String meals = '/meals';
  static const String health = '/health';
  static const String orders = '/orders';
  static const String profile = '/profile';

  // Chef Booking
  static const String bookChef = '/meals/book-chef';
  static const String bookChefAssigned = '/meals/book-chef/assigned';
  static const String bookChefCatalogue = '/meals/book-chef/catalogue';
  static const String bookChefReview = '/meals/book-chef/review';
  static const String bookChefCookingTime = '/meals/book-chef/cooking-time';
  static const String bookChefQuote = '/meals/book-chef/quote';
  static const String bookChefPayment = '/meals/book-chef/payment';
  static const String bookChefConfirmation = '/meals/book-chef/confirmation';
  static const String bookChefFailure = '/meals/book-chef/failure';
  static const String chefTracking = '/meals/book-chef/tracking';
  static const String preparationChecklist = '/meals/book-chef/preparation';
  static const String orderDetail = '/orders/detail';

  // Health Pass (Module 4 Sections 33–49)
  static const String healthPass = '/health-pass';
  static const String healthPassPlans = '/health-pass/plans';
  static const String healthPassComparison = '/health-pass/comparison';
  static const String healthPassConfigure = '/health-pass/configure';
  static const String healthPassReview = '/health-pass/review';
  static const String healthPassPayment = '/health-pass/payment';
  static const String healthPassActivation = '/health-pass/activation';
  static const String healthPassBenefits = '/health-pass/benefits';
  static const String healthPassUsage = '/health-pass/usage';
  static const String healthPassRenew = '/health-pass/renew';
  static const String healthPassHistory = '/health-pass/history';
  static const String healthPassPurchase = '/health-pass/purchase';

  // Dietitian & Consultations
  static const String dietitian = '/health/dietitian';
  static const String dietitianSelect = '/health/dietitian/select';
  static const String dietitianChat = '/health/dietitian/chat';
  static const String consultationBook = '/health/consultations/book';
  static const String consultationReview = '/health/consultations/review';
  static const String consultationsList = '/health/consultations';
  static const String consultationDetail = '/health/consultations/detail';
  static const String consultationVideo = '/health/consultations/video';
  static const String consultationSummary = '/health/consultations/summary';

  // Diet Plan
  static const String dietPlan = '/health/diet-plan';

  // Health Data (Module 8)
  static const String healthProfile = '/health/profile';
  static const String healthProfileEdit = '/health/profile/edit';
  static const String healthGoals = '/health/goals';
  static const String healthAllergies = '/health/allergies';
  static const String healthDietaryPreferences = '/health/dietary-preferences';
  static const String healthLifestyle = '/health/lifestyle';
  static const String healthBodyMeasurements = '/health/body-measurements';
  static const String healthMetrics = '/health/metrics';
  static const String healthPermissions = '/health/permissions';
  static const String healthDocuments = '/health/documents';
  static const String healthDocumentUpload = '/health/documents/upload';
  static const String healthDocumentDetail = '/health/documents/detail';
  static const String healthDocumentPreview = '/health/documents/preview';
  static const String healthProgress = '/health/progress';
  static const String progressTimeline = '/health/progress/timeline';

  // Profile & Management
  static const String editProfile = '/profile/edit';
  static const String household = '/profile/household';
  static const String memberForm = '/profile/household/member-form';
  static const String addresses = '/profile/addresses';
  static const String addressForm = '/profile/addresses/address-form';
  static const String preferences = '/profile/preferences';
  static const String walletCredits = '/profile/wallet';
  static const String promotions = '/promotions';
  static const String referrals = '/referrals';
  static const String referralHistory = '/referrals/history';
  static const String support = '/support';
  static const String supportCreateTicket = '/support/tickets/create';
  static const String supportTicketDetail = '/support/tickets/detail';
  static const String notifications = '/notifications';
  static const String privacy = '/profile/privacy';
  static const String security = '/profile/security';

  // System Screens (Module 20 Sections 313, 314, 320)
  static const String appUpdate = '/system/update';
  static const String notFound = '/system/404';

  // Backwards compatibility aliases
  static const String bookingConfirmation = bookChefConfirmation;
  static const String bookingFailure = bookChefFailure;
  static const String videoConsultation = consultationVideo;
  static const String purchasePass = healthPassPurchase;
}

