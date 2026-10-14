import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/units.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-16 changing the goal to 2500 shows on Today', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    expect(find.text('Daily goal'), findsWidgets);
    await tester.enterText(find.byKey(const Key('goal_dialog_field')), '2500');
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pumpAndSettle();
    expect(find.text('2500 ml'), findsOneWidget);
    await openTab(tester, 'tab_today');
    expect(text(tester, 'total'), '0 / 2500 ml');
  });

  testWidgets('AC-30 a goal of 200 ml shows the range and keeps the old', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal_dialog_field')), '200');
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a goal between 500 and 6000 ml'), findsOneWidget);
    expect(find.byKey(const Key('goal_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal_cancel')));
    await tester.pumpAndSettle();
    expect(h.state.todayGoal, 2000);
    await openTab(tester, 'tab_today');
    expect(text(tester, 'total'), '0 / 2000 ml');
  });

  testWidgets('AC-17 switching to fl oz changes amounts and buttons', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 500)],
        ),
      ),
    );
    await openTab(tester, 'tab_settings');
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    expect(h.state.unit, VolumeUnit.oz);
    await openTab(tester, 'tab_today');
    expect(text(tester, 'total'), '17 / 68 fl oz');
    expect(find.text('6 fl oz'), findsOneWidget);
    expect(find.text('8 fl oz'), findsOneWidget);
    expect(find.text('16 fl oz'), findsOneWidget);
    expect(find.text('150 ml'), findsNothing);
  });

  testWidgets('AC-18 Reset deletes everything; Cancel deletes nothing', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 500)],
        ),
      ),
    );
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    expect(find.text('Reset all data?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset_cancel')));
    await tester.pumpAndSettle();
    expect(h.state.hasAnyDrinks, isTrue);
    expect(h.storage.data, isNotNull);

    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_confirm')));
    await tester.pumpAndSettle();
    expect(h.state.hasAnyDrinks, isFalse);
    expect(h.storage.data, isNull);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
  });

  testWidgets('AC-23 Privacy options shows only when required', (tester) async {
    final h = await pumpApp(tester, ads: FakeAds(privacyRequired: false));
    await openTab(tester, 'tab_settings');
    expect(find.text('Privacy options'), findsNothing);
    h.ads.privacyRequired.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Privacy options'), findsOneWidget);
    await tester.tap(find.text('Privacy options'));
    await tester.pumpAndSettle();
    expect(h.ads.privacyShown, 1);
  });
}
