import 'package:flutter/material.dart';
import 'app_routes.dart';

// Splash & Auth
import '../../features/splash/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_verification_screen.dart';
import '../../features/auth/forgot_password_screen.dart';

// Home & Shell
import '../../features/home/main_nav_shell.dart';

// Chef Booking & Catalogue
import '../../features/chef_booking/booking_type_screen.dart';
import '../../features/chef_booking/assigned_meal_screen.dart';
import '../../features/chef_booking/quote_review_screen.dart';
import '../../features/chef_booking/payment_checkout_screen.dart';
import '../../features/chef_booking/booking_confirmation_screen.dart';
import '../../features/chef_booking/chef_tracking_screen.dart';
import '../../features/catalogue/catalogue_screen.dart';

// Preparation
import '../../features/preparation/preparation_checklist_screen.dart';

// Health Pass
import '../../features/health_pass/health_pass_screen.dart';
import '../../features/health_pass/plans_screen.dart';
import '../../features/health_pass/purchase_pass_screen.dart';

// Dietitian & Consultations
import '../../features/dietitian/dietitian_list_screen.dart';
import '../../features/consultation/book_consultation_screen.dart';
import '../../features/consultation/consultation_list_screen.dart';
import '../../features/consultation/video_consultation_screen.dart';
import '../../features/consultation/consultation_summary_screen.dart';

// Diet Plan & Health Data
import '../../features/diet_plan/diet_plan_screen.dart';
import '../../features/health/health_profile_screen.dart';
import '../../features/health/progress_charts_screen.dart';
import '../../features/health/health_documents_screen.dart';

// Orders
import '../../features/orders/order_detail_screen.dart';

// Profile & Settings
import '../../features/profile/household_screen.dart';
import '../../features/profile/addresses_screen.dart';
import '../../features/profile/wallet_credits_screen.dart';
import '../../features/profile/promotions_screen.dart';
import '../../features/profile/support_screen.dart';
import '../../features/profile/notifications_screen.dart';
import '../../features/profile/privacy_screen.dart';

// Shared models
import '../../shared/models/consultation_model.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      // Entry & Auth
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.otp:
        final phone = (args is Map ? args['phone'] : null) ?? '+91 98765 43210';
        return MaterialPageRoute(builder: (_) => OtpVerificationScreen(phone: phone));
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      // Shell & Tabs
      case AppRoutes.mainShell:
        final tab = (args is int) ? args : 0;
        return MaterialPageRoute(builder: (_) => MainNavShell(initialTab: tab));
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const MainNavShell(initialTab: 0));
      case AppRoutes.meals:
        return MaterialPageRoute(builder: (_) => const MainNavShell(initialTab: 1));
      case AppRoutes.health:
        return MaterialPageRoute(builder: (_) => const MainNavShell(initialTab: 2));
      case AppRoutes.orders:
        return MaterialPageRoute(builder: (_) => const MainNavShell(initialTab: 3));
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const MainNavShell(initialTab: 4));

      // Chef Booking
      case AppRoutes.bookChef:
        return MaterialPageRoute(builder: (_) => const BookingTypeScreen());
      case AppRoutes.bookChefAssigned:
        return MaterialPageRoute(builder: (_) => const AssignedMealScreen());
      case AppRoutes.bookChefCatalogue:
        return MaterialPageRoute(builder: (_) => const CatalogueScreen());
      case AppRoutes.bookChefQuote:
        final config = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => QuoteReviewScreen(bookingConfig: config));
      case AppRoutes.bookChefPayment:
        final data = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => PaymentCheckoutScreen(checkoutData: data));
      case AppRoutes.bookChefConfirmation:
        final data = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => BookingConfirmationScreen(confirmationData: data));
      case AppRoutes.chefTracking:
        final orderId = (args is Map ? args['orderId'] : args)?.toString() ?? '';
        return MaterialPageRoute(builder: (_) => ChefTrackingScreen(orderId: orderId));
      case AppRoutes.preparationChecklist:
        final orderId = (args is Map ? args['orderId'] : args)?.toString() ?? '';
        return MaterialPageRoute(builder: (_) => PreparationChecklistScreen(orderId: orderId));
      case AppRoutes.orderDetail:
        final orderId = (args is Map ? args['orderId'] : args)?.toString() ?? '';
        return MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId));

      // Health Pass
      case AppRoutes.healthPass:
        return MaterialPageRoute(builder: (_) => const HealthPassScreen());
      case AppRoutes.healthPassPlans:
        return MaterialPageRoute(builder: (_) => const HealthPassPlansScreen());
      case AppRoutes.healthPassPurchase:
        final data = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => PurchasePassScreen(purchaseData: data));

      // Dietitian & Consultations
      case AppRoutes.dietitian:
        return MaterialPageRoute(builder: (_) => const DietitianListScreen());
      case AppRoutes.consultationBook:
        final data = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        return MaterialPageRoute(builder: (_) => BookConsultationScreen(arguments: data));
      case AppRoutes.consultationsList:
        return MaterialPageRoute(builder: (_) => const ConsultationListScreen());
      case AppRoutes.consultationVideo:
        final data = (args is Map ? args['consultation'] : null);
        if (data is ConsultationModel) {
          return MaterialPageRoute(builder: (_) => VideoConsultationScreen(consultation: data));
        }
        return MaterialPageRoute(
          builder: (_) => VideoConsultationScreen(
            consultation: ConsultationModel(
              id: 'c_preview',
              dietitianId: 'd_1',
              dietitianName: 'Dr. Ananya Sharma',
              memberName: 'Self',
              scheduledAt: DateTime.now(),
              status: 'SCHEDULED',
            ),
          ),
        );
      case AppRoutes.consultationSummary:
        final data = (args is Map ? args['consultation'] : null);
        if (data is ConsultationModel) {
          return MaterialPageRoute(builder: (_) => ConsultationSummaryScreen(consultation: data));
        }
        return MaterialPageRoute(
          builder: (_) => ConsultationSummaryScreen(
            consultation: ConsultationModel(
              id: 'c_preview',
              dietitianId: 'd_1',
              dietitianName: 'Dr. Ananya Sharma',
              memberName: 'Self',
              scheduledAt: DateTime.now(),
              status: 'COMPLETED',
            ),
          ),
        );

      // Diet Plan & Health
      case AppRoutes.dietPlan:
        return MaterialPageRoute(builder: (_) => const DietPlanScreen());
      case AppRoutes.healthProfile:
        return MaterialPageRoute(builder: (_) => const HealthProfileScreen());
      case AppRoutes.healthProgress:
        return MaterialPageRoute(builder: (_) => const ProgressChartsScreen());
      case AppRoutes.healthDocuments:
        return MaterialPageRoute(builder: (_) => const HealthDocumentsScreen());

      // Profile & Settings
      case AppRoutes.household:
        return MaterialPageRoute(builder: (_) => const HouseholdScreen());
      case AppRoutes.addresses:
        return MaterialPageRoute(builder: (_) => const AddressesScreen());
      case AppRoutes.walletCredits:
        return MaterialPageRoute(builder: (_) => const WalletCreditsScreen());
      case AppRoutes.promotions:
        return MaterialPageRoute(builder: (_) => const PromotionsScreen());
      case AppRoutes.support:
        return MaterialPageRoute(builder: (_) => const SupportScreen());
      case AppRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case AppRoutes.privacy:
        return MaterialPageRoute(builder: (_) => const PrivacyScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route ${settings.name} not found')),
          ),
        );
    }
  }
}
