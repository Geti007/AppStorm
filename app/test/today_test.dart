import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/units.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-4 tapping 250 ml adds to the total and the log', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '250 / 2000 ml');
    expect(h.state.todayDrinks, hasLength(1));
    expect(find.byKey(const Key('drink_1')), findsOneWidget);
    expect(find.text('Added 250 ml'), findsOneWidget);
  });

  testWidgets('AC-5 shows 1000 / 2000 ml and 50%', (tester) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 500), (daysAgo(0, hour: 11), 500)],
        ),
      ),
    );
    expect(text(tester, 'total'), '1000 / 2000 ml');
    expect(text(tester, 'percent'), '50%');
    expect(find.byKey(const Key('goal_reached')), findsNothing);
  });

  testWidgets('AC-6 a custom 330 ml is added', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    expect(find.text('Custom amount'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('custom_field')), '330');
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom_add')));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, 330);
    expect(text(tester, 'total'), '330 / 2000 ml');
  });

  testWidgets('AC-7 Add is disabled for empty, 0 or too much', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    expect(find.text('1 to 2000 ml'), findsOneWidget);
    FilledButton add() =>
        tester.widget<FilledButton>(find.byKey(const Key('custom_add')));
    expect(add().onPressed, isNull);
    for (final bad in ['0', '2001', '']) {
      await tester.enterText(find.byKey(const Key('custom_field')), bad);
      await tester.pump();
      expect(add().onPressed, isNull, reason: bad);
    }
    await tester.enterText(find.byKey(const Key('custom_field')), '2000');
    await tester.pump();
    expect(add().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, 0);
  });

  testWidgets('AC-8 Undo removes the drink just added', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, 500);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, 0);
    expect(text(tester, 'total'), '0 / 2000 ml');
    expect(h.storage.json['drinks'], isEmpty);
  });

  testWidgets('AC-9 deleting an entry updates the total', (tester) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 250), (daysAgo(0, hour: 11), 500)],
        ),
      ),
    );
    expect(text(tester, 'total'), '750 / 2000 ml');
    await tester.tap(find.byKey(const Key('delete_2')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '250 / 2000 ml');
    expect(find.byKey(const Key('drink_2')), findsNothing);
    expect(h.state.todayDrinks.single.ml, 250);
  });

  testWidgets('AC-10 reaching the goal shows Goal reached, ring stays full', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 1500)],
        ),
      ),
    );
    expect(find.byKey(const Key('goal_reached')), findsNothing);
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(find.text('Goal reached'), findsOneWidget);
    expect(text(tester, 'percent'), '100%');
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(text(tester, 'percent'), '125%');
    expect(find.text('Goal reached'), findsOneWidget);
  });

  testWidgets('AC-11 empty day shows the empty message', (tester) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(goals: [(daysAgo(5), 2000)], drinks: [(daysAgo(1), 800)]),
      ),
    );
    expect(
      find.text('No drinks yet today. Tap a glass to start.'),
      findsOneWidget,
    );
    expect(text(tester, 'percent'), '0%');
    expect(text(tester, 'total'), '0 / 2000 ml');
  });

  testWidgets('AC-27 eight 8 fl oz drinks meet a 64 fl oz goal', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          unit: VolumeUnit.oz,
          goals: [(daysAgo(5), VolumeUnit.oz.toMl(64))],
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('add_237')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '64 / 64 fl oz');
    expect(text(tester, 'percent'), '100%');
    expect(find.text('Goal reached'), findsOneWidget);
  });

  testWidgets('AC-28 after midnight Today starts at 0 and History keeps it', (
    tester,
  ) async {
    final clock = TestClock(DateTime(2026, 10, 13, 23, 30));
    final h = await pumpApp(tester, clock: clock);
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '500 / 2000 ml');

    clock.now = DateTime(2026, 10, 14, 7);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '0 / 2000 ml');
    expect(
      find.text('No drinks yet today. Tap a glass to start.'),
      findsOneWidget,
    );
    await openTab(tester, 'tab_history');
    expect(h.state.lastSevenDays[5].ml, 500);
    expect(find.text('Tue, 13 Oct'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
  });
}
