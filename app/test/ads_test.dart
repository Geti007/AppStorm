import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';

import 'expenses_test.dart' show openTrip;
import 'support/fakes.dart';

List<Trip> trips(int n) => [
  for (var i = 0; i < n; i++)
    sampleTrip(id: 't$i', name: 'Trip $i', created: DateTime(2026, 1, 1 + i)),
];

List<Expense> expenses(int n, {String tripId = 't-lisbon'}) => [
  for (var i = 0; i < n; i++)
    sampleExpense(
      id: 'e${i.toString().padLeft(2, '0')}',
      tripId: tripId,
      title: 'Expense $i',
      amount: 1000 + i,
      date: DateTime(2026, 10, 1 + i % 5),
    ),
];

void main() {
  testWidgets(
    'AC-42 at launch the consent flow runs for free users before any ad',
    (tester) async {
      usePhone(tester);
      final h = Harness(initial: Snapshot(trips: trips(3)));
      h.ads.canRequest.value = false;
      await h.pump(tester, startServices: true);
      expect(h.ads.started, 1);
      // No ad is requested until consent allows it.
      expect(h.ads.nativeRequests, 0);
      expect(find.byKey(const Key('native_ad')), findsNothing);
      h.ads.canRequest.value = true;
      await tester.pumpAndSettle();
      expect(h.ads.nativeRequests, 1);
      expect(find.byKey(const Key('native_ad')), findsOneWidget);
    },
  );

  testWidgets(
    'AC-42 Settings shows Privacy options only when the consent SDK requires it',
    (tester) async {
      usePhone(tester);
      final h = Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('open_settings')));
      await tester.pumpAndSettle();
      final options = find.byKey(
        const Key('privacy_options'),
        skipOffstage: false,
      );
      expect(options, findsNothing);
      h.ads.privacyRequired.value = true;
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('privacy_options')),
        find.byKey(const Key('settings_list')),
        const Offset(0, -300),
      );
      expect(find.text('Privacy options'), findsOneWidget);
    },
  );

  testWidgets('AC-43 a Sponsored native ad appears after the 2nd trip', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: trips(3)));
    await h.pump(tester);
    expect(find.text('Sponsored'), findsOneWidget);
    final ad = tester.getTopLeft(find.byKey(const Key('native_ad'))).dy;
    expect(tester.getTopLeft(find.text('Trip 1')).dy, lessThan(ad));
    expect(tester.getTopLeft(find.text('Trip 2')).dy, lessThan(ad));
    await tester.drag(
      find.byKey(const Key('trips_list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Trip 0')).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('native_ad'))).dy),
    );
  });

  testWidgets('AC-43 no ad with fewer than 2 trips', (tester) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: trips(1)));
    await h.pump(tester);
    expect(find.byKey(const Key('native_ad')), findsNothing);
    expect(h.ads.nativeRequests, 0);
  });

  testWidgets('AC-43 an ad that fails to load leaves no gap', (tester) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: trips(3)));
    h.ads.nativeLoads = false;
    await h.pump(tester);
    expect(find.byKey(const Key('native_ad')), findsNothing);
    final b1 = tester.getBottomLeft(find.byKey(const Key('trip_t1'))).dy;
    final t0 = tester.getTopLeft(find.byKey(const Key('trip_t0'))).dy;
    // Only the normal 16 px spacing (plus the empty slot's own separator).
    expect(t0 - b1, lessThanOrEqualTo(32));
  });

  testWidgets(
    'AC-43 the expense list shows an ad after every 10th expense, at most 2',
    (tester) async {
      final h = await openTrip(tester, expenses: expenses(35));
      final list = find.byKey(const Key('expense_list'));
      await tester.dragUntilVisible(
        find.byKey(const Key('expenses_ad_1')),
        list,
        const Offset(0, -200),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('expenses_ad_1')),
          matching: find.text('Sponsored'),
        ),
        findsOneWidget,
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('expenses_ad_2')),
        list,
        const Offset(0, -200),
      );
      // Scroll to the end: no third ad even after the 30th expense.
      for (var i = 0; i < 20; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Expense 0'), findsOneWidget);
      expect(h.ads.nativeRequests, 2);
    },
  );

  testWidgets('AC-43 the first list ad sits right after the 10th expense', (
    tester,
  ) async {
    await openTrip(
      tester,
      expenses: [
        for (var i = 0; i < 12; i++)
          sampleExpense(
            id: 'e$i',
            title: 'Expense $i',
            amount: 1000 + i,
            date: DateTime(2026, 10, 3),
          ),
      ],
    );
    // A very tall window so every row is built at once.
    tester.view.physicalSize = const Size(1179, 12000);
    await tester.pumpAndSettle();
    final adTop = tester.getTopLeft(find.byKey(const Key('expenses_ad_1'))).dy;
    final above = [
      for (var i = 0; i < 12; i++)
        if (tester.getTopLeft(find.text('Expense $i')).dy < adTop) i,
    ];
    expect(above, hasLength(10));
  });

  testWidgets('AC-43 fewer than 10 expenses means no ad in the list', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: expenses(9));
    expect(h.ads.nativeRequests, 0);
  });

  testWidgets('AC-44 forms, settle, settings and export show no ads', (
    tester,
  ) async {
    final h = await openTrip(tester, expenses: expenses(12));
    final before = h.ads.nativeRequests;
    await tester.tap(find.byKey(const Key('add_expense')));
    await tester.pumpAndSettle();
    expect(find.text('Sponsored'), findsNothing);
    await tester.tap(find.byKey(const Key('close_form')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_balances')));
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('record_payment')));
    expect(find.text('Sponsored'), findsNothing);
    await tester.tap(find.byKey(const Key('close_form')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_export')));
    await tester.pumpAndSettle();
    expect(find.text('Sponsored'), findsNothing);
    expect(h.ads.nativeRequests, before);
  });

  testWidgets('AC-44 empty states show no ads', (tester) async {
    usePhone(tester);
    final h = Harness();
    await h.pump(tester);
    expect(find.text('No trips yet'), findsOneWidget);
    expect(h.ads.nativeRequests, 0);
  });

  testWidgets('AC-46 Premium users never load or request ads', (tester) async {
    usePhone(tester);
    final h = Harness(
      premium: true,
      initial: Snapshot(
        trips: trips(3),
        expenses: expenses(25, tripId: 't2'),
      ),
    );
    await h.pump(tester, startServices: true);
    expect(h.ads.started, 0);
    expect(find.text('Sponsored'), findsNothing);
    await tester.tap(find.text('Trip 2'));
    await tester.pumpAndSettle();
    expect(find.text('Expense 24'), findsOneWidget);
    // Scroll past the 10th and 20th rows, where free users see ads.
    await tester.dragUntilVisible(
      find.text('Expense 0'),
      find.byKey(const Key('expense_list')),
      const Offset(0, -300),
    );
    expect(find.text('Sponsored'), findsNothing);
    expect(h.ads.nativeRequests, 0);
  });

  testWidgets('AC-36 ads disappear as soon as Premium starts', (tester) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: trips(3)));
    await h.pump(tester);
    expect(find.text('Sponsored'), findsOneWidget);
    await h.state(tester).setPremium(true);
    await tester.pumpAndSettle();
    expect(find.text('Sponsored'), findsNothing);
  });
}
