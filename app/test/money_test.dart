import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/currencies.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/data/money.dart';

import 'support/fakes.dart';

void main() {
  group('splits', () {
    test('AC-10 equal split gives leftover cents to the first people', () {
      expect(splitEqual(1000, 3), [334, 333, 333]);
      expect(splitEqual(1001, 3), [334, 334, 333]);
      expect(splitEqual(999, 3), [333, 333, 333]);
      final rnd = Random(1);
      for (var i = 0; i < 500; i++) {
        final amount = 1 + rnd.nextInt(1000000);
        final n = 1 + rnd.nextInt(12);
        final parts = splitEqual(amount, n);
        expect(parts.reduce((a, b) => a + b), amount);
        expect(parts.reduce(max) - parts.reduce(min), lessThanOrEqualTo(1));
      }
    });

    test(
      'AC-11 percentage split rounds to minor units and adds up exactly',
      () {
        // 33.34% / 33.33% / 33.33% of 100.00
        expect(splitPercent(10000, [3334, 3333, 3333]), [3334, 3333, 3333]);
        // 50/50 of 0.01: the leftover cent goes to the first person.
        expect(splitPercent(1, [5000, 5000]), [1, 0]);
        // A person with 0% gets nothing even when there is a leftover unit.
        expect(splitPercent(101, [0, 5000, 5000]), [0, 51, 50]);
        final rnd = Random(2);
        for (var i = 0; i < 500; i++) {
          final amount = 1 + rnd.nextInt(1000000);
          final a = rnd.nextInt(10001);
          final b = rnd.nextInt(10001 - a);
          final parts = splitPercent(amount, [a, b, 10000 - a - b]);
          expect(parts.reduce((x, y) => x + y), amount);
        }
      },
    );

    test('AC-11 percentages parse with up to 2 decimals', () {
      expect(parsePercent('33.33'), 3333);
      expect(parsePercent('50'), 5000);
      expect(parsePercent('12,5'), 1250);
      expect(parsePercent('1.234'), isNull);
      expect(parsePercent('abc'), isNull);
      expect(formatPercent(1250), '12.5%');
      expect(formatPercent(-500), '-5%');
      expect(formatPercent(-1234), '-12.34%');
    });

    test('AC-12 custom amounts are used exactly', () {
      final e = sampleExpense(
        id: 'e1',
        amount: 5000,
        method: SplitMethod.custom,
        among: ['p-ana', 'p-ben'],
        inputs: {'p-ana': 1250, 'p-ben': 3750},
      );
      expect(sharesOf(e), {'p-ana': 1250, 'p-ben': 3750});
    });
  });

  group('currencies', () {
    test('AC-17 minor units come from the bundled ISO 4217 list', () {
      expect(currencyFor('JPY').minorUnits, 0);
      expect(currencyFor('KRW').minorUnits, 0);
      expect(currencyFor('KWD').minorUnits, 3);
      expect(currencyFor('BHD').minorUnits, 3);
      expect(currencyFor('EUR').minorUnits, 2);
      expect(currencies.length, greaterThan(140));
      expect(searchCurrencies('yen').map((c) => c.code), contains('JPY'));
      expect(searchCurrencies('usd').first.code, 'USD');
      expect(currencyFor('JPY').hasAutoRate, isTrue);
      expect(currencyFor('VND').hasAutoRate, isFalse);
    });

    test('AC-9 AC-17 amounts allow no more decimals than the currency has', () {
      expect(parseAmount('12.50', 2).minor, 1250);
      expect(parseAmount('12,5', 2).minor, 1250);
      expect(parseAmount('1200', 0).minor, 1200);
      expect(parseAmount('12.5', 0).error, AmountError.tooManyDecimals);
      expect(parseAmount('1.234', 2).error, AmountError.tooManyDecimals);
      expect(parseAmount('1.234', 3).minor, 1234);
      expect(parseAmount('0', 2).error, AmountError.notPositive);
      expect(parseAmount('', 2).error, AmountError.empty);
      expect(parseAmount('12a', 2).error, AmountError.invalid);
    });

    test('AC-17 totals convert to the base currency rounded to its unit', () {
      // 1000 JPY at 0.0062 EUR per JPY = 6.20 EUR.
      expect(convert(1000, 'JPY', 0.0062, 'EUR'), 620);
      // 12.34 EUR to JPY at 160 = 1974.4 -> 1974 JPY.
      expect(convert(1234, 'EUR', 160, 'JPY'), 1974);
      // 1.000 KWD to EUR at 2.95.
      expect(convert(1000, 'KWD', 2.95, 'EUR'), 295);
      expect(formatMoney(1974, 'JPY'), '¥1,974');
      expect(formatMoney(-1250, 'EUR'), '−€12.50');
      expect(formatMoney(1250, 'EUR', signed: true), '+€12.50');
    });

    test('AC-20 an expense keeps the rate stored with it', () {
      final e = sampleExpense(
        id: 'e1',
        amount: 10000,
        currency: 'USD',
        rate: 0.9,
      );
      final restored = Expense.fromJson(e.toJson());
      expect(restored.rate, 0.9);
      expect(baseAmountOf(restored, 'EUR'), 9000);
    });
  });

  group('balances', () {
    final trip = sampleTrip();

    test(
      'AC-22 balance = paid − shares + payments made − payments received',
      () {
        final expenses = [
          sampleExpense(id: 'e1', amount: 9000), // Ana paid 90, 30 each
          sampleExpense(id: 'e2', amount: 3000, paidBy: 'p-ben'), // 10 each
        ];
        final payments = [
          Payment(
            id: 'pay1',
            tripId: trip.id,
            fromId: 'p-cleo',
            toId: 'p-ana',
            amountMinor: 1500,
            date: DateTime(2026, 10, 4),
            createdAt: DateTime(2026, 10, 4),
          ),
        ];
        final b = balancesFor(trip, expenses, payments);
        expect(b['p-ana'], 9000 - 3000 - 1000 - 1500);
        expect(b['p-ben'], 3000 - 3000 - 1000);
        expect(b['p-cleo'], -3000 - 1000 + 1500);
        expect(b.values.reduce((a, c) => a + c), 0);
      },
    );

    test('AC-22 balances add up to 0 with mixed currencies and splits', () {
      final rnd = Random(3);
      final people = ['p-ana', 'p-ben', 'p-cleo'];
      for (var round = 0; round < 50; round++) {
        final expenses = <Expense>[
          for (var i = 0; i < 10; i++)
            sampleExpense(
              id: 'e$i',
              amount: 1 + rnd.nextInt(100000),
              currency: ['EUR', 'JPY', 'USD', 'KWD'][rnd.nextInt(4)],
              rate: 0.001 + rnd.nextDouble() * 3,
              paidBy: people[rnd.nextInt(3)],
              among: people.sublist(rnd.nextInt(3)),
            ),
        ];
        final b = balancesFor(trip, expenses, const []);
        expect(b.values.reduce((a, c) => a + c), 0);
      }
    });

    test(
      'AC-23 simplified payments: at most people − 1, and they settle everyone',
      () {
        final rnd = Random(4);
        for (var round = 0; round < 200; round++) {
          final n = 2 + rnd.nextInt(8);
          final values = [
            for (var i = 0; i < n - 1; i++) rnd.nextInt(20001) - 10000,
          ];
          values.add(-values.fold(0, (a, b) => a + b));
          final balances = {for (var i = 0; i < n; i++) 'p$i': values[i]};
          final transfers = simplifyDebts(balances);
          expect(transfers.length, lessThanOrEqualTo(n - 1));
          final after = Map.of(balances);
          for (final t in transfers) {
            after[t.fromId] = after[t.fromId]! + t.amountMinor;
            after[t.toId] = after[t.toId]! - t.amountMinor;
          }
          expect(after.values.every((v) => v == 0), isTrue);
        }
      },
    );

    test('AC-23 the largest debtor pays the largest creditor first', () {
      final t = simplifyDebts({'a': 5000, 'b': -3000, 'c': -2000, 'd': 0});
      expect(t.first.fromId, 'b');
      expect(t.first.toId, 'a');
      expect(t.first.amountMinor, 3000);
      expect(t.length, 2);
    });

    test('AC-26 settled means every balance is within one minor unit', () {
      expect(isSettled({'a': 0, 'b': 1, 'c': -1}), isTrue);
      expect(isSettled({'a': 2, 'b': -2}), isFalse);
    });
  });
}
