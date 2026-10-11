import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/widgets/common.dart';

import 'support/fakes.dart';

/// The smallest phone the app supports (320 x 568 dp).
void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2;
}

const longTrip = 'Grand tour of the Amalfi Coast 🍋🚤 2026';
const people = [
  Participant(id: 'p-ana', name: 'Ana-Sofia Ramalho 🌍'),
  Participant(id: 'p-ben', name: 'בנימין'),
  Participant(id: 'p-cleo', name: 'كليوباترا'),
];

Snapshot hardData() => Snapshot(
  trips: [
    Trip(
      id: 't-lisbon',
      name: longTrip,
      baseCurrency: 'EUR',
      cover: 2,
      participants: people,
      createdAt: DateTime(2026, 10, 1),
      startDate: DateTime(2026, 10, 2),
      endDate: DateTime(2026, 10, 5),
    ),
  ],
  expenses: [
    sampleExpense(
      id: 'e1',
      title: 'Very long dinner title at a seaside restaurant 🍝🍷 in Positano',
      amount: 123456789,
    ),
    sampleExpense(
      id: 'e2',
      title: 'מונית לשדה התעופה',
      amount: 4500,
      paidBy: 'p-ben',
      category: 'transport',
    ),
  ],
);

Future<void> noOverflow(WidgetTester tester, String screen) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$screen overflowed');
}

Future<void> walkScreens(WidgetTester tester) async {
  await noOverflow(tester, 'trips');
  await tester.tap(find.text(longTrip));
  await noOverflow(tester, 'expenses');
  await tester.tap(find.byKey(const Key('add_expense')));
  await noOverflow(tester, 'expense form');
  await tester.tap(find.byKey(const Key('close_form')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tab_balances')));
  await noOverflow(tester, 'balances');
  await tester.tap(find.byKey(const Key('tab_stats')));
  await noOverflow(tester, 'stats');
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open_settings')));
  await noOverflow(tester, 'settings');
}

void main() {
  testWidgets(
    'AC-49 a 320x568 phone with long names, emoji, right-to-left text and huge amounts',
    (tester) async {
      useSmallPhone(tester);
      await Harness(initial: hardData()).pump(tester);
      await walkScreens(tester);
    },
  );

  testWidgets('AC-47 AC-49 the same screens in dark mode at 150% text', (
    tester,
  ) async {
    useSmallPhone(tester, textScale: 1.5);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await Harness(premium: true, initial: hardData()).pump(tester);
    await walkScreens(tester);
  });

  testWidgets('AC-49 a landscape phone shows the trip without overflow', (
    tester,
  ) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(2556, 1179);
    await Harness(initial: hardData()).pump(tester);
    await noOverflow(tester, 'trips landscape');
    await tester.tap(find.text(longTrip));
    await noOverflow(tester, 'dashboard landscape');
    await tester.tap(find.byKey(const Key('add_expense')));
    await noOverflow(tester, 'expense form landscape');
  });

  for (final size in [const Size(1600, 2560), const Size(2560, 1600)]) {
    final shape = size.width < size.height ? 'portrait' : 'landscape';
    testWidgets(
      'AC-49 a tablet in $shape shows every screen without overflow',
      (tester) async {
        usePhone(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2;
        await Harness(initial: hardData()).pump(tester);
        // Wide windows keep the app in a readable column.
        expect(
          tester.getSize(find.byType(Scaffold).first).width,
          ReadableWidth.maxWidth,
        );
        await walkScreens(tester);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text(longTrip));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open_export')));
        await noOverflow(tester, 'export sheet');
        await tester.tap(find.byKey(const Key('export_pdf')));
        await noOverflow(tester, 'paywall');
      },
    );
  }

  testWidgets('AC-2 tapping Save twice fast creates one trip', (tester) async {
    usePhone(tester);
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('create_first_trip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trip_name')), 'Rome');
    for (final n in ['Ana', 'Ben']) {
      await tester.enterText(find.byKey(const Key('person_name')), n);
      await tapOn(tester, find.byKey(const Key('add_person')));
    }
    final save = find.byKey(const Key('save_trip'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.repo.trips, hasLength(1));
  });

  testWidgets('AC-9 tapping Save twice fast creates one expense', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(initial: Snapshot(trips: [sampleTrip()]));
    await h.pump(tester);
    await tester.tap(find.text('Lisbon weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_expense')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense_title')), 'Lunch');
    await tester.enterText(find.byKey(const Key('expense_amount')), '30');
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save_expense'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.repo.expenses, hasLength(1));
  });

  testWidgets('AC-18 with no network and no cached rate the app still opens', (
    tester,
  ) async {
    usePhone(tester);
    final h = Harness(initial: hardData());
    h.rates.latestTable = null;
    h.rates.historicalTable = null;
    await h.pump(tester, startServices: true);
    expect(find.text(longTrip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
