// End-to-end flows on a real device or emulator, with the real SQLite
// database. The store, ads, rates and share sheet are fakes, so nothing
// leaves the device and no real ad is ever requested.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:trippi/data/repository.dart';
import 'package:trippi/main.dart';
import 'package:trippi/state/app_state.dart';

import '../test/support/fakes.dart';

class Device {
  Device(this.path, {bool premium = false}) {
    if (premium) billing.active = true;
  }

  final String path;
  late SqliteRepository repo = SqliteRepository(path: path);
  final billing = FakeBilling();
  final ads = FakeAds();
  final rates = FakeRates();
  final files = FakeFiles();

  AppServices services() => AppServices(
    repository: repo,
    rates: rates,
    billing: billing,
    ads: ads,
    files: files,
    clock: () => DateTime(2026, 10, 11, 12),
    openUrl: (_) async {},
    isIOS: false,
  );

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(TrippiApp(services: services()));
    await tester.pumpAndSettle();
  }

  /// Closes the app and opens it again on the same database.
  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await repo.close();
    repo = SqliteRepository(path: path);
    await launch(tester);
  }
}

Future<String> freshDatabase(String name) async {
  final path = p.join(await getDatabasesPath(), 'it_$name.db');
  await deleteDatabase(path);
  return path;
}

/// Fails at once with the error if a frame reported one, so the failure
/// names the step instead of surfacing only when the test ends.
void noErrorAt(WidgetTester tester, String step) {
  final error = tester.takeException();
  if (error != null) fail('$step: $error');
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> addPerson(WidgetTester tester, String name) async {
  await type(tester, 'person_name', name);
  await tapOn(tester, find.byKey(const Key('add_person')));
}

Future<void> addExpense(
  WidgetTester tester,
  String title,
  String amount,
) async {
  await tester.tap(find.byKey(const Key('add_expense')));
  await tester.pumpAndSettle();
  await type(tester, 'expense_title', title);
  await type(tester, 'expense_amount', amount);
  await tapOn(tester, find.byKey(const Key('save_expense')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The check report keeps only the end of the output, so failures are
  // repeated briefly once every test has run.
  final failures = <String>[];
  final report = reportTestException;
  reportTestException = (details, description) {
    final stack = details.stack.toString().split('\n').take(6).join('\n');
    failures.add('$description\n${details.exceptionAsString()}\n$stack');
    report(details, description);
  };
  tearDownAll(() {
    for (final f in failures) {
      // ignore: avoid_print
      print('FAILED: ${f.length > 1400 ? f.substring(0, 1400) : f}');
    }
  });

  testWidgets(
    'AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart',
    (tester) async {
      final device = Device(await freshDatabase('settle'));
      await device.repo.setSetting('onboarding_done', '1');
      await device.repo.saveTrip(sampleTrip());
      await device.repo.saveExpense(sampleExpense(id: 'e1', amount: 9000));
      await device.launch(tester);

      await tester.tap(find.text('Lisbon weekend'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_balances')));
      await tester.pumpAndSettle();
      for (final from in ['Ben', 'Cleo']) {
        await tapOn(tester, find.byKey(Key('settle_${from}_Ana')));
        await tapOn(tester, find.byKey(const Key('save_payment')));
      }
      expect(find.text('All settled up'), findsOneWidget);

      await device.restart(tester);
      await tester.tap(find.text('Lisbon weekend'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_balances')));
      await tester.pumpAndSettle();
      expect(find.text('All settled up'), findsOneWidget);
      expect(find.text('Ben paid Ana'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-36 AC-46 Premium is re-checked with the store at launch and removes ads',
    (tester) async {
      final device = Device(await freshDatabase('premium'), premium: true);
      await device.repo.setSetting('onboarding_done', '1');
      for (var i = 0; i < 3; i++) {
        await device.repo.saveTrip(sampleTrip(id: 't$i', name: 'Trip $i'));
      }
      await device.launch(tester);
      expect(find.text('Sponsored'), findsNothing);
      expect(device.ads.started, 0);
      expect(device.ads.nativeRequests, 0);

      // The store says the subscription ended: ads come back on next launch.
      device.billing.active = false;
      await device.restart(tester);
      expect(device.ads.started, 1);
      expect(find.text('Sponsored'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart',
    (tester) async {
      final device = Device(await freshDatabase('first_run'));
      await device.launch(tester);
      noErrorAt(tester, 'launch');

      // Onboarding on first launch, then the empty trips list.
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      expect(find.text('No trips yet'), findsOneWidget);
      noErrorAt(tester, 'onboarding');

      await tester.tap(find.byKey(const Key('create_first_trip')));
      await tester.pumpAndSettle();
      await type(tester, 'trip_name', 'Lisbon weekend');
      noErrorAt(tester, 'trip name');
      for (final name in ['Ana', 'Ben', 'Cleo']) {
        await addPerson(tester, name);
        noErrorAt(tester, 'add person');
      }
      await tapOn(tester, find.byKey(const Key('save_trip')));
      noErrorAt(tester, 'save trip');
      await tester.tap(find.text('Lisbon weekend'));
      await tester.pumpAndSettle();

      await addExpense(tester, 'Dinner', '90');
      noErrorAt(tester, 'add expense');
      expect(find.text('Dinner'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab_balances')));
      await tester.pumpAndSettle();
      expect(find.text('+€60.00 gets back'), findsOneWidget);
      expect(find.text('−€30.00 owes'), findsNWidgets(2));
      noErrorAt(tester, 'balances');

      await device.restart(tester);
      noErrorAt(tester, 'restart');
      expect(find.text('No trips yet'), findsNothing);
      expect(find.text('Lisbon weekend'), findsOneWidget);
      await tester.tap(find.text('Lisbon weekend'));
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('header_total'))).data,
        '€90.00',
      );
      noErrorAt(tester, 'after restart');
    },
  );
}
