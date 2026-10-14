// Store screenshots. The factory runs this on an Android emulator with
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart
// Each takeScreenshot name must match an "id" in store/listing.json "screenshots".
//
// The app runs with a believable week of sample data on an in-memory store,
// with ads off so no test banner appears in the store images.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/main.dart';
import 'package:glassful/state/app_state.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final real = DateTime.now();
    final now = DateTime(real.year, real.month, real.day, 16, 40);
    DateTime at(int daysAgo, int hour, int minute) =>
        DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

    // A believable week: goal met five days in a row, today in progress.
    const day = [
      (7, 50, 250.0),
      (10, 15, 500.0),
      (13, 5, 330.0),
      (16, 30, 500.0),
      (19, 45, 250.0),
    ];
    final extraByDay = {
      6: 0.0,
      5: 250.0,
      4: 400.0,
      3: 500.0,
      2: 250.0,
      1: 330.0,
    };
    final week = <(DateTime, double)>[
      for (final MapEntry(key: d, value: extra) in extraByDay.entries) ...[
        for (final (h, m, ml) in day) (at(d, h, m), ml),
        if (extra > 0) (at(d, 21, 10), extra),
      ],
      (at(0, 7, 45), 250),
      (at(0, 9, 30), 500),
      (at(0, 12, 15), 330),
      (at(0, 15, 50), 250),
    ];
    final storage = MemoryStorage(
      savedJson(goals: [(at(30, 9, 0), 2000)], drinks: week),
    );
    final state = AppState(storage: storage, clock: () => now);
    await tester.pumpWidget(
      GlassfulApp(state: state, ads: FakeAds(canRequest: false)),
    );
    await state.load();
    await tester.pumpAndSettle();
    // Required once on Android before the first screenshot.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    await binding.takeScreenshot('today');

    await tester.tap(find.byKey(const Key('tab_history')));
    await tester.pumpAndSettle();
    await clearTapMarkers(tester);
    await binding.takeScreenshot('history');

    await tester.tap(find.byKey(const Key('tab_today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_field')), '330');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await clearTapMarkers(tester);
    await binding.takeScreenshot('custom_amount');

    expect(find.byKey(const Key('custom_dialog')), findsOneWidget);
  });
}

/// The live test binding draws a crosshair where the test tapped and fades
/// it out over a few frames. Pump frames until it is gone.
Future<void> clearTapMarkers(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
