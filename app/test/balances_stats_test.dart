import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/premium_screen.dart';
import 'package:trippi/widgets/confetti.dart';

import 'expenses_test.dart' show openTrip;
import 'support/fakes.dart';

List<Expense> twoExpenses() => [
  sampleExpense(id: 'e1', amount: 9000), // Ana paid 90.00 for 3
  sampleExpense(
    id: 'e2',
    title: 'Taxi',
    amount: 3000,
    paidBy: 'p-ben',
    category: 'transport',
    date: DateTime(2026, 10, 4),
  ),
];

/// A Semantics widget with exactly this label (chart and row summaries).
Finder semanticsLabel(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AC-22 AC-23 balances show signs and words, and the fewest payments',
    (tester) async {
      await openTrip(tester, expenses: twoExpenses());
      await openTab(tester, 'tab_balances');
      expect(find.text('+€50.00 gets back'), findsOneWidget);
      expect(find.text('−€10.00 owes'), findsOneWidget);
      expect(find.text('−€40.00 owes'), findsOneWidget);
      expect(find.text('Cleo → Ana'), findsOneWidget);
      expect(find.text('Ben → Ana'), findsOneWidget);
      expect(find.text('Suggested payments'), findsOneWidget);
      expect(find.byType(Confetti), findsNothing);
    },
  );

  testWidgets(
    'AC-24 Settle opens the payment prefilled; saving updates balances',
    (tester) async {
      final h = await openTrip(tester, expenses: twoExpenses());
      await openTab(tester, 'tab_balances');
      await tapOn(tester, find.byKey(const Key('settle_Cleo_Ana')));
      expect(find.text('Record payment'), findsWidgets);
      final amount = tester.widget<TextField>(
        find.byKey(const Key('settle_amount')),
      );
      expect(amount.controller!.text, '40.00');
      expect(find.text('Cleo'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('save_payment')));
      expect(find.text('Payment recorded'), findsOneWidget);
      final p = h.repo.payments.values.single;
      expect((p.fromId, p.toId, p.amountMinor), ('p-cleo', 'p-ana', 4000));
      expect(find.text('Cleo → Ana'), findsNothing);
      expect(find.text('+€10.00 gets back'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-24 a payment needs two different people and an amount above 0',
    (tester) async {
      await openTrip(tester, expenses: twoExpenses());
      await openTab(tester, 'tab_balances');
      await tapOn(tester, find.byKey(const Key('record_payment')));
      bool enabled() =>
          tester
              .widget<FilledButton>(find.byKey(const Key('save_payment')))
              .onPressed !=
          null;
      expect(enabled(), isFalse);
      await tester.enterText(find.byKey(const Key('settle_amount')), '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount greater than 0'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('settle_amount')), '5.555');
      await tester.pumpAndSettle();
      expect(find.text('Use up to 2 decimals for EUR'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('settle_amount')), '5');
      await tester.pumpAndSettle();
      expect(enabled(), isTrue);
      await tester.tap(find.byKey(const Key('settle_to')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').last);
      await tester.pumpAndSettle();
      expect(find.text('Choose two different people'), findsOneWidget);
      expect(enabled(), isFalse);
    },
  );

  testWidgets(
    'AC-25 payment history lists payments and one can be deleted after confirming',
    (tester) async {
      final h = await openTrip(
        tester,
        expenses: twoExpenses(),
        trip: sampleTrip(),
      );
      final state = h.state(tester);
      await state.savePayment(
        Payment(
          id: 'pay1',
          tripId: 't-lisbon',
          fromId: 'p-ben',
          toId: 'p-ana',
          amountMinor: 1000,
          date: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 5),
        ),
      );
      await openTab(tester, 'tab_balances');
      expect(find.text('Payment history'), findsOneWidget);
      expect(find.text('Ben paid Ana'), findsOneWidget);
      expect(find.text('5 Oct 2026'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('payment_menu_pay1')));
      await tester.tap(find.text('Delete payment'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this payment?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(h.repo.payments, isEmpty);
      expect(find.text('Ben paid Ana'), findsNothing);
    },
  );

  testWidgets('AC-26 when everyone is even the tab shows All settled up', (
    tester,
  ) async {
    final h = await openTrip(
      tester,
      expenses: [sampleExpense(id: 'e1', amount: 9000)],
    );
    final state = h.state(tester);
    for (final from in ['p-ben', 'p-cleo']) {
      await state.savePayment(
        Payment(
          id: 'pay-$from',
          tripId: 't-lisbon',
          fromId: from,
          toId: 'p-ana',
          amountMinor: 3000,
          date: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 5),
        ),
      );
    }
    await openTab(tester, 'tab_balances');
    expect(find.text('All settled up'), findsOneWidget);
    expect(find.text('Everyone is even. Nice trip!'), findsOneWidget);
    expect(find.text('Settled'), findsNWidgets(3));
    expect(find.text('Suggested payments'), findsNothing);
    expect(find.byType(Confetti), findsOneWidget);
  });

  testWidgets('AC-26 balances with no expenses show the empty state', (
    tester,
  ) async {
    await openTrip(tester);
    await openTab(tester, 'tab_balances');
    expect(find.text('Nothing to settle yet'), findsOneWidget);
  });

  testWidgets(
    'AC-27 the header shows total, number of expenses and average per person',
    (tester) async {
      await openTrip(tester, expenses: twoExpenses());
      expect(
        tester.widget<Text>(find.byKey(const Key('header_total'))).data,
        '€120.00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('header_count'))).data,
        '2 expenses',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('header_average'))).data,
        '€40.00 avg per person',
      );
    },
  );

  testWidgets('AC-27 with no expenses the header shows zeros', (tester) async {
    await openTrip(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('header_total'))).data,
      '€0.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('header_count'))).data,
      '0 expenses',
    );
  });

  testWidgets(
    'AC-28 the Stats tab shows spending by category with amounts and percentages',
    (tester) async {
      await openTrip(tester, expenses: twoExpenses());
      await openTab(tester, 'tab_stats');
      expect(find.text('Spending by category'), findsOneWidget);
      Finder inCard(String text) => find.descendant(
        of: find.byKey(const Key('stats_by_category')),
        matching: find.text(text),
      );
      expect(inCard('Food & drink'), findsOneWidget);
      expect(inCard('€90.00'), findsOneWidget);
      expect(inCard('75%'), findsOneWidget);
      expect(inCard('Transport'), findsOneWidget);
      expect(inCard('€30.00'), findsOneWidget);
      expect(inCard('25%'), findsOneWidget);
      expect(inCard('€120.00'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-29 AC-45a free users see the advanced stats locked behind Unlock with Premium',
    (tester) async {
      await openTrip(tester, expenses: twoExpenses());
      await openTab(tester, 'tab_stats');
      expect(find.byKey(const Key('stats_locked')), findsOneWidget);
      expect(find.text('See where the money went'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('unlock_stats')));
      expect(find.byType(PremiumScreen), findsOneWidget);
      // AC-45: advanced stats is a Pass feature, so the video is offered.
      expect(
        find.byKey(const Key('rewarded_offer'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AC-29 Premium shows daily spending, who paid, and the top 5 expenses',
    (tester) async {
      final handle = tester.ensureSemantics();
      final six = [
        sampleExpense(id: 'e1', title: 'Hotel', amount: 30000),
        sampleExpense(id: 'e2', title: 'Dinner', amount: 9000, paidBy: 'p-ben'),
        sampleExpense(id: 'e3', title: 'Museum', amount: 4500),
        sampleExpense(
          id: 'e4',
          title: 'Taxi',
          amount: 3000,
          paidBy: 'p-cleo',
          date: DateTime(2026, 10, 4),
        ),
        sampleExpense(
          id: 'e5',
          title: 'Coffee',
          amount: 1200,
          date: DateTime(2026, 10, 4),
        ),
        sampleExpense(
          id: 'e6',
          title: 'Water',
          amount: 300,
          date: DateTime(2026, 10, 4),
        ),
      ];
      await openTrip(tester, expenses: six, premium: true);
      await openTab(tester, 'tab_stats');
      expect(find.byKey(const Key('stats_locked')), findsNothing);

      final list = find.byKey(const Key('stats_list'));
      await tester.dragUntilVisible(
        find.byKey(const Key('stats_daily')),
        list,
        const Offset(0, -300),
      );
      // Daily totals: 3 Oct €435.00, 4 Oct €45.00.
      expect(
        semanticsLabel('Daily spending: 3 Oct €435.00, 4 Oct €45.00'),
        findsOneWidget,
      );

      await tester.dragUntilVisible(
        find.byKey(const Key('stats_people')),
        list,
        const Offset(0, -300),
      );
      // Ana paid 300 + 45 + 12 + 3 = €360.00; each share is a third of €480.
      expect(
        semanticsLabel('Ana: paid €360.00, share €160.00'),
        findsOneWidget,
      );
      expect(semanticsLabel('Ben: paid €90.00, share €160.00'), findsOneWidget);
      expect(
        semanticsLabel('Cleo: paid €30.00, share €160.00'),
        findsOneWidget,
      );

      await tester.dragUntilVisible(
        find.byKey(const Key('stats_top')),
        list,
        const Offset(0, -300),
      );
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      Finder inTop(String text) => find.descendant(
        of: find.byKey(const Key('stats_top')),
        matching: find.text(text),
      );
      final order = ['Hotel', 'Dinner', 'Museum', 'Taxi', 'Coffee'];
      for (final title in order) {
        expect(inTop(title), findsOneWidget);
      }
      expect(inTop('Water'), findsNothing);
      for (var i = 1; i < order.length; i++) {
        expect(
          tester.getTopLeft(inTop(order[i - 1])).dy,
          lessThan(tester.getTopLeft(inTop(order[i])).dy),
        );
      }
      handle.dispose();
    },
  );

  testWidgets('AC-29 a Premium Pass unlocks the advanced stats too', (
    tester,
  ) async {
    await openTrip(
      tester,
      expenses: twoExpenses(),
      settings: {'pass_end': DateTime(2026, 10, 12).toIso8601String()},
    );
    await openTab(tester, 'tab_stats');
    expect(find.byKey(const Key('stats_locked')), findsNothing);
  });

  testWidgets('AC-30 with no expenses Stats shows an empty state', (
    tester,
  ) async {
    await openTrip(tester);
    await openTab(tester, 'tab_stats');
    expect(find.text('No stats yet'), findsOneWidget);
    expect(find.byKey(const Key('stats_by_category')), findsNothing);
  });

  testWidgets('AC-31 Share summary sends the text summary to the share sheet', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: twoExpenses());
    await tester.tap(find.byKey(const Key('open_export')));
    await tester.pumpAndSettle();
    expect(find.text('Share or export'), findsWidgets);
    await tester.tap(find.byKey(const Key('export_text')));
    await tester.pumpAndSettle();
    expect(h.files.texts.single, contains('Cleo pays Ana €40.00'));
  });

  testWidgets('AC-32 AC-33 AC-45a PDF and Excel are locked for free users', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: twoExpenses());
    await tester.tap(find.byKey(const Key('open_export')));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('export_pdf')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(
      find.byKey(const Key('rewarded_offer'), skipOffstage: false),
      findsOneWidget,
    );
    expect(h.files.sharedFiles, isEmpty);
  });

  testWidgets(
    'AC-32 AC-33 Premium exports a PDF and an Excel file to the share sheet',
    (tester) async {
      final h = await openTrip(tester, expenses: twoExpenses(), premium: true);
      await tester.tap(find.byKey(const Key('open_export')));
      await tester.pumpAndSettle();
      expect(find.text('Premium'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export_pdf')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(h.files.sharedFiles.single.$2, 'trippi-lisbon-weekend.pdf');
      expect(h.files.sharedFiles.single.$3, 'application/pdf');

      await tester.tap(find.byKey(const Key('open_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export_excel')));
      await tester.pumpAndSettle();
      expect(h.files.sharedFiles.last.$2, 'trippi-lisbon-weekend.xlsx');
    },
  );

  testWidgets('AC-32 a failed export shows an error and keeps the sheet open', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: twoExpenses(), premium: true);
    h.files.failShare = true;
    await tester.tap(find.byKey(const Key('open_export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export_excel')));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't create the file. Please try again."),
      findsOneWidget,
    );
  });
}
