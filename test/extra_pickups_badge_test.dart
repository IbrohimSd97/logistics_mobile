import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/orders/extra_pickups_badge.dart';

void main() {
  testWidgets('shows +N extra pickups', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExtraPickupsBadge(count: 2))));
    expect(find.textContaining('2'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_rounded), findsOneWidget);
  });
}
