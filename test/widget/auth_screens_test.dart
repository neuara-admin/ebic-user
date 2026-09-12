import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebic_user/features/splash/splash_screen.dart';
import 'package:ebic_user/features/onboarding/onboarding_screen.dart';
import 'package:ebic_user/features/auth/welcome_screen.dart';
import 'package:ebic_user/features/auth/login_screen.dart';
import 'package:ebic_user/features/auth/register_screen.dart';
import 'package:ebic_user/features/auth/otp_verification_screen.dart';
import 'package:ebic_user/shared/widgets/ebic_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
      ),
    );
  }

  group('Module 2 — Section 71 Widget Tests: Welcome Screen', () {
    testWidgets('WelcomeScreen renders headline, Create Account and Login buttons', (tester) async {
      await tester.pumpWidget(createTestWidget(const WelcomeScreen()));
      await tester.pump();

      expect(find.textContaining('Precision Nutrition'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In with Phone / OTP'), findsOneWidget);
      expect(find.text('Staff or Console Sign In'), findsNothing);
    });
  });

  group('Module 2 — Section 71 Widget Tests: Register Screen', () {
    testWidgets('RegisterScreen displays all required fields and client validation', (tester) async {
      await tester.pumpWidget(createTestWidget(const RegisterScreen()));
      await tester.pump();

      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Mobile Number *'), findsOneWidget);
      expect(find.text('Email Address (Optional)'), findsOneWidget);
      expect(find.text('Referral Code (Optional)'), findsOneWidget);
      expect(find.text('Create Account & Send OTP'), findsOneWidget);

      // Tap submit with empty form -> triggers validation error
      final submitBtn = find.widgetWithText(EbicButton, 'Create Account & Send OTP');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.textContaining('Please enter your full name'), findsOneWidget);
    });

    testWidgets('RegisterScreen validates short names and invalid phone numbers', (tester) async {
      await tester.pumpWidget(createTestWidget(const RegisterScreen()));
      await tester.pump();

      final submitBtn = find.widgetWithText(EbicButton, 'Create Account & Send OTP');

      // Enter single character name
      await tester.enterText(find.byType(TextField).at(0), 'A');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.textContaining('at least 2 characters'), findsOneWidget);

      // Enter valid name, but invalid phone
      await tester.enterText(find.byType(TextField).at(0), 'Rohit Kumar');
      await tester.enterText(find.byType(TextField).at(1), '12345');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.textContaining('10-digit mobile number'), findsOneWidget);
    });
  });

  group('Module 2 — Section 71 Widget Tests: Login Screen', () {
    testWidgets('LoginScreen displays phone input mode by default with sign up link', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pump();

      expect(find.text('Sign In with Phone'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
      expect(find.textContaining('Sign Up'), findsOneWidget);
      expect(find.textContaining('Account Recovery'), findsOneWidget);

      // Tap send verification with empty phone
      final sendBtn = find.widgetWithText(EbicButton, 'Send Verification Code');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pump();

      expect(find.textContaining('Please enter your mobile phone number'), findsOneWidget);

      // Enter invalid phone
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '12345');
      await tester.pump();
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('10-digit mobile number'), findsOneWidget);
    });

    testWidgets('LoginScreen renders exclusively customer phone OTP inputs and no password/staff inputs', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pump();

      expect(find.text('Sign In with Phone'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Email Address'), findsNothing);
      expect(find.text('Forgot Password?'), findsNothing);
    });
  });

  group('Module 2 — Section 13 & 14 Widget Tests: Splash and Onboarding Screens', () {
    testWidgets('SplashScreen renders EBIC branding, title, and tagline', (tester) async {
      await tester.pumpWidget(createTestWidget(const SplashScreen()));
      await tester.pump();

      expect(find.text('EBIC'), findsOneWidget);
      expect(find.text('EVERY BITE COUNTS'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('OnboardingScreen renders multi-step slides with Next and Skip buttons', (tester) async {
      await tester.pumpWidget(createTestWidget(const OnboardingScreen()));
      await tester.pump();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('PERSONALIZED NUTRITION'), findsOneWidget);
      expect(find.textContaining('Dietitian Care Tailored to You'), findsOneWidget);

      // Advance to slide 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('IN-HOME CHEFS'), findsOneWidget);
      expect(find.textContaining('Freshly Cooked in Your Kitchen'), findsOneWidget);
    });
  });

  group('Module 2 — Section 71 Widget Tests: OTP Verification Screen', () {
    testWidgets('OtpVerificationScreen renders 6 pin cells and masked phone', (tester) async {
      await tester.pumpWidget(createTestWidget(const OtpVerificationScreen(
        phone: '+919876543210',
        purpose: 'LOGIN',
      )));
      await tester.pump();

      expect(find.text('Verify Phone Number'), findsOneWidget);
      expect(find.textContaining('****'), findsOneWidget);
      // 6 text fields for PIN digits
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Verify & Continue'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen displays registration purpose title', (tester) async {
      await tester.pumpWidget(createTestWidget(const OtpVerificationScreen(
        phone: '+919876543210',
        purpose: 'REGISTRATION',
      )));
      await tester.pump();

      expect(find.text('Verify Registration'), findsOneWidget);
      expect(find.text('Step 2: Verification'), findsOneWidget);
    });
  });
}
