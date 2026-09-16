import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/shared/widgets/clinical_notes_input_widget.dart';

void main() {
  group('ClinicalNotesInputWidget Tests', () {
    testWidgets('renders title, subtitle, text field, and quick suggestions', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClinicalNotesInputWidget(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify title and subtitle
      expect(find.text('Clinical Notes & Dietitian Instructions'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      // Verify quick chips
      expect(find.text('Low sodium'), findsOneWidget);
      expect(find.text('Mild spice only'), findsOneWidget);
      expect(find.text('No onion / garlic'), findsOneWidget);

      // Tap on 'Low sodium' chip
      await tester.tap(find.text('Low sodium'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Low sodium');

      // Tap on 'Mild spice only' chip to append
      await tester.tap(find.text('Mild spice only'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Low sodium, Mild spice only');
    });

    testWidgets('allows manual typing in text area', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClinicalNotesInputWidget(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Recovering from knee surgery, gluten sensitive');
      await tester.pumpAndSettle();

      expect(controller.text, 'Recovering from knee surgery, gluten sensitive');
    });
  });
}
