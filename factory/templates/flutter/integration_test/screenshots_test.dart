// Store screenshots. The factory runs this on an Android emulator with
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart
// Each takeScreenshot name must match an "id" in store/listing.json "screenshots".
//
// The app coder replaces the body of the test: launch the app with realistic
// sample data (never lorem ipsum), navigate to each screen and take one shot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    // Required once on Android before the first screenshot.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await binding.takeScreenshot('home');
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
