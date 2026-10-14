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

    final week = <(DateTime, double)>[
      for (final (day, extra) in [(6, 0), (5, 250), (4, 150), (3, 500)]) ...[
        (at(day, 7, 50), 250.0),
        (at(day, 10, 15), 500.0),
        (at(day, 13, 5), 330.0),
        (at(day, 16, 30), 500.0),
        (at(day, 19, 45), 250.0 + extra),
      ],
      (at(2, 8, 10), 250),
      (at(2, 12, 40), 500),
      (at(2, 18, 20), 330),
      for (final day in [1]) ...[
        (at(day, 7, 30), 250.0),
        (at(day, 9, 55), 500.0),
        (at(day, 12, 20), 330.0),
        (at(day, 15, 10), 500.0),
        (at(day, 18, 0), 250.0),
        (at(day, 21, 15), 250.0),
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
    await binding.takeScreenshot('history');

    await tester.tap(find.byKey(const Key('tab_today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_field')), '330');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('custom_amount');

    expect(find.byKey(const Key('custom_dialog')), findsOneWidget);
  });
}
