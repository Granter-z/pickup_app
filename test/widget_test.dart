import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickup_app/ui/app.dart';
import 'helpers/test_hive_helper.dart';

void main() {
  setUpAll(() async {
    await TestHiveHelper.init();
    await TestHiveHelper.resetBox();
  });

  tearDownAll(() async {
    await TestHiveHelper.cleanup();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PickupApp()),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
