import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/premium_screen.dart';
import 'package:trippi/services/rates.dart';

import 'support/fakes.dart';

Future<Harness> openTrip(
  WidgetTester tester, {
  List<Expense> expenses = const [],
  bool premium = false,
  Map<String, String> settings = const {},
  Trip? trip,
}) async {
  usePhone(tester);
  final h = Harness(
    premium: premium,
    initial: Snapshot(
      trips: [trip ?? sampleTrip()],
      expenses: expenses,
      settings: settings,
    ),
  );
  await h.pump(tester);
  await tester.tap(find.text((trip ?? sampleTrip()).name).first);
  await tester.pumpAndSettle();
  return h;
}

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add_expense')));
  await tester.pumpAndSettle();
}

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('save_expense')))
        .onPressed !=
    null;

Future<void> fill(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AC-9 Save stays disabled until title, valid amount, payer and split are set',
    (tester) async {
      await openTrip(tester);
      await openAdd(tester);
      expect(find.text('Add expense'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      await fill(tester, 'expense_amount', '12.345');
      expect(find.text('Use up to 2 decimals for EUR'), findsOneWidget);
      await fill(tester, 'expense_title', 'Dinner');
      expect(saveEnabled(tester), isFalse);
      await fill(tester, 'expense_amount', '0');
      expect(find.text('Enter an amount greater than 0'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      await fill(tester, 'expense_amount', '12.34');
      expect(saveEnabled(tester), isTrue);
      // At least one person must be in the split.
      await tapOn(tester, find.byKey(const Key('select_all')));
      expect(saveEnabled(tester), isFalse);
      await tapOn(tester, find.byKey(const Key('share_Ben')));
      expect(saveEnabled(tester), isTrue);
      // The title is limited to 60 characters.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('expense_title')))
            .maxLength,
        60,
      );
    },
  );

  testWidgets('AC-9 AC-17 a zero-decimal currency rejects decimals', (
    tester,
  ) async {
    await openTrip(tester, trip: sampleTrip(currency: 'JPY'));
    await openAdd(tester);
    await fill(tester, 'expense_amount', '1200.5');
    expect(find.text('Use whole numbers for JPY'), findsOneWidget);
    await fill(tester, 'expense_amount', '1200');
    expect(find.text('Use whole numbers for JPY'), findsNothing);
  });

  testWidgets('AC-10 equal split shows each share and saves exact shares', (
    tester,
  ) async {
    final h = await openTrip(tester);
    await openAdd(tester);
    await fill(tester, 'expense_title', 'Museum');
    await fill(tester, 'expense_amount', '10');
    expect(find.text('€3.34'), findsOneWidget);
    expect(find.text('€3.33'), findsNWidgets(2));
    await tapOn(tester, find.byKey(const Key('save_expense')));
    final e = h.repo.expenses.values.single;
    expect(e.method, SplitMethod.equal);
    expect(e.splitAmong, ['p-ana', 'p-ben', 'p-cleo']);
    expect(e.amountMinor, 1000);
  });

  testWidgets('AC-11 percentages must add up to 100 before Save', (
    tester,
  ) async {
    final h = await openTrip(tester);
    await openAdd(tester);
    await fill(tester, 'expense_title', 'Hotel');
    await fill(tester, 'expense_amount', '300');
    await tapOn(tester, find.byKey(const Key('split_percent')));
    await fill(tester, 'percent_Ana', '50');
    expect(find.text('Remaining: 50%'), findsOneWidget);
    await fill(tester, 'percent_Ben', '25');
    expect(find.text('Remaining: 25%'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    await fill(tester, 'percent_Cleo', '30');
    expect(find.text('Remaining: -5%'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    await fill(tester, 'percent_Cleo', '25');
    expect(find.text('Remaining: 0%'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
    await tapOn(tester, find.byKey(const Key('save_expense')));
    final e = h.repo.expenses.values.single;
    expect(e.method, SplitMethod.percent);
    expect(e.splitInputs, {'p-ana': 5000, 'p-ben': 2500, 'p-cleo': 2500});
  });

  testWidgets('AC-12 custom amounts must add up to the expense amount', (
    tester,
  ) async {
    final h = await openTrip(tester);
    await openAdd(tester);
    await fill(tester, 'expense_title', 'Groceries');
    await fill(tester, 'expense_amount', '50');
    await tapOn(tester, find.byKey(const Key('split_custom')));
    await fill(tester, 'custom_Ana', '20');
    expect(find.text('Remaining: €30.00'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    await fill(tester, 'custom_Ben', '30');
    expect(find.text('Remaining: €0.00'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
    await tapOn(tester, find.byKey(const Key('save_expense')));
    final e = h.repo.expenses.values.single;
    expect(e.splitAmong, ['p-ana', 'p-ben']);
    expect(e.splitInputs, {'p-ana': 2000, 'p-ben': 3000});
  });

  testWidgets(
    'AC-13 every built-in category is offered and shown with its icon',
    (tester) async {
      final h = await openTrip(tester);
      await openAdd(tester);
      for (final name in [
        'Accommodation',
        'Food & drink',
        'Transport',
        'Activities',
        'Shopping',
        'Groceries',
        'Other',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      await fill(tester, 'expense_title', 'Train');
      await fill(tester, 'expense_amount', '30');
      await tapOn(tester, find.byKey(const Key('category_transport')));
      await tapOn(tester, find.byKey(const Key('save_expense')));
      expect(h.repo.expenses.values.single.categoryId, 'transport');
      expect(find.byIcon(Icons.directions_bus_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'AC-14 expenses are grouped by day, newest first, with base amounts',
    (tester) async {
      await openTrip(
        tester,
        expenses: [
          sampleExpense(
            id: 'e1',
            title: 'Breakfast',
            amount: 1500,
            date: DateTime(2026, 10, 2),
          ),
          sampleExpense(
            id: 'e2',
            title: 'Souvenirs',
            amount: 2200,
            currency: 'USD',
            rate: 0.5,
            paidBy: 'p-ben',
            date: DateTime(2026, 10, 11),
          ),
          sampleExpense(
            id: 'e3',
            title: 'Taxi',
            amount: 1800,
            date: DateTime(2026, 10, 10),
          ),
        ],
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Fri, 2 Oct'), findsOneWidget);
      final ySouvenirs = tester.getTopLeft(find.text('Souvenirs')).dy;
      final yTaxi = tester.getTopLeft(find.text('Taxi')).dy;
      final yBreakfast = tester.getTopLeft(find.text('Breakfast')).dy;
      expect(ySouvenirs < yTaxi && yTaxi < yBreakfast, isTrue);
      expect(find.text('Paid by Ben'), findsOneWidget);
      expect(find.text(r'$22.00'), findsOneWidget);
      expect(find.text('≈ €11.00'), findsOneWidget);
    },
  );

  testWidgets('AC-15 editing an expense updates totals and balances at once', (
    tester,
  ) async {
    final h = await openTrip(
      tester,
      expenses: [sampleExpense(id: 'e1', amount: 9000)],
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('header_total'))).data,
      '€90.00',
    );
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    await fill(tester, 'expense_amount', '120');
    await tapOn(tester, find.byKey(const Key('save_expense')));
    expect(
      tester.widget<Text>(find.byKey(const Key('header_total'))).data,
      '€120.00',
    );
    await tapOn(tester, find.byKey(const Key('tab_balances')));
    expect(find.text('+€80.00 gets back'), findsOneWidget);
    expect(h.repo.expenses['e1']!.amountMinor, 12000);
  });

  testWidgets(
    'AC-15 deleting an expense asks first and can be undone for 4 seconds',
    (tester) async {
      final h = await openTrip(tester, expenses: [sampleExpense(id: 'e1')]);
      await tester.drag(find.text('Dinner'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete this expense?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(h.repo.expenses, isEmpty);
      expect(find.text('Expense deleted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(h.repo.expenses.keys, ['e1']);
      expect(find.text('Dinner'), findsOneWidget);

      // From the edit screen, and the snackbar goes away after 4 seconds.
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_expense')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(h.repo.expenses, isEmpty);
      expect(find.text('Expense deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Expense deleted'), findsNothing);
    },
  );

  testWidgets('AC-16 search filters by title as you type; clearing shows all', (
    tester,
  ) async {
    await openTrip(
      tester,
      expenses: [
        sampleExpense(id: 'e1', title: 'Dinner at Ramiro'),
        sampleExpense(id: 'e2', title: 'Tram tickets'),
      ],
    );
    await tester.enterText(find.byKey(const Key('expense_search')), 'ram');
    await tester.pumpAndSettle();
    expect(find.text('Dinner at Ramiro'), findsOneWidget);
    expect(find.text('Tram tickets'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expense_search')), 'dinner');
    await tester.pumpAndSettle();
    expect(find.text('Tram tickets'), findsNothing);
    await tester.enterText(find.byKey(const Key('expense_search')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('No expenses match "xyz"'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear_search')));
    await tester.pumpAndSettle();
    expect(find.text('Dinner at Ramiro'), findsOneWidget);
    expect(find.text('Tram tickets'), findsOneWidget);
  });

  testWidgets('AC-17 the currency picker searches by code and name', (
    tester,
  ) async {
    await openTrip(tester);
    await openAdd(tester);
    await tester.tap(find.byKey(const Key('expense_currency')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('currency_search')), 'yen');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('currency_JPY')), findsOneWidget);
    expect(find.byKey(const Key('currency_USD')), findsNothing);
    await tester.enterText(find.byKey(const Key('currency_search')), 'qqq');
    await tester.pumpAndSettle();
    expect(find.text('No currency matches "qqq"'), findsOneWidget);
  });

  testWidgets(
    'AC-18 a different currency fills in the latest rate and its date; it can be overwritten',
    (tester) async {
      final h = await openTrip(tester);
      await openAdd(tester);
      await tester.tap(find.byKey(const Key('expense_currency')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_USD')));
      await tester.pumpAndSettle();
      expect(h.rates.latestCalls, 1);
      expect(
        find.text('1 USD = 0.909091 EUR · rate from 10 Oct 2026'),
        findsOneWidget,
      );
      await fill(tester, 'expense_title', 'Boat tour');
      await fill(tester, 'expense_amount', '100');
      await tapOn(tester, find.byKey(const Key('edit_rate')));
      await fill(tester, 'rate_field', '0.95');
      await tapOn(tester, find.byKey(const Key('save_expense')));
      final e = h.repo.expenses.values.single;
      expect(e.currency, 'USD');
      expect(e.rate, 0.95);
    },
  );

  testWidgets('AC-18 offline, the cached rate is used', (tester) async {
    final h = await openTrip(
      tester,
      settings: {'rates_latest': '{"date":"2026-10-01","rates":{"USD":1.2}}'},
    );
    h.rates.latestTable = null;
    await openAdd(tester);
    await tester.tap(find.byKey(const Key('expense_currency')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_USD')));
    await tester.pumpAndSettle();
    expect(
      find.text('1 USD = 0.833333 EUR · rate from 1 Oct 2026'),
      findsOneWidget,
    );
  });

  testWidgets(
    'AC-19 with no rate available the form asks for one and blocks Save',
    (tester) async {
      final h = await openTrip(tester);
      h.rates.latestTable = null;
      await openAdd(tester);
      await fill(tester, 'expense_title', 'Pho');
      await fill(tester, 'expense_amount', '200000');
      await tester.tap(find.byKey(const Key('expense_currency')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('currency_search')), 'VND');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_VND')));
      await tester.pumpAndSettle();
      expect(
        find.text('No rate available offline. Enter the rate.'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse);
      await fill(tester, 'rate_field', '0');
      expect(saveEnabled(tester), isFalse);
      await fill(tester, 'rate_field', '0.000036');
      expect(saveEnabled(tester), isTrue);
      await tapOn(tester, find.byKey(const Key('save_expense')));
      expect(h.repo.expenses.values.single.rate, 0.000036);
    },
  );

  testWidgets('AC-20 later rate changes never change a saved expense', (
    tester,
  ) async {
    final h = await openTrip(
      tester,
      expenses: [
        sampleExpense(id: 'e1', amount: 10000, currency: 'USD', rate: 0.8),
      ],
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('header_total'))).data,
      '€80.00',
    );
    h.rates.latestTable = const RateTable('2026-10-11', {'EUR': 1, 'USD': 2});
    await h.state(tester).refreshRates();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('header_total'))).data,
      '€80.00',
    );
    expect(h.repo.expenses['e1']!.rate, 0.8);
  });

  testWidgets(
    'AC-21 AC-45 free users see the historical rate locked; it opens Premium with a video offer',
    (tester) async {
      final h = await openTrip(tester);
      await openAdd(tester);
      await tester.tap(find.byKey(const Key('expense_currency')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_USD')));
      await tester.pumpAndSettle();
      await tapOn(tester, find.byKey(const Key('historical_rate')));
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(h.rates.historicalCalls, 0);
      // AC-45: the historical rate can be unlocked with a video.
      expect(
        find.byKey(const Key('rewarded_offer'), skipOffstage: false),
        findsOneWidget,
      );
      expect(h.ads.rewardedLoads, 1);
    },
  );

  testWidgets('AC-21 Premium fetches the rate on the expense date', (
    tester,
  ) async {
    final h = await openTrip(tester, premium: true);
    await openAdd(tester);
    await tester.tap(find.byKey(const Key('expense_currency')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_USD')));
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('historical_rate')));
    expect(h.rates.historicalCalls, 1);
    expect(find.text('1 USD = 0.8 EUR · rate from 1 Aug 2026'), findsOneWidget);
  });

  testWidgets('AC-21 a Premium Pass also unlocks the historical rate', (
    tester,
  ) async {
    final h = await openTrip(
      tester,
      settings: {'pass_end': DateTime(2026, 10, 12).toIso8601String()},
    );
    await openAdd(tester);
    await tester.tap(find.byKey(const Key('expense_currency')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_USD')));
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('historical_rate')));
    expect(h.rates.historicalCalls, 1);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets(
    'AC-41 AC-44 the expense form shows no upgrade prompt and no ad',
    (tester) async {
      final h = await openTrip(tester);
      await openAdd(tester);
      expect(find.byKey(const Key('upgrade_card')), findsNothing);
      expect(find.byKey(const Key('native_ad')), findsNothing);
      expect(find.byType(PremiumScreen), findsNothing);
      expect(h.ads.nativeRequests, 0);
    },
  );
}
