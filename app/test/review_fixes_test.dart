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
}
