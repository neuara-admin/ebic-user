import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebic_user/main.dart';
import 'package:ebic_user/shared/widgets/ebic_button.dart';
import 'package:ebic_user/shared/widgets/status_badge.dart';
import 'package:ebic_user/shared/models/dish_model.dart';
import 'package:ebic_user/shared/models/order_model.dart';

import 'package:ebic_user/core/routing/app_routes.dart';

void main() {
  testWidgets('EBIC App launches and renders root app widget', (WidgetTester tester) async {
    await tester.pumpWidget(const EbicCustomerApp(initialRoute: AppRoutes.welcome));
    expect(find.byType(EbicCustomerApp), findsOneWidget);
    expect(find.text('Get Started with Phone / OTP'), findsOneWidget);
  });

  testWidgets('EbicButton renders properly with label and variant', (WidgetTester tester) async {
    bool clicked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EbicButton(
            label: 'Book a Chef',
            variant: EbicButtonVariant.primary,
            onPressed: () => clicked = true,
          ),
        ),
      ),
    );

    expect(find.text('Book a Chef'), findsOneWidget);
    await tester.tap(find.text('Book a Chef'));
    await tester.pump();
    expect(clicked, isTrue);
  });

  testWidgets('StatusBadge formats status text cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: 'CHEF_EN_ROUTE'),
        ),
      ),
    );

    expect(find.text('CHEF EN ROUTE'), findsOneWidget);
  });

  test('DishModel and OrderModel parse and expose properties', () {
    final dish = DishModel(
      id: 'dish-1',
      name: 'Herb Grilled Chicken',
      category: 'HIGH_PROTEIN',
      baseCookTimeMin: 25,
    );
    expect(dish.name, 'Herb Grilled Chicken');
    expect(dish.cookTimeMinutes, 25);
    expect(dish.basePrice, 249.0);

    final order = OrderModel(
      id: 'order-12345678',
      orderType: 'INSTANT',
      bookingOption: 'L',
      status: 'CONFIRMED',
      visitCookTimeMin: 35,
      priceSubtotal: 500,
      priceGst: 25,
      priceTotal: 525,
      createdAt: DateTime.now(),
    );
    expect(order.bookingReference, 'EBIC-ORDE');
    expect(order.cookingTimeMinutes, 35);
    expect(order.totalAmount, 525);
  });
}
