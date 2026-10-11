import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trippi/data/backup.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/data/repository.dart';
import 'package:trippi/services/exporter.dart';
import 'package:trippi/services/rates.dart';
import 'package:trippi/state/app_state.dart';

import 'support/fakes.dart';

AppState stateWith(Repository repo) => AppState(
  AppServices(
    repository: repo,
    rates: FakeRates(),
    billing: FakeBilling(),
    ads: FakeAds(),
    files: FakeFiles(),
    clock: () => DateTime(2026, 10, 11, 12),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'AC-48 data is stored in a local database and survives a restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('trippi');
      final path = '${dir.path}/trippi.db';
      final first = SqliteRepository(factory: databaseFactoryFfi, path: path);
      final s1 = stateWith(first);
      await s1.load();
      await s1.saveTrip(sampleTrip());
      await s1.saveExpense(sampleExpense(id: 'e1'));
      await s1.savePayment(
        Payment(
          id: 'pay1',
          tripId: 't-lisbon',
          fromId: 'p-ben',
          toId: 'p-ana',
          amountMinor: 3000,
          date: DateTime(2026, 10, 4),
          createdAt: DateTime(2026, 10, 4),
        ),
      );
      await s1.saveCategory(
        const CustomCategory(
          id: 'c1',
          name: 'Ski pass',
          iconKey: 'downhill_skiing',
          colorIndex: 8,
        ),
      );
      await s1.setThemeMode(ThemeMode.dark);
      await first.close();

      // A fresh repository on the same file, as after an app restart.
      final second = SqliteRepository(factory: databaseFactoryFfi, path: path);
      final s2 = stateWith(second);
      await s2.load();
      expect(s2.trips.single.name, 'Lisbon weekend');
      expect(s2.expensesOf('t-lisbon').single.amountMinor, 9000);
      expect(s2.paymentsOf('t-lisbon').single.amountMinor, 3000);
      expect(s2.customCategories.single.name, 'Ski pass');
      expect(s2.themeMode, ThemeMode.dark);

      // AC-5 deleting a trip removes its expenses and payments from storage.
      await s2.deleteTrip('t-lisbon');
      await second.close();
      final third = SqliteRepository(factory: databaseFactoryFfi, path: path);
      final snap = await third.load();
      expect(snap.trips, isEmpty);
      expect(snap.expenses, isEmpty);
      expect(snap.payments, isEmpty);
      await third.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'AC-48 a database that cannot open shows a load error instead of crashing',
    () async {
      final repo = SqliteRepository(
        factory: databaseFactoryFfi,
        path: '/proc/forbidden/trippi.db',
      );
      final s = stateWith(repo);
      await s.load();
      expect(s.loaded, isFalse);
      expect(s.loadError, isNotNull);
    },
  );

  test('AC-18 the latest rates are cached for offline use', () async {
    final repo = MemoryRepository();
    final s = stateWith(repo);
    await s.load();
    await s.refreshRates();
    final again = stateWith(repo);
    await again.load();
    expect(again.latestRates?.rate('USD', 'EUR'), closeTo(1 / 1.10, 1e-9));
    expect(again.latestRates?.date, '2026-10-10');
    expect(RateTable.fromJson({'date': 'x'}), isNull);
  });

  group('backup', () {
    test('AC-40 a backup file round-trips every trip', () async {
      final s = stateWith(MemoryRepository());
      await s.load();
      await s.saveTrip(sampleTrip());
      await s.saveExpense(sampleExpense(id: 'e1'));
      final text = s.makeBackup().encode();
      final b = Backup.decode(text);
      expect(b.tripCount, 1);
      expect(b.expenseCount, 1);
      expect(b.data.trips.single.participants.length, 3);
    });

    test('AC-40 an invalid file is rejected', () {
      expect(() => Backup.decode('hello'), throwsFormatException);
      expect(
        () => Backup.decode(jsonEncode({'format': 'other'})),
        throwsFormatException,
      );
      expect(
        () => Backup.decode(
          jsonEncode({
            'format': Backup.marker,
            'version': 1,
            'savedAt': '2026-10-11T12:00:00',
            'trips': [],
            'expenses': [sampleExpense(id: 'e1').toJson()],
            'payments': [],
            'categories': [],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('exports', () {
    late AppState s;
    setUp(() async {
      s = stateWith(MemoryRepository());
      await s.load();
      await s.saveTrip(sampleTrip());
      await s.saveExpense(sampleExpense(id: 'e1', amount: 9000));
      await s.saveExpense(
        sampleExpense(
          id: 'e2',
          title: 'Taxi',
          amount: 3000,
          paidBy: 'p-ben',
          category: 'transport',
        ),
      );
    });

    test('AC-31 the text summary lists total, balances and payments', () {
      final text = tripSummaryText(s, s.trips.single);
      expect(text, contains('Trippi · Lisbon weekend'));
      expect(text, contains('Total: €120.00 (2 expenses)'));
      expect(text, contains('Ana: gets back €50.00'));
      expect(text, contains('Ben: owes €10.00'));
      expect(text, contains('Cleo: owes €40.00'));
      expect(text, contains('Cleo pays Ana €40.00'));
      expect(text, contains('Ben pays Ana €10.00'));
    });

    Future<void> addPayment() => s.savePayment(
      Payment(
        id: 'pay1',
        tripId: 't-lisbon',
        fromId: 'p-cleo',
        toId: 'p-ana',
        amountMinor: 1500,
        date: DateTime(2026, 10, 5),
        createdAt: DateTime(2026, 10, 5),
      ),
    );

    test(
      'AC-32 the PDF holds the summary, balances, payments and every expense',
      () async {
        await addPayment();
        final r = tripReport(s, s.trips.single);
        expect(r.title, 'Lisbon weekend');
        expect(r.summary, 'Total EUR 120.00 · 2 expenses · 3 people');
        final sections = {for (final x in r.sections) x.heading: x.rows};
        expect(sections['Balances'], [
          ['Ana', 'gets back EUR 35.00'],
          ['Ben', 'owes EUR 10.00'],
          ['Cleo', 'owes EUR 25.00'],
        ]);
        expect(sections['To settle up'], [
          ['Cleo', 'Ana', 'EUR 25.00'],
          ['Ben', 'Ana', 'EUR 10.00'],
        ]);
        expect(sections['Payments'], [
          ['5 Oct 2026', 'Cleo', 'Ana', 'EUR 15.00'],
        ]);
        expect(sections['Expenses']!.map((row) => row[1]).toSet(), {
          'Dinner',
          'Taxi',
        });
        expect(sections['Expenses']!.firstWhere((row) => row[1] == 'Taxi'), [
          '3 Oct 2026',
          'Taxi',
          'Transport',
          'Ben',
          'EUR 30.00',
          'EUR 30.00',
        ]);

        final bytes = await tripPdf(s, s.trips.single);
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(2000));
        expect(
          exportFileName(s.trips.single, 'pdf'),
          'trippi-lisbon-weekend.pdf',
        );
      },
    );

    test(
      'AC-33 the Excel export has Expenses, Balances and Payments sheets',
      () async {
        await addPayment();
        final bytes = tripXlsx(s, s.trips.single);
        final book = Excel.decodeBytes(bytes);
        expect(book.tables.keys.toSet(), {'Expenses', 'Balances', 'Payments'});
        final expenses = book.tables['Expenses']!;
        expect(expenses.maxRows, 3);
        expect(expenses.row(0).first?.value.toString(), 'Date');
        final titles = {
          for (var i = 1; i < 3; i++) expenses.row(i)[1]?.value.toString(),
        };
        expect(titles, {'Dinner', 'Taxi'});
        final balances = book.tables['Balances']!;
        expect(balances.row(1)[0]?.value.toString(), 'Ana');
        expect(double.parse(balances.row(1)[1]!.value.toString()), 35);
        final payments = book.tables['Payments']!;
        expect(payments.maxRows, 2);
        final row = [for (final c in payments.row(1)) c?.value.toString()];
        expect(row, containsAllInOrder(['Cleo', 'Ana']));
        expect(double.parse(row.last!), 15);
      },
    );
  });
}
