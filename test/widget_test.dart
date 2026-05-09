import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/ui/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PickupApp());
    expect(find.text('待取件'), findsOneWidget);
  });
}