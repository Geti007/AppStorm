// Edge cases written by the independent tester: double taps, restarts
// mid-flow, midnight, large text, small and rotated screens, dark mode,
// storage failures and ad behaviour with a fake ad service.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/storage.dart';
import 'package:glassful/data/units.dart';
import 'package:glassful/main.dart';
import 'package:glassful/services/ads.dart';
import 'package:glassful/state/app_state.dart';
import 'package:glassful/widgets/progress_ring.dart';

import 'support/fakes.dart';

/// Storage whose first read waits until the test releases it.
class SlowStorage extends MemoryStorage {
  SlowStorage([super.data]);

  final gate = Completer<void>();

  @override
  Future<String?> read() async {
    await gate.future;
    return data;
  }
}

/// Storage that cannot be read at all.
class BrokenReadStorage extends MemoryStorage {
  @override
  Future<String?> read() async => throw const FileSystemException('denied');
}

/// Storage whose writes always fail (disk full).
class FullDiskStorage extends MemoryStorage {
  FullDiskStorage([super.data]);

  @override
  Future<void> write(String d) async =>
      throw const FileSystemException('no space');
}

MemoryStorage seededWeek() => MemoryStorage(
  savedJson(
    goals: [(daysAgo(30), 2000)],
    drinks: [
      for (var i = 1; i < 7; i++) (daysAgo(i), 1500.0 + i * 100),
      (daysAgo(0, hour: 9), 250),
    ],
  ),
);

MemoryStorage goalMetToday() => MemoryStorage(
  savedJson(
    goals: [(daysAgo(30), 2000)],
    drinks: [(daysAgo(1), 2000), (daysAgo(0, hour: 9), 2500)],
  ),
);

double ringTarget(WidgetTester tester) {
  final tween = tester.widget<TweenAnimationBuilder<double>>(
    find.descendant(
      of: find.byType(ProgressRing),
      matching: find.byType(TweenAnimationBuilder<double>),
    ),
  );
  return tween.tween.end!;
}

double barHeight(WidgetTester tester, int i) => tester
    .widget<TweenAnimationBuilder<double>>(find.byKey(Key('bar_$i')))
    .tween
    .end!;

void smallBigText(WidgetTester tester, {bool landscape = false}) {
  tester.view.physicalSize = landscape
      ? const Size(568, 320)
      : const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void darkMode(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

Future<void> tapVisible(WidgetTester tester, String key) async {
  // Today, History and Settings build their lists lazily.
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: list.hitTestable().first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  // ------------------------------------------------------------ onboarding

  testWidgets('AC-2 double tap on Start tracking saves one goal', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.tap(
      find.byKey(const Key('start_button')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('today')), findsOneWidget);
    expect(h.storage.json['goals'], hasLength(1));
    expect(h.storage.json['onboarded'], isTrue);
  });

  testWidgets('AC-2 restart in the middle of onboarding starts it again', (
    tester,
  ) async {
    var h = await pumpApp(tester, storage: MemoryStorage());
    await tester.enterText(find.byKey(const Key('goal_field')), '2500');
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    h = await restart(tester, h);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('goal_field')));
    expect(field.controller!.text, '2000');
    expect(h.state.onboarded, isFalse);
  });

  testWidgets('AC-3 a 25-digit goal is rejected, not crashed on', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.enterText(
      find.byKey(const Key('goal_field')),
      '9999999999999999999999999',
    );
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Enter a goal between 500 and 6000 ml'), findsOneWidget);
    expect(h.state.onboarded, isFalse);
    // The lower and upper limits themselves are accepted.
    await tester.enterText(find.byKey(const Key('goal_field')), '500');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(h.state.todayGoal, 500);
  });

  testWidgets('AC-26 ounce limits 17 and 202 are accepted, 203 is not', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    for (final bad in ['16', '203', '']) {
      await tester.enterText(find.byKey(const Key('goal_field')), bad);
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a goal between 17 and 202 fl oz'),
        findsOneWidget,
        reason: bad,
      );
    }
    await tester.enterText(find.byKey(const Key('goal_field')), '202');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(h.state.unit, VolumeUnit.oz);
    expect(h.state.todayGoal, closeTo(202 * mlPerOz, 1e-9));
    expect(text(tester, 'total'), '0 / 202 fl oz');
  });

  // ------------------------------------------------------------ today

  testWidgets('AC-4 two fast taps on 250 ml log two drinks of 250', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(h.state.todayDrinks, hasLength(2));
    expect(text(tester, 'total'), '500 / 2000 ml');
    expect(h.storage.json['drinks'], hasLength(2));
  });

  testWidgets('AC-5 ring is half full and its label is spoken', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 1000)],
        ),
      ),
    );
    expect(ringTarget(tester), 0.5);
    expect(
      find.bySemanticsLabel('1000 of 2000 millilitres, 50 percent'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('AC-6 double tap on Add logs the custom amount once', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_field')), '330');
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom_add')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('custom_add')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.state.todayDrinks, hasLength(1));
    expect(h.state.todayTotal, 330);
    expect(find.byKey(const Key('today')), findsOneWidget);
  });

  testWidgets('AC-6 Cancel adds nothing; custom in fl oz stores exact ml', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(unit: VolumeUnit.oz, goals: [(daysAgo(5), 2000)]),
      ),
    );
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_field')), '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    expect(h.state.hasAnyDrinks, isFalse);

    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    expect(find.text('1 to 67 fl oz'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('custom_field')), '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom_add')));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, closeTo(12 * mlPerOz, 1e-9));
    expect(text(tester, 'total'), '12 / 68 fl oz');
  });

  testWidgets('AC-7 limits: 1 and 2000 ml allowed; 25 digits disabled', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    FilledButton add() =>
        tester.widget<FilledButton>(find.byKey(const Key('custom_add')));
    for (final ok in ['1', '2000']) {
      await tester.enterText(find.byKey(const Key('custom_field')), ok);
      await tester.pump();
      expect(add().onPressed, isNotNull, reason: ok);
    }
    for (final bad in ['9999999999999999999999999', '000', '2001']) {
      await tester.enterText(find.byKey(const Key('custom_field')), bad);
      await tester.pump();
      expect(add().onPressed, isNull, reason: bad);
      expect(find.text('1 to 2000 ml'), findsOneWidget);
    }
    // Submitting from the keyboard with an invalid value adds nothing.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom_dialog')), findsOneWidget);
  });

  testWidgets('AC-7 fl oz: 67 allowed, 68 disabled', (tester) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(unit: VolumeUnit.oz, goals: [(daysAgo(5), 2000)]),
      ),
    );
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    FilledButton add() =>
        tester.widget<FilledButton>(find.byKey(const Key('custom_add')));
    await tester.enterText(find.byKey(const Key('custom_field')), '67');
    await tester.pump();
    expect(add().onPressed, isNotNull);
    await tester.enterText(find.byKey(const Key('custom_field')), '68');
    await tester.pump();
    expect(add().onPressed, isNull);
  });

  testWidgets('AC-8 Undo after two drinks removes only the last one', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Undo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.state.todayTotal, 250);
    expect(text(tester, 'total'), '250 / 2000 ml');
    expect(h.storage.json['drinks'], hasLength(1));
  });

  testWidgets('AC-8 the Undo snackbar goes away on its own', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('added_snackbar')), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(h.state.todayTotal, 250);
  });

  testWidgets('AC-22 the Undo snackbar never sits over the History banner', (
    tester,
  ) async {
    await pumpApp(tester, storage: seededWeek());
    await tester.tap(find.byKey(const Key('add_150')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_history');
    // Straight after switching tabs, and once things have settled.
    for (final wait in [Duration.zero, const Duration(seconds: 10)]) {
      await tester.pump(wait);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_banner')), findsOneWidget);
      final banner = tester.getRect(find.byKey(const Key('history_banner')));
      for (final e in find.byType(SnackBar).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(r.overlaps(banner), isFalse, reason: '$wait');
      }
    }
  });

  testWidgets('AC-8 Undo after the drink was deleted does nothing harmful', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_1')));
    await tester.pumpAndSettle();
    expect(h.state.todayTotal, 0);
    if (find.text('Undo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(h.state.todayTotal, 0);
    await tester.tap(find.byKey(const Key('add_150')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '150 / 2000 ml');
  });

  testWidgets('AC-9 double tap on delete removes one entry only', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 250), (daysAgo(0, hour: 11), 500)],
        ),
      ),
    );
    final spot = tester.getCenter(find.byKey(const Key('delete_2')));
    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(spot);
    await tester.pumpAndSettle();
    expect(h.state.todayDrinks.single.id, 1);
    expect(text(tester, 'total'), '250 / 2000 ml');
    expect(find.byKey(const Key('delete_1')), findsOneWidget);
    // A deliberate second delete a moment later works.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.byKey(const Key('delete_1')));
    await tester.pumpAndSettle();
    expect(h.state.todayDrinks, isEmpty);
    expect(text(tester, 'total'), '0 / 2000 ml');
  });

  testWidgets('AC-10 the ring is full and never above 100% past the goal', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: goalMetToday());
    expect(h.state.todayTotal, 2500);
    expect(find.text('Goal reached'), findsOneWidget);
    expect(ringTarget(tester), 1.0);
  });

  testWidgets('AC-10 within 0.5 ml of the goal counts as reached', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 1999.6)],
        ),
      ),
    );
    expect(find.text('Goal reached'), findsOneWidget);
    expect(text(tester, 'percent'), '100%');
  });

  testWidgets('AC-10 1999 ml of a 2000 ml goal is not reached', (tester) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 1999)],
        ),
      ),
    );
    expect(find.text('Goal reached'), findsNothing);
    expect(ringTarget(tester), lessThan(1.0));
  });

  testWidgets('AC-11 deleting the last drink brings back the empty message', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_empty')), findsNothing);
    await tester.tap(find.byKey(const Key('delete_1')));
    await tester.pumpAndSettle();
    expect(
      find.text('No drinks yet today. Tap a glass to start.'),
      findsOneWidget,
    );
    expect(ringTarget(tester), 0);
  });

  testWidgets('AC-27 full flow: onboard at 64 fl oz, tap 8 fl oz 8 times', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal_field')), '64');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('add_237')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expect(h.state.todayDrinks, hasLength(8));
    expect(text(tester, 'total'), '64 / 64 fl oz');
    expect(find.text('Goal reached'), findsOneWidget);
    // And it is still met after a restart.
    await restart(tester, h);
    expect(text(tester, 'total'), '64 / 64 fl oz');
    expect(find.text('Goal reached'), findsOneWidget);
  });

  testWidgets('AC-27 three 6 fl oz drinks show 18 fl oz, not 17 or 19', (
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
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('add_177')));
      await tester.pumpAndSettle();
    }
    expect(text(tester, 'total'), '18 / 64 fl oz');
  });

  testWidgets('AC-28 midnight passes while the app stays open', (tester) async {
    final clock = TestClock(DateTime(2026, 10, 13, 23, 59, 30));
    final h = await pumpApp(tester, clock: clock);
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '500 / 2000 ml');
    expect(find.text('Tuesday, 13 October'), findsOneWidget);

    clock.now = DateTime(2026, 10, 14, 0, 0, 5);
    await tester.pump(const Duration(seconds: 32));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '0 / 2000 ml');
    expect(find.byKey(const Key('today_empty')), findsOneWidget);
    expect(find.text('Wednesday, 14 October'), findsOneWidget);
    await openTab(tester, 'tab_history');
    expect(h.state.lastSevenDays[5].ml, 500);
    expect(h.state.lastSevenDays[6].ml, 0);
  });

  testWidgets('AC-28 opening the app the next morning starts at 0', (
    tester,
  ) async {
    final clock = TestClock(DateTime(2026, 10, 13, 22));
    var h = await pumpApp(tester, clock: clock);
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    clock.now = DateTime(2026, 10, 14, 6);
    h = await restart(tester, h);
    expect(text(tester, 'total'), '0 / 2000 ml');
    expect(find.byKey(const Key('today_empty')), findsOneWidget);
    await openTab(tester, 'tab_history');
    expect(find.text('Tue, 13 Oct'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
  });

  // ------------------------------------------------------------ history

  testWidgets('AC-12 bars are proportional and today is the last bar', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(6), 1000),
            (daysAgo(3), 4000),
            (daysAgo(0, hour: 8), 500),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    // Tallest is 4000 ml (three days ago, bar 3).
    expect(barHeight(tester, 3), greaterThan(barHeight(tester, 0)));
    expect(barHeight(tester, 0), closeTo(barHeight(tester, 3) / 4, 0.01));
    expect(barHeight(tester, 6), closeTo(barHeight(tester, 3) / 8, 0.01));
    expect(barHeight(tester, 1), 0);
    final last = tester.getRect(find.byKey(const Key('bar_6')));
    final first = tester.getRect(find.byKey(const Key('bar_0')));
    expect(last.left, greaterThan(first.left));
  });

  testWidgets('AC-12 only old drinks: 7 empty bars, not the empty state', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(goals: [(daysAgo(30), 2000)], drinks: [(daysAgo(20), 900)]),
      ),
    );
    await openTab(tester, 'tab_history');
    for (var i = 0; i < 7; i++) {
      expect(barHeight(tester, i), 0);
    }
    expect(find.byKey(const Key('history_empty')), findsNothing);
    expect(text(tester, 'streak'), 'No streak yet');
  });

  testWidgets('AC-13 a met today with an unmet yesterday is a 1-day streak', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(2), 2000),
            (daysAgo(1), 1000),
            (daysAgo(0, hour: 9), 2000),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '1-day streak');
  });

  testWidgets('AC-13 streak grows live when today reaches the goal', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [
            (daysAgo(3), 500),
            (daysAgo(2), 2000),
            (daysAgo(1), 2000),
            (daysAgo(0, hour: 9), 1500),
          ],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '2-day streak');
    await openTab(tester, 'tab_today');
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '3-day streak');
  });

  testWidgets('AC-14 nothing met yesterday or today shows No streak yet', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [(daysAgo(2), 2500), (daysAgo(0, hour: 9), 100)],
        ),
      ),
    );
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), 'No streak yet');
  });

  testWidgets('AC-15 deleting every drink brings back the empty History', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_1')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_history');
    expect(
      find.text('Your week will show up here once you log a drink.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bar_0')), findsNothing);
    expect(find.byKey(const Key('history_banner')), findsNothing);
    expect(h.ads.bannersCreated, 0);
  });

  testWidgets('AC-29 lowering the goal does not make past days met', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(30), 2000)],
          drinks: [(daysAgo(1), 1500), (daysAgo(0, hour: 9), 1500)],
        ),
      ),
    );
    await h.state.setGoal(1000);
    await h.state.setGoal(1200);
    await tester.pumpAndSettle();
    expect(h.state.goalOn(daysAgo(1)), 2000);
    expect(h.state.todayGoal, 1200);
    expect(h.state.lastSevenDays[5].met, isFalse);
    expect(h.state.lastSevenDays[6].met, isTrue);
    expect(h.storage.json['goals'], hasLength(2));
    await openTab(tester, 'tab_history');
    expect(text(tester, 'streak'), '1-day streak');
  });

  testWidgets('AC-29 the past goal survives a restart and midnight', (
    tester,
  ) async {
    var h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(goals: [(daysAgo(30), 2000)], drinks: [(daysAgo(1), 2000)]),
      ),
    );
    await h.state.setGoal(3000);
    h.clock.now = DateTime(2026, 10, 15, 9);
    h = await restart(tester, h);
    expect(h.state.goalOn(DateTime(2026, 10, 13)), 2000);
    expect(h.state.goalOn(DateTime(2026, 10, 14)), 3000);
    expect(h.state.todayGoal, 3000);
  });

  // ------------------------------------------------------------ settings

  testWidgets('AC-16 goal edit in fl oz validates in ounces', (tester) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(unit: VolumeUnit.oz, goals: [(daysAgo(5), 2000)]),
      ),
    );
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('goal_dialog_field')),
    );
    expect(field.controller!.text, '68');
    await tester.enterText(find.byKey(const Key('goal_dialog_field')), '10');
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a goal between 17 and 202 fl oz'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal_dialog_field')), '80');
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pumpAndSettle();
    expect(h.state.todayGoal, closeTo(80 * mlPerOz, 1e-9));
    await openTab(tester, 'tab_today');
    expect(text(tester, 'total'), '0 / 80 fl oz');
  });

  testWidgets('AC-16 saving the unchanged ounce goal keeps the exact ml', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(unit: VolumeUnit.oz, goals: [(daysAgo(5), 2000)]),
      ),
    );
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_save')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('goal_save')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.state.todayGoal, 2000);
    expect(find.byKey(const Key('settings')), findsOneWidget);
  });

  testWidgets('AC-17 switching back to ml shows exact ml of oz drinks', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await openTab(tester, 'tab_settings');
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_today');
    await tester.tap(find.byKey(const Key('add_237')));
    await tester.pumpAndSettle();
    expect(find.text('Added 8 fl oz'), findsOneWidget);
    expect(h.state.todayTotal, closeTo(8 * mlPerOz, 1e-9));
    await openTab(tester, 'tab_settings');
    await tester.tap(find.text('ml'));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_today');
    expect(text(tester, 'total'), '237 / 2000 ml');
    expect(find.text('250 ml'), findsOneWidget);
    expect(find.text('8 fl oz'), findsNothing);
  });

  testWidgets('AC-18 after reset the app starts clean and survives restart', (
    tester,
  ) async {
    var h = await pumpApp(tester, storage: seededWeek());
    await openTab(tester, 'tab_settings');
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_confirm')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('goal_field')));
    expect(field.controller!.text, '2000');
    expect(field.decoration!.suffixText, 'ml');

    h = await restart(tester, h);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '0 / 2000 ml');
    await openTab(tester, 'tab_history');
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(h.state.streak, 0);
  });

  testWidgets('AC-18 double tap on Reset does not skip onboarding', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    final spot = tester.getCenter(find.byKey(const Key('reset_confirm')));
    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(spot);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(h.state.onboarded, isFalse);
    expect(h.storage.data, isNull);
    // A deliberate tap a moment later works.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.enterText(find.byKey(const Key('goal_field')), '1500');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(h.state.onboarded, isTrue);
    expect(text(tester, 'total'), '0 / 1500 ml');
  });

  testWidgets('AC-18 dismissing the reset dialog deletes nothing', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    final before = h.storage.data;
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset_dialog')), findsNothing);
    expect(h.state.hasAnyDrinks, isTrue);
    expect(h.storage.data, before);
  });

  // ------------------------------------------------------------ data

  testWidgets('AC-19 restart with the custom dialog open loses nothing', (
    tester,
  ) async {
    var h = await pumpApp(tester, storage: seededWeek());
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_field')), '400');
    await tester.pump();
    h = await restart(tester, h);
    expect(find.byKey(const Key('custom_dialog')), findsNothing);
    expect(h.state.todayTotal, 250);
    expect(h.state.lastSevenDays.map((d) => d.ml).toList(), [
      2100,
      2000,
      1900,
      1800,
      1700,
      1600,
      250,
    ]);
  });

  testWidgets('AC-19 drink times survive a restart', (tester) async {
    var h = await pumpApp(tester);
    h.clock.now = DateTime(2026, 10, 14, 7, 5);
    await tester.tap(find.byKey(const Key('add_150')));
    await tester.pumpAndSettle();
    h.clock.now = testNow;
    h = await restart(tester, h);
    expect(h.state.todayDrinks.single.time, DateTime(2026, 10, 14, 7, 5));
    expect(find.text('7:05 AM'), findsOneWidget);
  });

  testWidgets('AC-20 storage that throws on read starts fresh', (tester) async {
    final h = await pumpApp(tester, storage: BrokenReadStorage());
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsOneWidget,
    );
    expect(h.state.hasAnyDrinks, isFalse);
  });

  testWidgets('AC-20 a bad drink entry inside valid JSON starts fresh', (
    tester,
  ) async {
    final h = await pumpApp(
      tester,
      storage: MemoryStorage(
        '{"onboarded": true, "unit": "ml", "goals": [], '
        '"drinks": [{"id": 1, "t": "not a date", "ml": 250}]}',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(h.state.loadFailed, isTrue);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsOneWidget,
    );
  });

  testWidgets('AC-20 after starting fresh, new data replaces the bad data', (
    tester,
  ) async {
    var h = await pumpApp(tester, storage: MemoryStorage('[1, 2'));
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(h.storage.json['drinks'], hasLength(1));
    h = await restart(tester, h);
    expect(h.state.loadFailed, isFalse);
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsNothing,
    );
    expect(text(tester, 'total'), '250 / 2000 ml');
  });

  testWidgets('AC-20 a full disk does not crash logging', (tester) async {
    final h = await pumpApp(
      tester,
      storage: FullDiskStorage(savedJson(goals: [(daysAgo(5), 2000)])),
    );
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.state.todayTotal, 250);
    expect(text(tester, 'total'), '250 / 2000 ml');
  });

  testWidgets('AC-20 loading state shows a spinner and no ad', (tester) async {
    usePhoneView(tester);
    final storage = SlowStorage(seededWeek().data);
    final ads = FakeAds();
    final state = AppState(storage: storage, clock: TestClock(testNow).call);
    await tester.pumpWidget(GlassfulApp(state: state, ads: ads));
    final loading = state.load();
    await tester.pump();
    expect(find.byKey(const Key('loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('nav')), findsNothing);
    expect(ads.bannersCreated, 0);
    storage.gate.complete();
    await loading;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today')), findsOneWidget);
  });

  // ------------------------------------------------------------ ads

  testWidgets('AC-21 launch requests no ad and starts consent once', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    expect(h.ads.started, 1);
    expect(h.ads.bannersCreated, 0);
    // Leaving and returning to the app does not show or request an ad.
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
    expect(h.ads.bannersCreated, 0);
    expect(find.byKey(const Key('fake_ad')), findsNothing);
    // Every launch updates consent again.
    await restart(tester, h);
    expect(h.ads.started, 2);
  });

  testWidgets('AC-21 tab switching shows at most one banner, frees the old', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    for (var i = 0; i < 3; i++) {
      await openTab(tester, 'tab_history');
      expect(find.byKey(const Key('fake_ad')), findsOneWidget);
      await openTab(tester, 'tab_today');
      expect(find.byKey(const Key('fake_ad')), findsNothing);
    }
    expect(h.ads.banners.where((b) => !b.disposed), isEmpty);
  });

  testWidgets('AC-21 no ad in the custom dialog, goal and reset dialogs', (
    tester,
  ) async {
    await pumpApp(tester, storage: seededWeek());
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake_ad')), findsNothing);
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake_ad')), findsNothing);
    await tester.tap(find.byKey(const Key('goal_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake_ad')), findsNothing);
  });

  testWidgets('AC-21 rotating History replaces the banner, no overflow', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    await openTab(tester, 'tab_history');
    expect(h.ads.bannersCreated, 1);
    tester.view.physicalSize = const Size(2400, 1080);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.ads.bannersCreated, 2);
    expect(h.ads.banners.first.disposed, isTrue);
    expect(find.byKey(const Key('fake_ad')), findsOneWidget);
  });

  testWidgets('AC-21 consent refused: no banner request on any screen', (
    tester,
  ) async {
    final ads = FakeAds(canRequest: false);
    await pumpApp(tester, storage: seededWeek(), ads: ads);
    for (final tab in ['tab_history', 'tab_settings', 'tab_today']) {
      await openTab(tester, tab);
    }
    await openTab(tester, 'tab_history');
    expect(ads.bannersCreated, 0);
    expect(find.byKey(const Key('history_banner')), findsNothing);
  });

  testWidgets('AC-22 a banner that later fails collapses with no gap', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: seededWeek());
    await openTab(tester, 'tab_history');
    expect(find.byKey(const Key('history_banner')), findsOneWidget);
    h.ads.banners.single.setLoaded(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_banner')), findsNothing);
    final list = tester.getRect(find.byType(ListView).last);
    final nav = tester.getRect(find.byKey(const Key('nav')));
    expect(list.bottom, nav.top);
  });

  testWidgets('AC-22 a banner that loads late appears without breaking', (
    tester,
  ) async {
    final ads = FakeAds(bannerLoads: false);
    await pumpApp(tester, storage: seededWeek(), ads: ads);
    await openTab(tester, 'tab_history');
    expect(find.byKey(const Key('history_banner')), findsNothing);
    ads.banners.single.setLoaded(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_banner')), findsOneWidget);
    final banner = tester.getRect(find.byKey(const Key('history_banner')));
    final list = tester.getRect(find.byType(ListView).last);
    expect(banner.top, greaterThanOrEqualTo(list.bottom));
  });

  testWidgets('AC-22 the real service offers no banner before consent', (
    tester,
  ) async {
    final real = GoogleAdsService(AdUnits.androidTest);
    expect(real.canRequestAds.value, isFalse);
    expect(await real.createBanner(400), isNull);
    expect(await NoAdsService().createBanner(400), isNull);
  });

  test('AC-21 debug and test builds use only Google test ad units', () async {
    const publisher = 'ca-app-pub-3940256099942544/';
    expect(AdUnits.androidTest.historyBanner, startsWith(publisher));
    expect(AdUnits.iosTest.historyBanner, startsWith(publisher));
    final units = await AdUnits.load();
    expect(units.historyBanner, startsWith(publisher));
    // No other ad unit id anywhere in the app code.
    final ids = RegExp(r'ca-app-pub-\d+[/~]\d+');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in ids.allMatches(f.readAsStringSync())) {
        expect(m.group(0), startsWith('ca-app-pub-3940256099942544'));
      }
    }
  });

  testWidgets('AC-23 Privacy options appears and hides as consent changes', (
    tester,
  ) async {
    final h = await pumpApp(tester, ads: FakeAds(privacyRequired: true));
    await openTab(tester, 'tab_settings');
    expect(find.byKey(const Key('privacy_options')), findsOneWidget);
    h.ads.privacyRequired.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_options')), findsNothing);
  });

  // ------------------------------------------------------------ a11y

  testWidgets('AC-24 tap targets on onboarding, History and every dialog', (
    tester,
  ) async {
    await pumpApp(tester, storage: MemoryStorage());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_250')));
    await tester.pumpAndSettle();
    // With the Undo snackbar showing.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_history');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await openTab(tester, 'tab_settings');
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('goal_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset_all')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('AC-24 labels in fl oz and every tap target has a label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          unit: VolumeUnit.oz,
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), VolumeUnit.oz.toMl(8))],
        ),
      ),
    );
    for (final s in ['Add 6 fl oz', 'Add 8 fl oz', 'Add 16 fl oz']) {
      expect(find.bySemanticsLabel(s), findsOneWidget, reason: s);
    }
    expect(find.byTooltip('Delete 8 fl oz drink at 9:00 AM'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await openTab(tester, 'tab_settings');
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('AC-24 dark mode text contrast on every screen', (tester) async {
    darkMode(tester);
    await pumpApp(tester, storage: MemoryStorage());
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_500')));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await openTab(tester, 'tab_history');
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await openTab(tester, 'tab_settings');
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('AC-24 dark mode contrast with Goal reached showing', (
    tester,
  ) async {
    darkMode(tester);
    await pumpApp(tester, storage: goalMetToday());
    expect(find.text('Goal reached'), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('AC-24 light mode text contrast on History and Settings', (
    tester,
  ) async {
    await pumpApp(tester, storage: goalMetToday());
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await openTab(tester, 'tab_history');
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await openTab(tester, 'tab_settings');
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('AC-25 text 2.0 at 320x568: goal reached, snackbar, fl oz', (
    tester,
  ) async {
    smallBigText(tester);
    final h = await pumpApp(tester, storage: goalMetToday(), phoneView: false);
    expect(tester.takeException(), isNull);
    expect(find.text('Goal reached'), findsOneWidget);
    await tapVisible(tester, 'add_500');
    expect(tester.takeException(), isNull);
    await h.state.setUnit(VolumeUnit.oz);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await openTab(tester, 'tab_history');
    expect(tester.takeException(), isNull);
    // Let the "Added" snackbar time out; it floats over the bottom rows.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_settings');
    await tapVisible(tester, 'reset_all');
    expect(find.byKey(const Key('reset_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-25 text 2.0 rotated to 568x320: no overflow anywhere', (
    tester,
  ) async {
    smallBigText(tester, landscape: true);
    await pumpApp(tester, storage: MemoryStorage(), phoneView: false);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'start_button');
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'add_250');
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'add_custom');
    expect(find.byKey(const Key('custom_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    await openTab(tester, 'tab_history');
    expect(tester.takeException(), isNull);
    await openTab(tester, 'tab_settings');
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'settings_goal');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-25 text 2.0 at 320x568 in dark mode with a full week', (
    tester,
  ) async {
    smallBigText(tester);
    darkMode(tester);
    await pumpApp(tester, storage: seededWeek(), phoneView: false);
    expect(tester.takeException(), isNull);
    await openTab(tester, 'tab_history');
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-25 large tablet screen renders every tab', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpApp(tester, storage: seededWeek(), phoneView: false);
    for (final tab in ['tab_history', 'tab_settings', 'tab_today']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull);
    }
  });

  test('AC-19 PrefsStorage key is stable', () {
    // Changing the key would silently lose every user's data on update.
    expect(PrefsStorage.key, 'glassful.v1');
  });
}
