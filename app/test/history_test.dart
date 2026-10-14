import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-12 seven bars, today last, and daily totals', (tester) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(9), 900),
            (daysAgo(6), 1200),
            (daysAgo(3), 2100),
            (daysAgo(0, hour: 8), 400),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(Key('bar_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('bar_7')), findsNothing);
    final days = h.state.lastSevenDays;
    expect(days.last.day, DateTime(2026, 10, 14));
    expect(days.first.day, DateTime(2026, 10, 8));
    await tester.scrollUntilVisible(
      find.text('Thu, 8 Oct'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Thu, 8 Oct'), findsOneWidget);
    expect(find.text('1200 ml'), findsOneWidget);
    expect(find.text('2100 ml'), findsOneWidget);
    expect(find.text('Wed, 14 Oct'), findsOneWidget);
    expect(find.text('400 ml'), findsOneWidget);
    // Nine days ago is outside the week.
    expect(find.text('900 ml'), findsNothing);
  });

  testWidgets('AC-13 three met days in a row make a 3-day streak', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(3), 1900),
            (daysAgo(2), 2000),
            (daysAgo(1), 2500),
            (daysAgo(0, hour: 9), 1000),
            (daysAgo(0, hour: 12), 1000),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '3-day streak');
  });

  testWidgets('AC-14 an unfinished today does not break the streak', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(2), 2000),
            (daysAgo(1), 2000),
            (daysAgo(0, hour: 9), 300),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '2-day streak');
    // Missing a whole day does break it.
    h.clock.now = DateTime(2026, 10, 15, 9);
    h.state.refreshDay();
    await tester.pumpAndSettle();
    expect(text(tester, 'streak'), 'No streak yet');
  });

  testWidgets('AC-14 the streak counts days older than the last week', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [for (var i = 1; i <= 10; i++) (daysAgo(i), 2000)],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '10-day streak');
  });

  testWidgets('AC-15 no drinks ever: empty message and no ad', (tester) async {
    final h = await pumpApp(tester);
    await openTab(tester, 'tab_history');
    expect(
      find.text('Your week will show up here once you log a drink.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('streak')), findsNothing);
    expect(find.byKey(const Key('history_banner')), findsNothing);
    expect(h.ads.bannersCreated, 0);
  });

  testWidgets('AC-29 raising the goal does not rewrite past days', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(goals: [(daysAgo(30), 2000)], drinks: [(daysAgo(1), 2000)]),
      ),
    );
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal_dialog_field')), '3000');
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pumpAndSettle();
    expect(h.state.todayGoal, 3000);
    expect(h.state.goalOn(daysAgo(1)), 2000);
    expect(h.state.lastSevenDays[5].met, isTrue);
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '1-day streak');
  });
}
