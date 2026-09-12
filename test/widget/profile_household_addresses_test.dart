import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebic_user/core/auth/auth_service.dart';
import 'package:ebic_user/core/context/member_context.dart';
import 'package:ebic_user/features/profile/profile_screen.dart';
import 'package:ebic_user/features/profile/edit_profile_screen.dart';
import 'package:ebic_user/features/profile/household_screen.dart';
import 'package:ebic_user/features/profile/preferences_screen.dart';
import 'package:ebic_user/shared/models/household_member_model.dart';
import 'package:ebic_user/features/profile/addresses_screen.dart';
import 'package:ebic_user/features/profile/address_form_screen.dart';
import 'package:ebic_user/shared/widgets/member_switcher_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSelf = HouseholdMemberModel(
    id: 'mem-1',
    name: 'Vikram Sethi',
    relationship: 'SELF',
    isSelf: true,
    isCoveredByHealthPass: true,
    dateOfBirth: '1990-01-01',
  );

  final mockSpouse = HouseholdMemberModel(
    id: 'mem-2',
    name: 'Neha Sethi',
    relationship: 'SPOUSE',
    isSelf: false,
    isCoveredByHealthPass: true,
    dateOfBirth: '1992-04-12',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().setSessionForTesting(
      user: {
        'id': 'u-101',
        'name': 'Vikram Sethi',
        'phone': '+91 98765 43210',
        'email': 'vikram.sethi@example.com',
        'phoneVerified': true,
        'emailVerified': true,
      },
      token: 'mock-token',
    );
    MemberContext().setMembersForTesting([mockSelf, mockSpouse]);
  });

  group('Module 3 — Widget Tests: Profile & Personal Info (Sections 23 & 24)', () {
    testWidgets('ProfileScreen renders profile header, verification chips and switcher', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account & Profile'), findsOneWidget);
      expect(find.text('Vikram Sethi'), findsAtLeastNWidgets(1));
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('PHONE VERIFIED'), findsOneWidget);
      expect(find.text('EMAIL VERIFIED'), findsOneWidget);

      // Verify MemberSwitcherBar is present
      expect(find.byType(MemberSwitcherBar), findsOneWidget);
      expect(find.text('ACTIVE HOUSEHOLD MEMBER'), findsOneWidget);

      // Verify section menu items
      expect(find.text('Household & Family Members'), findsOneWidget);
      expect(find.text('Saved Kitchen Addresses'), findsOneWidget);
      expect(find.text('Preferences & Language'), findsOneWidget);
      expect(find.text('Logout of EBIC'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders EMAIL UNVERIFIED — TAP TO VERIFY when email is unverified', (tester) async {
      AuthService().setSessionForTesting(
        user: {
          'id': 'u-103',
          'name': 'Pooja Nair',
          'phone': '+91 91234 56789',
          'email': 'pooja.nair@example.com',
          'phoneVerified': true,
          'emailVerified': false,
        },
        token: 'mock-token-3',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Pooja Nair'), findsAtLeastNWidgets(1));
      expect(find.text('pooja.nair@example.com'), findsOneWidget);
      expect(find.text('EMAIL UNVERIFIED — TAP TO VERIFY'), findsOneWidget);
      expect(find.text('EMAIL VERIFIED'), findsNothing);
    });

    testWidgets('ProfileScreen renders Add your name and ADD EMAIL when profile is incomplete', (tester) async {
      AuthService().setSessionForTesting(
        user: {
          'id': 'u-102',
          'name': null,
          'phone': '+91 99887 76655',
          'email': null,
          'phoneVerified': true,
          'emailVerified': false,
        },
        token: 'mock-token-2',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Add your name'), findsOneWidget);
      expect(find.text('No email address added'), findsOneWidget);
      expect(find.text('+91 99887 76655'), findsOneWidget);
      expect(find.text('PHONE VERIFIED'), findsOneWidget);
      expect(find.text('ADD EMAIL'), findsOneWidget);
      expect(find.text('EMAIL VERIFIED'), findsNothing);
    });

    testWidgets('EditProfileScreen renders editable fields and verified phone card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Account Profile'), findsOneWidget);
      expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
      expect(find.text('Full Legal Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('AUTHENTICATION & PHONE'), findsOneWidget);
      expect(find.text('Save Profile Changes'), findsOneWidget);
    });
  });

  group('Module 3 — Widget Tests: Household Management (Sections 25–28)', () {
    testWidgets('HouseholdScreen renders member cards with active badge and Add FAB', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HouseholdScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Household & Members'), findsOneWidget);
      expect(find.text('Vikram Sethi'), findsOneWidget);
      expect(find.text('Neha Sethi'), findsOneWidget);
      expect(find.text('ACTIVE MEMBER'), findsOneWidget);
      expect(find.text('Health Pass Covered'), findsAtLeastNWidgets(1));
      expect(find.text('Add Member'), findsOneWidget);
    });

    testWidgets('MemberSwitcherBar opens modal sheet and switches active member', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MemberSwitcherBar()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vikram Sethi'), findsOneWidget);

      // Tap to open bottom sheet
      await tester.tap(find.byType(MemberSwitcherBar));
      await tester.pumpAndSettle();

      expect(find.text('Switch Active Member'), findsOneWidget);
      expect(find.text('Manage Household Members'), findsOneWidget);

      // Select Neha Sethi
      await tester.tap(find.text('Neha Sethi'));
      await tester.pumpAndSettle();

      // Context now reflects Neha Sethi
      expect(MemberContext().selectedMemberId, equals('mem-2'));
      expect(find.text('Neha Sethi'), findsOneWidget);
    });
  });

  group('Module 3 — Widget Tests: Preferences (Section 32)', () {
    testWidgets('PreferencesScreen renders language radio tiles and notification switches', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PreferencesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer Preferences'), findsOneWidget);
      expect(find.text('PREFERRED LANGUAGE'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Telugu'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);

      expect(find.text('COMMUNICATION CHANNELS'), findsOneWidget);
      expect(find.text('WhatsApp Updates'), findsOneWidget);
      expect(find.text('SMS Notifications'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Email Receipts & Reports'), findsOneWidget);
    });
  });

  group('Module 3 — Widget Tests: Kitchen Addresses & Map Pinpoint (Sections 29–31)', () {
    testWidgets('AddressFormScreen renders map pinpoint section, kitchen types, and contact fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddressFormScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Kitchen Address'), findsOneWidget);
      expect(find.text('EXACT KITCHEN PINPOINT (MAP LOCATION)'), findsOneWidget);
      expect(find.text('Pick on Map'), findsOneWidget);

      // Verify clean Home and Other address types
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Verify NO office/work types
      expect(find.text('Work'), findsNothing);
      expect(find.text('Office'), findsNothing);

      // Tap 'Other' to reveal custom label and suggestions
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Label Name'), findsOneWidget);
      expect(find.text("Parents' Home"), findsOneWidget);
      expect(find.text('Villa'), findsOneWidget);
      expect(find.text('Farmhouse'), findsOneWidget);

      // Verify kitchen contact section
      expect(find.text('KITCHEN CONTACT ON CHEF ARRIVAL'), findsOneWidget);
      expect(find.text('Set as Primary Cooking Kitchen'), findsOneWidget);
    });

    testWidgets('AddressesScreen renders empty state when no addresses exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddressesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved Kitchen Addresses'), findsOneWidget);
      expect(find.text('No saved kitchen addresses'), findsOneWidget);
      expect(find.text('Add Kitchen Address'), findsOneWidget);
    });
  });
}
