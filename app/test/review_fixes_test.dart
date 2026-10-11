import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/backup.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/data/money.dart';
import 'package:trippi/services/rates.dart';
import 'package:trippi/state/app_state.dart';

import 'expenses_test.dart' show openTrip, openAdd;
import 'premium_test.dart' show openPaywall;
import 'support/fakes.dart';

void main() {
  testWidgets(
    "AC-4 the trip currency can't be changed after the trip is created",
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(
          trips: [sampleTrip()],
          expenses: [sampleExpense(id: 'e1')],
        ),
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('trip_menu_t-lisbon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit trip'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "The trip currency can't be changed after the trip is created.",
        ),
        findsOneWidget,
      );
      await tapOn(tester, find.byKey(const Key('trip_currency')));
      expect(find.byKey(const Key('currency_search')), findsNothing);
      await tester.enterText(find.byKey(const Key('trip_name')), 'Porto');
      await tapOn(tester, find.byKey(const Key('save_trip')));
      expect(h.repo.trips['t-lisbon']!.baseCurrency, 'EUR');
    },
  );

  testWidgets(
    'AC-19 when fetching a published rate fails, the form says so and Try again fetches it',
    (tester) async {
      final h = await openTrip(tester);
      h.rates.latestTable = null;
      await openAdd(tester);
      await tester.tap(find.byKey(const Key('expense_currency')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('currency_search')), 'USD');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_USD')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Couldn't get the rate. Check your connection or enter it yourself.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('rate_field')), findsOneWidget);

      h.rates.latestTable = const RateTable('2026-10-10', {
        'EUR': 1,
        'USD': 1.10,
      });
      await tapOn(tester, find.byKey(const Key('retry_rate')));
      expect(find.byKey(const Key('rate_line')), findsOneWidget);
      expect(find.byKey(const Key('retry_rate')), findsNothing);
    },
  );

  testWidgets(
    'AC-45 a rewarded video closed early still counts toward the 3 a day',
    (tester) async {
      final h = await openPaywall(tester, source: PaywallSource.export);
      h.ads.rewardEarned = false;
      h.ads.ready.value = true;
      await tester.pumpAndSettle();
      await tapOn(tester, find.byKey(const Key('watch_video')));
      final state = h.state(tester);
      expect(state.passActive, isFalse);
      expect(state.rewardedWatchedToday, 1);
    },
  );

  testWidgets('AC-43 scrolling an ad away and back does not request a new ad', (
    tester,
  ) async {
    final h = await openTrip(
      tester,
      expenses: [
        for (var i = 0; i < 12; i++)
          sampleExpense(id: 'e$i', title: 'Expense $i', amount: 1000 + i),
      ],
    );
    final list = find.byKey(const Key('expense_list'));
    await tester.dragUntilVisible(
      find.byKey(const Key('expenses_ad_1')),
      list,
      const Offset(0, -200),
    );
    expect(h.ads.nativeRequests, 1);
    for (var i = 0; i < 6; i++) {
      await tester.drag(list, const Offset(0, 400));
      await tester.pumpAndSettle();
    }
    await tester.dragUntilVisible(
      find.byKey(const Key('expenses_ad_1')),
      list,
      const Offset(0, -200),
    );
    expect(h.ads.nativeRequests, 1);
  });

  test('AC-40 a backup naming people who are not in the trip is rejected', () {
    final good = Backup(
      savedAt: DateTime(2026, 10, 1),
      data: Snapshot(
        trips: [sampleTrip()],
        expenses: [sampleExpense(id: 'e1')],
      ),
    );
    expect(Backup.decode(good.encode()).expenseCount, 1);
    final bad = jsonDecode(good.encode()) as Map<String, dynamic>;
    (bad['expenses'] as List).first['paidBy'] = 'p-ghost';
    expect(() => Backup.decode(jsonEncode(bad)), throwsFormatException);
  });

  test('AC-22 letter currency symbols are separated from the amount', () {
    expect(formatMoney(1250, 'CHF'), 'CHF 12.50');
    expect(formatMoney(1250, 'EUR'), '€12.50');
  });

  test('AC-22 shares of very large amounts never overflow', () {
    // Rp 50,000,000 (5e9 minor units) split between 2, then converted.
    final parts = distribute(5000000000, [2500000000, 2500000000]);
    expect(parts, [2500000000, 2500000000]);
    final converted = distribute(4999999999, [2500000000, 2500000000]);
    expect(converted.reduce((a, b) => a + b), 4999999999);
    expect(converted.every((v) => v > 0), isTrue);
    final balances = balancesFor(
      Trip(
        id: 't',
        name: 'Bali',
        baseCurrency: 'IDR',
        cover: 0,
        participants: const [ana, ben],
        createdAt: DateTime(2026, 1, 1),
      ),
      [
        sampleExpense(
          id: 'e1',
          tripId: 't',
          amount: 5000000000,
          currency: 'IDR',
          among: const ['p-ana', 'p-ben'],
        ),
      ],
      const [],
    );
    expect(balances['p-ana'], 2500000000);
    expect(balances['p-ben'], -2500000000);
  });

  test('AC-40 backups with impossible data are rejected', () {
    String withTrip(Trip t, {List<Expense> expenses = const []}) => Backup(
      savedAt: DateTime(2026, 10, 1),
      data: Snapshot(trips: [t], expenses: expenses),
    ).encode();
    expect(
      () => Backup.decode(withTrip(sampleTrip(people: const [ana]))),
      throwsFormatException,
    );
    expect(
      () => Backup.decode(
        withTrip(
          sampleTrip(),
          expenses: [
            sampleExpense(
              id: 'e1',
              method: SplitMethod.percent,
              inputs: const {'p-ana': 5000, 'p-ben': 2000, 'p-cleo': 2000},
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => Backup.decode(
        withTrip(sampleTrip(), expenses: [sampleExpense(id: 'e1', amount: 0)]),
      ),
      throwsFormatException,
    );
  });

  testWidgets(
    'AC-36 AC-42 after "Try again" on a load error, launch checks still run',
    (tester) async {
      usePhone(tester);
      final h = Harness(initial: Snapshot(trips: [sampleTrip()]));
      h.repo.failLoads = 1;
      await h.pump(tester, startServices: true);
      expect(find.byKey(const Key('retry')), findsOneWidget);
      expect(h.ads.started, 0);
      await tester.tap(find.byKey(const Key('retry')));
      await tester.pumpAndSettle();
      expect(find.text('Lisbon weekend'), findsOneWidget);
      expect(h.ads.started, 1);
      expect(h.rates.latestCalls, greaterThan(0));
    },
  );

  testWidgets(
    'AC-40a AC-42 when Premium lapses on resume, consent and ads start',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        premium: true,
        initial: Snapshot(trips: [sampleTrip()]),
      );
      h.billing.active = true;
      await h.pump(tester, startServices: true);
      expect(h.ads.started, 0);
      h.billing.active = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.state(tester).isPremium, isFalse);
      expect(h.ads.started, 1);
    },
  );

  testWidgets('AC-15 a failed delete keeps the expense and says so', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: [sampleExpense(id: 'e1')]);
    h.repo.failDeletes = true;
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't delete the expense. Please try again."),
      findsOneWidget,
    );
    expect(h.repo.expenses, hasLength(1));
  });

  testWidgets('AC-39 tapping Save twice creates one category', (tester) async {
    usePhone(tester);
    final h = Harness(premium: true);
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new_category')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('category_name')), 'Tips');
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save_category'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.repo.categories, hasLength(1));
  });
}
