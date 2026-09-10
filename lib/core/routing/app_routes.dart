class AppRoutes {
  // Entry & Auth
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';

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
  static const String chefTracking = '/meals/book-chef/tracking';
  static const String preparationChecklist = '/meals/book-chef/preparation';
  static const String orderDetail = '/orders/detail';

  // Health Pass
  static const String healthPass = '/health-pass';
  static const String healthPassPlans = '/health-pass/plans';
  static const String healthPassPurchase = '/health-pass/purchase';

  // Dietitian & Consultations
  static const String dietitian = '/health/dietitian';
  static const String dietitianSelect = '/health/dietitian/select';
  static const String consultationBook = '/health/consultations/book';
  static const String consultationsList = '/health/consultations';
  static const String consultationVideo = '/health/consultations/video';
  static const String consultationSummary = '/health/consultations/summary';

  // Diet Plan
  static const String dietPlan = '/health/diet-plan';

  // Health Data
  static const String healthProfile = '/health/profile';
  static const String healthDocuments = '/health/documents';
  static const String healthProgress = '/health/progress';

  // Profile & Management
  static const String household = '/profile/household';
  static const String addresses = '/profile/addresses';
  static const String walletCredits = '/profile/wallet';
  static const String promotions = '/promotions';
  static const String support = '/support';
  static const String supportCreateTicket = '/support/tickets/create';
  static const String supportTicketDetail = '/support/tickets/detail';
  static const String notifications = '/notifications';
  static const String privacy = '/profile/privacy';
}
