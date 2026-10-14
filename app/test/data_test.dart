import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/storage.dart';
import 'package:glassful/data/units.dart';
import 'package:glassful/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-19 drinks, goal and unit survive a restart', (tester) async {
    var h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    await h.state.setGoal(2400);
    await h.state.setUnit(VolumeUnit.oz);
    await tester.pumpAndSettle();

    h = await restart(tester, h);
    expect(h.state.unit, VolumeUnit.oz);
    expect(h.state.todayGoal, 2400);
    expect(h.state.todayTotal, 250);
    expect(text(tester, 'total'), '8 / 81 fl oz');
  });

  test('AC-19 shared_preferences storage round-trips the app data', () async {
    SharedPreferences.setMockInitialValues({});
    final clock = TestClock(testNow);
    final a = AppState(storage: PrefsStorage(), clock: clock.call);
    await a.load();
    await a.completeOnboarding(goalMl: 1800, unit: VolumeUnit.ml);
    await a.addDrink(300);
    final b = AppState(storage: PrefsStorage(), clock: clock.call);
    await b.load();
    expect(b.onboarded, isTrue);
    expect(b.todayGoal, 1800);
    expect(b.todayTotal, 300);
  });

  testWidgets('AC-20 unreadable data starts fresh with a message', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage('{not json'));
    expect(tester.takeException(), isNull);
    expect(h.state.loadFailed, isTrue);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsOneWidget,
    );
  });

  testWidgets('AC-20 data with the wrong shape also starts fresh', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage('{"onboarded": "yes", "drinks": 3}'),
    );
    expect(h.state.loadFailed, isTrue);
    expect(h.state.hasAnyDrinks, isFalse);
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsOneWidget,
    );
  });
}
