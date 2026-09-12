import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebic_user/core/auth/auth_service.dart';
import 'package:ebic_user/features/profile/widgets/avatar_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().setSessionForTesting(
      user: {
        'id': 'u-101',
        'name': 'Vikram Sethi',
        'phone': '+91 98765 43210',
        'email': 'vikram.sethi@example.com',
      },
      token: 'mock-token',
    );
  });

  group('AvatarPickerSheet Tests', () {
    testWidgets('renders upload options and no remove button when no photo exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarPickerSheet(currentAvatarUrl: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upload Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);

      // Verify "Remove Photo" is not rendered
      expect(find.text('Remove Photo'), findsNothing);

      // Verify presets and custom url input are completely absent
      expect(find.text('Executive Chef'), findsNothing);
      expect(find.text('Culinary Artist'), findsNothing);
      expect(find.text('Enter Custom Image URL'), findsNothing);
    });

    testWidgets('renders replace and remove options when photo already exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarPickerSheet(currentAvatarUrl: 'https://example.com/avatar.jpg'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Replace from Gallery'), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);

      // Verify presets and custom url input are completely absent
      expect(find.text('Executive Chef'), findsNothing);
      expect(find.text('Enter Custom Image URL'), findsNothing);
    });
  });
}
