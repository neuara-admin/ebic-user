import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/shared/widgets/ebic_button.dart';
import 'package:ebic_user/shared/widgets/ebic_outlined_button.dart';
import 'package:ebic_user/shared/widgets/ebic_text_button.dart';
import 'package:ebic_user/shared/widgets/ebic_text_field.dart';
import 'package:ebic_user/shared/widgets/ebic_badge.dart';
import 'package:ebic_user/shared/widgets/status_badge.dart';
import 'package:ebic_user/shared/widgets/loading_view.dart';
import 'package:ebic_user/shared/widgets/error_view.dart';
import 'package:ebic_user/shared/widgets/empty_state_view.dart';
import 'package:ebic_user/shared/widgets/ebic_price_summary.dart';

void main() {
  group('Module 1: Core Design Components (Section 6.2)', () {
    testWidgets('EBICButton renders label and triggers click callback', (WidgetTester tester) async {
      bool clicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EBICButton(
              label: 'Book Instant Chef',
              onPressed: () => clicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Book Instant Chef'), findsOneWidget);
      await tester.tap(find.text('Book Instant Chef'));
      await tester.pump();
      expect(clicked, isTrue);
    });

    testWidgets('EBICOutlinedButton renders properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EBICOutlinedButton(
              label: 'Secondary Action',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secondary Action'), findsOneWidget);
    });

    testWidgets('EBICTextButton renders label with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EBICTextButton(
              label: 'View All',
              icon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('View All'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('EBICTextField displays label, hint, and error text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EBICTextField(
              label: 'Mobile Number',
              hintText: '9876543210',
              errorText: 'Invalid phone number',
            ),
          ),
        ),
      );

      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Invalid phone number'), findsOneWidget);
    });

    testWidgets('EBICPriceSummary formats subtotal, tax, discount, and grand total', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EBICPriceSummary(
              currency: 'INR',
              subtotal: 1000,
              discount: 100,
              tax: 162,
              grandTotal: 1062,
            ),
          ),
        ),
      );

      expect(find.text('Payment Summary'), findsOneWidget);
      expect(find.text('Item Subtotal'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(find.text('₹1,062'), findsOneWidget);
    });

    testWidgets('StatusBadge and EBICBadge render with appropriate tags', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EBICStatusBadge(status: 'COOKING'),
                EBICBadge.counter(5),
                EBICBadge.pill('VEGAN'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('COOKING'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('VEGAN'), findsOneWidget);
    });

    testWidgets('Global UI State widgets render cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const EBICLoader.spinner(message: 'Preparing menu...'),
                EBICEmptyView.noOrders(),
                EBICErrorView(message: 'Could not connect to server', onRetry: () {}),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Preparing menu...'), findsOneWidget);
      expect(find.text('No Orders'), findsOneWidget);
      expect(find.text('Could not connect to server'), findsOneWidget);
    });
  });
}
