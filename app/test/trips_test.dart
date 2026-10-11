import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/premium_screen.dart';
import 'package:trippi/screens/trip_dashboard_screen.dart';

import 'support/fakes.dart';

Future<void> addPerson(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('person_name')), name);
  await tapOn(tester, find.byKey(const Key('add_person')));
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('save_trip')));

void main() {
  testWidgets(
    'AC-1 no trips shows the empty state and its button opens the form',
    (tester) async {
      usePhone(tester);
      final h = Harness();
      await h.pump(tester);
      expect(find.text('No trips yet'), findsOneWidget);
      expect(
        find.text(
          'Create a trip, add your travel crew, and start tracking shared costs.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('new_trip')), findsNothing);
      await tester.tap(find.byKey(const Key('create_first_trip')));
      await tester.pumpAndSettle();
      expect(find.text('New trip'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-2 Save stays disabled until a name and 2 people; the trip appears at the top',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(trips: [sampleTrip(name: 'Older trip')]),
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('new_trip')));
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('crew_hint')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('trip_name')),
        'Tokyo spring',
      );
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);
      await addPerson(tester, 'Mia');
      expect(saveButton(tester).onPressed, isNull);
      await addPerson(tester, 'Leo');
      expect(saveButton(tester).onPressed, isNotNull);

      // The name is required even with 2 people.
      await tester.enterText(find.byKey(const Key('trip_name')), '   ');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('trip_name')),
        'Tokyo spring',
      );
      await tester.pump();

      // The name field is limited to 40 characters.
      final field = tester.widget<TextField>(
        find.byKey(const Key('trip_name')),
      );
      expect(field.maxLength, 40);

      await tapOn(tester, find.byKey(const Key('save_trip')));
      final cards = find.byWidgetPredicate(
        (w) =>
            w is Card &&
            (w.key is ValueKey<String>) &&
            (w.key! as ValueKey<String>).value.startsWith('trip_'),
      );
      expect(cards, findsNWidgets(2));
      final firstTitle = tester.getTopLeft(find.text('Tokyo spring'));
      final secondTitle = tester.getTopLeft(find.text('Older trip'));
      expect(firstTitle.dy, lessThan(secondTitle.dy));
      expect(h.repo.trips.length, 2);
    },
  );

  testWidgets('AC-3 participant names must be unique and non-empty', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('create_first_trip')));
    await tester.pumpAndSettle();
    await addPerson(tester, '');
    expect(find.text('Enter a name'), findsOneWidget);
    await addPerson(tester, 'Ana');
    await addPerson(tester, 'ana');
    expect(find.text('Name already in this trip'), findsOneWidget);
    expect(find.byKey(const Key('person_Ana')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('person_name')),
    );
    expect(field.maxLength, 24);
  });

  testWidgets('AC-4 editing a trip; a person in an expense cannot be removed', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(
      initial: Snapshot(
        trips: [sampleTrip()],
        expenses: [
          sampleExpense(id: 'e1', among: ['p-ana', 'p-ben']),
        ],
      ),
    );
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('trip_menu_t-lisbon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit trip'));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip'), findsOneWidget);

    await tapOn(tester, find.byKey(const Key('remove_Ben')));
    expect(
      find.text(
        "Ben is part of expenses or payments in this trip, so they can't be removed.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('person_Ben')), findsOneWidget);

    // Cleo is in no expense, so she can be removed.
    await tapOn(tester, find.byKey(const Key('remove_Cleo')));
    expect(find.byKey(const Key('person_Cleo')), findsNothing);

    await tester.enterText(find.byKey(const Key('trip_name')), 'Porto weekend');
    await tapOn(tester, find.byKey(const Key('cover_2')));
    await tapOn(tester, find.byKey(const Key('save_trip')));
    final saved = h.repo.trips['t-lisbon']!;
    expect(saved.name, 'Porto weekend');
    expect(saved.cover, 2);
    expect(saved.participants.map((p) => p.name), ['Ana', 'Ben']);
    expect(find.text('Porto weekend'), findsOneWidget);
  });

  testWidgets(
    'AC-5 deleting a trip asks first, then removes it with its expenses',
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
      await tester.tap(find.text('Delete trip'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this trip?'), findsOneWidget);
      expect(
        find.text(
          "Lisbon weekend and all its expenses and payments will be deleted. This can't be undone.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('dialog_cancel')));
      await tester.pumpAndSettle();
      expect(h.repo.trips, hasLength(1));

      await tester.tap(find.byKey(const Key('trip_menu_t-lisbon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(h.repo.trips, isEmpty);
      expect(h.repo.expenses, isEmpty);
      expect(find.text('No trips yet'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-6 a 4th trip on the free plan opens Premium instead of the form',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(
          trips: [
            for (var i = 0; i < 3; i++) sampleTrip(id: 't$i', name: 'Trip $i'),
          ],
        ),
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('new_trip')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text('New trip'), findsNothing);
    },
  );

  testWidgets('AC-6 Premium users can create any number of trips', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(
      premium: true,
      initial: Snapshot(
        trips: [
          for (var i = 0; i < 5; i++) sampleTrip(id: 't$i', name: 'Trip $i'),
        ],
      ),
    );
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('new_trip')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('New trip'), findsWidgets);
  });

  testWidgets('AC-7 a 7th participant on the free plan opens Premium', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('create_first_trip')));
    await tester.pumpAndSettle();
    for (final n in ['A1', 'A2', 'A3', 'A4', 'A5', 'A6']) {
      await addPerson(tester, n);
    }
    expect(find.text('6 people'), findsOneWidget);
    await addPerson(tester, 'A7');
    expect(find.byType(PremiumScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('close_premium')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person_A7')), findsNothing);
  });

  testWidgets('AC-7 Premium users can add more than 6 participants', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(premium: true);
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('create_first_trip')));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 8; i++) {
      await addPerson(tester, 'P$i');
    }
    expect(find.text('8 people'), findsOneWidget);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets(
    'AC-8 trips are newest first and cards show name, dates, total and people',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(
          trips: [
            sampleTrip(
              id: 'old',
              name: 'Old trip',
              created: DateTime(2026, 1, 1),
            ),
            sampleTrip(
              id: 'new',
              name: 'Summer trip',
              created: DateTime(2026, 9, 1),
            ),
          ],
          expenses: [
            sampleExpense(id: 'e1', tripId: 'new', amount: 4550),
            sampleExpense(id: 'e2', tripId: 'new', amount: 1000),
          ],
        ),
      );
      await h.pump(tester);
      expect(
        tester.getTopLeft(find.text('Summer trip')).dy,
        lessThan(tester.getTopLeft(find.text('Old trip')).dy),
      );
      expect(find.text('2 – 5 Oct 2026'), findsNWidgets(2));
      expect(find.byKey(const Key('trip_total_new')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('trip_total_new'))).data,
        '€55.50',
      );
      expect(find.text('3 people'), findsNWidgets(2));
    },
  );

  testWidgets('AC-8 a trip card opens the trip dashboard', (tester) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: [sampleTrip()]));
    await h.pump(tester);
    await tester.tap(find.text('Lisbon weekend'));
    await tester.pumpAndSettle();
    expect(find.byType(TripDashboardScreen), findsOneWidget);
  });
}
