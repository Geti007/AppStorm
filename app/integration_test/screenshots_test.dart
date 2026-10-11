// Store screenshots. The factory runs this on an Android emulator with
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart
// Each takeScreenshot name must match an "id" in store/listing.json "screenshots".
//
// The app runs with realistic sample data on an in-memory store, with
// Premium on so no ad slot appears, and with fake services so nothing leaves
// the device.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/data/repository.dart';
import 'package:trippi/main.dart';
import 'package:trippi/state/app_state.dart';
import 'package:trippi/widgets/common.dart';

import '../test/support/fakes.dart';

const crew = [
  Participant(id: 'p-maya', name: 'Maya'),
  Participant(id: 'p-jonas', name: 'Jonas'),
  Participant(id: 'p-sofia', name: 'Sofia'),
  Participant(id: 'p-leo', name: 'Leo'),
];

const all = ['p-maya', 'p-jonas', 'p-sofia', 'p-leo'];

Expense spend(
  String id,
  String title,
  int amount,
  String paidBy,
  String category,
  int day, {
  int month = 9,
  String currency = 'EUR',
  double rate = 1,
  List<String> among = all,
}) => Expense(
  id: id,
  tripId: 't-lisbon',
  title: title,
  amountMinor: amount,
  currency: currency,
  rate: rate,
  categoryId: category,
  date: DateTime(2026, month, day),
  paidBy: paidBy,
  method: SplitMethod.equal,
  splitAmong: among,
  splitInputs: const {},
  createdAt: DateTime(2026, month, day, 20),
);

Snapshot sampleData() => Snapshot(
  trips: [
    Trip(
      id: 't-iceland',
      name: 'Iceland road trip',
      baseCurrency: 'ISK',
      cover: 3,
      participants: crew.take(3).toList(),
      createdAt: DateTime(2026, 3, 1),
      startDate: DateTime(2026, 6, 14),
      endDate: DateTime(2026, 6, 22),
    ),
    Trip(
      id: 't-tokyo',
      name: 'Tokyo in spring',
      baseCurrency: 'JPY',
      cover: 1,
      participants: crew.toList(),
      createdAt: DateTime(2026, 2, 1),
      startDate: DateTime(2026, 4, 2),
      endDate: DateTime(2026, 4, 9),
    ),
    Trip(
      id: 't-lisbon',
      name: 'Lisbon with friends',
      baseCurrency: 'EUR',
      cover: 0,
      participants: crew.toList(),
      createdAt: DateTime(2026, 8, 20),
      startDate: DateTime(2026, 9, 18),
      endDate: DateTime(2026, 9, 22),
    ),
  ],
  expenses: [
    spend('l1', 'Apartment in Alfama', 48000, 'p-maya', 'accommodation', 18),
    spend('l2', 'Dinner at the marisqueira', 13650, 'p-jonas', 'food', 18),
    spend('l3', 'Tram 28 day passes', 2560, 'p-sofia', 'transport', 19),
    spend('l4', 'Sintra palace tickets', 7800, 'p-leo', 'activities', 19),
    spend('l5', 'Pastéis de nata', 1240, 'p-maya', 'food', 20),
    spend('l6', 'Groceries for breakfast', 3415, 'p-sofia', 'groceries', 20),
    spend(
      'l7',
      'Sunset boat tour',
      18000,
      'p-jonas',
      'activities',
      21,
      currency: 'USD',
      rate: 0.92,
    ),
    spend('l8', 'Airport taxi', 3200, 'p-leo', 'transport', 22),
    // Iceland and Tokyo use whole krónur and yen (no minor units).
    for (final e in [
      spend(
        'i1',
        'Camper van',
        380000,
        'p-maya',
        'transport',
        14,
        month: 6,
        currency: 'ISK',
      ),
      spend(
        'i2',
        'Fuel',
        42500,
        'p-jonas',
        'transport',
        17,
        month: 6,
        currency: 'ISK',
      ),
      spend(
        'i3',
        'Glacier hike',
        89970,
        'p-sofia',
        'activities',
        19,
        month: 6,
        currency: 'ISK',
      ),
    ])
      e.copyWithTrip('t-iceland', ['p-maya', 'p-jonas', 'p-sofia']),
    for (final e in [
      spend(
        'k1',
        'Ryokan stay',
        168000,
        'p-jonas',
        'accommodation',
        3,
        month: 4,
        currency: 'JPY',
      ),
      spend(
        'k2',
        'Shinkansen to Kyoto',
        56000,
        'p-maya',
        'transport',
        5,
        month: 4,
        currency: 'JPY',
      ),
      spend(
        'k3',
        'Sushi dinner',
        38400,
        'p-leo',
        'food',
        6,
        month: 4,
        currency: 'JPY',
      ),
    ])
      e.copyWithTrip('t-tokyo', all),
  ],
  payments: [
    Payment(
      id: 'pay1',
      tripId: 't-lisbon',
      fromId: 'p-leo',
      toId: 'p-maya',
      amountMinor: 5000,
      date: DateTime(2026, 9, 22),
      createdAt: DateTime(2026, 9, 22, 18),
    ),
  ],
  settings: const {'onboarding_done': '1', 'premium': '1'},
);

extension on Expense {
  Expense copyWithTrip(String trip, List<String> among) => Expense(
    id: id,
    tripId: trip,
    title: title,
    amountMinor: amountMinor,
    currency: currency,
    rate: rate,
    categoryId: categoryId,
    date: date,
    paidBy: paidBy,
    method: method,
    splitAmong: among,
    splitInputs: splitInputs,
    createdAt: createdAt,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final billing = FakeBilling()..active = true;
    final services = AppServices(
      repository: MemoryRepository(sampleData()),
      rates: FakeRates(),
      billing: billing,
      ads: FakeAds(),
      files: FakeFiles(),
      clock: () => DateTime(2026, 9, 23, 10),
      openUrl: (_) async {},
      isIOS: false,
    );
    await tester.pumpWidget(TrippiApp(services: services));
    // Wait for the data to load before the first screenshot.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(SkeletonList).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('the app never loaded');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    // Required once on Android before the first screenshot.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    expect(find.text('Sponsored'), findsNothing);
    await binding.takeScreenshot('trips');

    await tester.tap(find.text('Lisbon with friends'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('trip_dashboard');

    await tester.tap(find.text('Sunset boat tour'));
    await tester.pumpAndSettle();
    // The caption is about splitting: scroll down to the split section,
    // with the Date field's label at the top so nothing is cut in half.
    final dateLabel = find.text('Date');
    await tester.scrollUntilVisible(
      find.text('Leo').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(tester.element(dateLabel));
    await tester.pumpAndSettle();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar).last).dy;
    expect(
      tester.getTopLeft(dateLabel).dy,
      greaterThanOrEqualTo(appBarBottom - 0.5),
    );
    expect(find.byKey(const Key('split_method')), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('expense_form');
    await tester.tap(find.byKey(const Key('close_form')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab_balances')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('balances');

    await tester.tap(find.byKey(const Key('tab_stats')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('stats');
  });
}
