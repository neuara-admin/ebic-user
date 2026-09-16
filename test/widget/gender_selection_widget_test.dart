import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/shared/widgets/gender_selection_widget.dart';

void main() {
  group('GenderSelectionWidget Tests', () {
    testWidgets('renders all 4 gender options and header badge', (tester) async {
      String selected = 'Female';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GenderSelectionWidget(
                  selectedGender: selected,
                  onGenderChanged: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify header and items
      expect(find.text('GENDER / BIOLOGICAL SEX'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsAtLeastNWidgets(1));
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Prefer not to say'), findsOneWidget);

      // Verify active badge checkmark
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap on 'Male' card
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      expect(selected, 'Male');
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('triggers onGenderChanged callback when selecting Other', (tester) async {
      String? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenderSelectionWidget(
              selectedGender: 'Male',
              onGenderChanged: (val) {
                changedTo = val;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      expect(changedTo, 'Other');
    });
  });
}
