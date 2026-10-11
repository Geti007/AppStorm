import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/categories_screen.dart';
import 'package:trippi/screens/export_sheet.dart';

import 'support/fakes.dart';

/// A small Android phone (360 x 780 dp) with text at 200 %.
void useSmallPhoneLargeText(WidgetTester tester) {
  usePhone(tester, textScale: 2);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
}

Future<void> checkScreen(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$name overflowed');
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

Snapshot data() => Snapshot(
  trips: [
    sampleTrip(),
    sampleTrip(id: 't2', name: 'A rather long trip name for testing'),
  ],
  expenses: [
    sampleExpense(id: 'e1', title: 'Dinner at a seaside restaurant'),
    sampleExpense(
      id: 'e2',
      title: 'Taxi',
      amount: 3000,
      paidBy: 'p-ben',
      category: 'transport',
      date: DateTime(2026, 10, 4),
    ),
  ],
);

void main() {
  for (final premium in [false, true]) {
    final plan = premium ? 'Premium' : 'free';
    testWidgets(
      'AC-49 main screens at 200% text have no overflow, labelled 48dp targets ($plan)',
      (tester) async {
        final handle = tester.ensureSemantics();
        useSmallPhoneLargeText(tester);
        final h = Harness(premium: premium, initial: data());
        await h.pump(tester);
        await checkScreen(tester, 'trips');

        await tester.tap(find.text('Lisbon weekend'));
        await checkScreen(tester, 'expenses tab');

        await tester.tap(find.byKey(const Key('add_expense')));
        await checkScreen(tester, 'expense form');
        await tester.tap(find.byKey(const Key('close_form')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab_balances')));
        await checkScreen(tester, 'balances tab');

        await tester.dragUntilVisible(
          find.byKey(const Key('record_payment')),
          find.byKey(const Key('balances_list')),
          const Offset(0, -200),
        );
        await tapOn(tester, find.byKey(const Key('record_payment')));
        await checkScreen(tester, 'settle');
        await tester.tap(find.byKey(const Key('close_form')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab_stats')));
        await checkScreen(tester, 'stats tab');

        await tester.tap(find.byKey(const Key('open_export')));
        await checkScreen(tester, 'export sheet');
        Navigator.of(tester.element(find.byType(ExportSheet))).pop();
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open_settings')));
        await checkScreen(tester, 'settings');

        if (!premium) {
          await tester.dragUntilVisible(
            find.byKey(const Key('get_premium')),
            find.byKey(const Key('settings_list')),
            const Offset(0, -300),
          );
          await tester.tap(find.byKey(const Key('get_premium')));
          await checkScreen(tester, 'premium');
        } else {
          await tester.dragUntilVisible(
            find.byKey(const Key('open_categories')),
            find.byKey(const Key('settings_list')),
            const Offset(0, -300),
          );
          await tapOn(tester, find.byKey(const Key('open_categories')));
          await checkScreen(tester, 'categories');
          expect(find.byType(CategoriesScreen), findsOneWidget);
          await tester.tap(find.byKey(const Key('new_category')));
          await checkScreen(tester, 'category sheet');
        }
        handle.dispose();
      },
    );
  }

  testWidgets('AC-49 onboarding at 200% text', (tester) async {
    final handle = tester.ensureSemantics();
    useSmallPhoneLargeText(tester);
    await Harness(onboarded: false).pump(tester);
    await checkScreen(tester, 'onboarding');
    for (var i = 0; i < 3; i++) {
      final next = find.byKey(const Key('onboarding_next'));
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await checkScreen(tester, 'onboarding page ${i + 2}');
    }
    handle.dispose();
  });

  testWidgets('AC-49 empty trips and the trip form at 200% text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    useSmallPhoneLargeText(tester);
    await Harness().pump(tester);
    await checkScreen(tester, 'trips empty');
    await tester.tap(find.byKey(const Key('create_first_trip')));
    await checkScreen(tester, 'trip form');
    handle.dispose();
  });
}
