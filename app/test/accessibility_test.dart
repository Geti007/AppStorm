import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

MemoryStorage seeded() => MemoryStorage(
  savedJson(
    goals: [(daysAgo(30), 2000)],
    drinks: [
      for (var i = 1; i < 7; i++) (daysAgo(i), 1500.0 + i * 100),
      (daysAgo(0, hour: 9), 250),
    ],
  ),
);

Future<void> smallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('AC-24 labels on quick-add, delete and tabs', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, storage: seeded());
    expect(find.bySemanticsLabel('Add 150 ml'), findsOneWidget);
    expect(find.bySemanticsLabel('Add 250 ml'), findsOneWidget);
    expect(find.bySemanticsLabel('Add 500 ml'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a custom amount'), findsOneWidget);
    expect(find.byTooltip('Delete 250 ml drink at 9:00 AM'), findsOneWidget);
    expect(
      find.bySemanticsLabel('250 of 2000 millilitres, 13 percent'),
      findsOneWidget,
    );
    for (final tab in ['Today', 'History', 'Settings']) {
      expect(find.bySemanticsLabel(RegExp('^$tab')), findsWidgets);
    }
    semantics.dispose();
  });

  testWidgets('AC-24 tappable controls are at least 48 by 48', (tester) async {
    await pumpApp(tester, storage: seeded());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await openTab(tester, 'tab_settings');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('AC-24 text contrast meets the guideline on Today', (
    tester,
  ) async {
    await pumpApp(tester, storage: seeded());
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('AC-25 text scale 2.0 on 320x568: no overflow anywhere', (
    tester,
  ) async {
    await smallScreen(tester);
    // Onboarding.
    final h = await pumpApp(tester, storage: MemoryStorage(), phoneView: false);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Today with drinks, and the custom dialog.
    for (var i = 0; i < 3; i++) {
      await h.state.addDrink(250);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('custom_cancel')));
    await tester.pumpAndSettle();
    // History and Settings.
    await openTab(tester, 'tab_history');
    expect(tester.takeException(), isNull);
    await openTab(tester, 'tab_settings');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('settings_goal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-25 dark mode renders every tab without errors', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, storage: seeded());
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    for (final tab in ['tab_history', 'tab_settings', 'tab_today']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull);
    }
  });
}
