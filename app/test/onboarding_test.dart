import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/units.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-1 first launch shows onboarding with 2000 ml', (
    tester,
  ) async {
    await pumpApp(tester, storage: MemoryStorage());
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(find.text('Welcome to Glassful'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('goal_field')));
    expect(field.controller!.text, '2000');
    expect(field.decoration!.suffixText, 'ml');
    expect(find.byKey(const Key('nav')), findsNothing);
  });

  testWidgets('AC-2 Start tracking opens Today and onboarding stays done', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today')), findsOneWidget);
    expect(text(tester, 'total'), '0 / 2000 ml');

    await restart(tester, h);
    expect(find.byKey(const Key('onboarding')), findsNothing);
    expect(find.byKey(const Key('today')), findsOneWidget);
  });

  testWidgets('AC-3 out-of-range goal shows an error and stays', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    for (final bad in ['499', '6001', '']) {
      await tester.enterText(find.byKey(const Key('goal_field')), bad);
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a goal between 500 and 6000 ml'), findsOneWidget);
      expect(find.byKey(const Key('onboarding')), findsOneWidget);
    }
    expect(h.state.onboarded, isFalse);
    await tester.enterText(find.byKey(const Key('goal_field')), '6000');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(h.state.todayGoal, 6000);
  });

  testWidgets('AC-26 choosing fl oz shows 68 and the ounce range', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: MemoryStorage());
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('goal_field')));
    expect(field.controller!.text, '68');
    expect(field.decoration!.suffixText, 'fl oz');

    await tester.enterText(find.byKey(const Key('goal_field')), '10');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a goal between 17 and 202 fl oz'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('goal_field')), '64');
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();
    expect(h.state.unit, VolumeUnit.oz);
    expect(text(tester, 'total'), '0 / 64 fl oz');
  });
}
