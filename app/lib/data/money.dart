import 'package:intl/intl.dart';

import 'currencies.dart';
import 'models.dart';

int pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Formats [minor] units of [code] with its symbol, e.g. "€12.50" or "¥1,200".
String formatMoney(int minor, String code, {bool signed = false}) {
  final c = currencyFor(code);
  // Letter symbols get a no-break space: "CHF 12.50", but "€12.50".
  final letters = RegExp(r'\p{L}$', unicode: true).hasMatch(c.symbol);
  final f = NumberFormat.currency(
    symbol: letters ? '${c.symbol}\u00A0' : c.symbol,
    decimalDigits: c.minorUnits,
  );
  final value = minor.abs() / pow10(c.minorUnits);
  final text = f.format(value);
  if (minor < 0) return '−$text';
  if (signed && minor > 0) return '+$text';
  return text;
}

/// Formats [minor] units as a plain number for an input field ("12.50").
String formatAmountInput(int minor, String code) {
  final units = currencyFor(code).minorUnits;
  if (units == 0) return '$minor';
  final whole = minor ~/ pow10(units);
  final frac = (minor.abs() % pow10(units)).toString().padLeft(units, '0');
  return '$whole.$frac';
}

/// Formats [minor] with the currency code instead of a symbol ("EUR 12.50"),
/// for exports whose fonts may not include every symbol.
String formatMoneyCode(int minor, String code) {
  final c = currencyFor(code);
  final f = NumberFormat.decimalPatternDigits(decimalDigits: c.minorUnits);
  final text = f.format(minor.abs() / pow10(c.minorUnits));
  return '${minor < 0 ? '-' : ''}$code $text';
}

enum AmountError { empty, invalid, tooManyDecimals, notPositive }

class ParsedAmount {
  const ParsedAmount.ok(int this.minor) : error = null;
  const ParsedAmount.fail(AmountError this.error) : minor = null;

  final int? minor;
  final AmountError? error;
}

/// Parses user input such as "12.5" or "12,50" into minor units.
ParsedAmount parseAmount(String input, int minorUnits) {
  final text = input.trim().replaceAll(' ', '');
  if (text.isEmpty) return const ParsedAmount.fail(AmountError.empty);
  final normalised = text.replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d*)?$|^\.\d+$').hasMatch(normalised)) {
    return const ParsedAmount.fail(AmountError.invalid);
  }
  final parts = normalised.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final frac = parts.length > 1 ? parts[1] : '';
  if (frac.length > minorUnits) {
    return const ParsedAmount.fail(AmountError.tooManyDecimals);
  }
  if (whole.length > 12) return const ParsedAmount.fail(AmountError.invalid);
  final minor =
      int.parse(whole) * pow10(minorUnits) +
      (frac.isEmpty ? 0 : int.parse(frac.padRight(minorUnits, '0')));
  if (minor <= 0) return const ParsedAmount.fail(AmountError.notPositive);
  return ParsedAmount.ok(minor);
}

/// Parses a percentage with up to 2 decimals into hundredths (100% = 10000).
int? parsePercent(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return 0;
  if (!RegExp(r'^\d{1,3}(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final frac = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return int.parse(parts[0]) * 100 + int.parse(frac);
}

/// Parses an exchange rate typed by hand; null unless it is greater than 0.
double? parseRate(String input) {
  final v = double.tryParse(input.trim().replaceAll(',', '.'));
  if (v == null || v <= 0 || v.isNaN || v.isInfinite) return null;
  return v;
}

String formatPercent(int hundredths) {
  final sign = hundredths < 0 ? '-' : '';
  final v = hundredths.abs();
  final whole = v ~/ 100;
  final frac = v % 100;
  if (frac == 0) return '$sign$whole%';
  final f = frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '');
  return '$sign$whole.$f%';
}

/// Splits [amount] equally between [count] people. Remaining units go to
/// the first people so the shares add up exactly to [amount].
List<int> splitEqual(int amount, int count) {
  if (count <= 0) return const [];
  final base = amount ~/ count;
  final rest = amount - base * count;
  return [for (var i = 0; i < count; i++) base + (i < rest ? 1 : 0)];
}

/// Splits [amount] by percentages in hundredths that add up to 10000.
/// Shares are rounded down and leftover units go to the first people.
List<int> splitPercent(int amount, List<int> hundredths) {
  final shares = [for (final h in hundredths) amount * h ~/ 10000];
  var rest = amount - shares.fold(0, (a, b) => a + b);
  var i = 0;
  while (rest > 0 && shares.isNotEmpty) {
    if (hundredths[i % shares.length] > 0 || hundredths.every((h) => h == 0)) {
      shares[i % shares.length]++;
      rest--;
    }
    i++;
  }
  return shares;
}

/// Divides [total] in proportion to [weights] (largest remainder), so the
/// parts add up exactly to [total].
List<int> distribute(int total, List<int> weights) {
  final sum = weights.fold(0, (a, b) => a + b);
  if (weights.isEmpty) return const [];
  if (sum == 0) return splitEqual(total, weights.length);
  if (sum == total) return List.of(weights);
  // total * weight can pass the 64-bit range for large amounts in
  // currencies with many units (IDR, VND, LBP), so multiply in BigInt.
  final bigTotal = BigInt.from(total);
  final bigSum = BigInt.from(sum);
  final parts = <int>[];
  final remainders = <MapEntry<int, BigInt>>[];
  var used = 0;
  for (var i = 0; i < weights.length; i++) {
    final exact = bigTotal * BigInt.from(weights[i]);
    final part = (exact ~/ bigSum).toInt();
    parts.add(part);
    used += part;
    remainders.add(MapEntry(i, exact % bigSum));
  }
  remainders.sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  var rest = total - used;
  for (final r in remainders) {
    if (rest <= 0) break;
    parts[r.key]++;
    rest--;
  }
  return parts;
}

/// Converts [minor] units of [from] at [rate] into minor units of [to].
int convert(int minor, String from, double rate, String to) {
  if (from == to) return minor;
  final f = currencyFor(from).minorUnits;
  final t = currencyFor(to).minorUnits;
  return (minor / pow10(f) * rate * pow10(t)).round();
}

/// Each person's share of [e] in the expense currency.
Map<String, int> sharesOf(Expense e) {
  final people = e.splitAmong;
  final List<int> parts;
  switch (e.method) {
    case SplitMethod.equal:
      parts = splitEqual(e.amountMinor, people.length);
    case SplitMethod.percent:
      parts = splitPercent(e.amountMinor, [
        for (final p in people) e.splitInputs[p] ?? 0,
      ]);
    case SplitMethod.custom:
      parts = [for (final p in people) e.splitInputs[p] ?? 0];
  }
  return {for (var i = 0; i < people.length; i++) people[i]: parts[i]};
}

/// The expense amount in the trip currency.
int baseAmountOf(Expense e, String baseCurrency) =>
    convert(e.amountMinor, e.currency, e.rate, baseCurrency);

/// Each person's share of [e] in the trip currency, adding up exactly to
/// [baseAmountOf].
Map<String, int> baseSharesOf(Expense e, String baseCurrency) {
  final shares = sharesOf(e);
  final ids = shares.keys.toList();
  final parts = distribute(baseAmountOf(e, baseCurrency), [
    for (final id in ids) shares[id]!,
  ]);
  return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
}

/// Net balance per participant in the trip currency: paid − shares
/// + payments made − payments received. The balances add up to 0.
Map<String, int> balancesFor(
  Trip trip,
  Iterable<Expense> expenses,
  Iterable<Payment> payments,
) {
  final b = {for (final p in trip.participants) p.id: 0};
  for (final e in expenses) {
    b[e.paidBy] = (b[e.paidBy] ?? 0) + baseAmountOf(e, trip.baseCurrency);
    baseSharesOf(e, trip.baseCurrency).forEach((id, share) {
      b[id] = (b[id] ?? 0) - share;
    });
  }
  for (final p in payments) {
    b[p.fromId] = (b[p.fromId] ?? 0) + p.amountMinor;
    b[p.toId] = (b[p.toId] ?? 0) - p.amountMinor;
  }
  return b;
}

class Transfer {
  const Transfer(this.fromId, this.toId, this.amountMinor);

  final String fromId;
  final String toId;
  final int amountMinor;
}

/// The fewest payments that settle [balances]: debtors and creditors are
/// matched largest first, giving at most (people − 1) payments.
List<Transfer> simplifyDebts(Map<String, int> balances, {int tolerance = 0}) {
  final debtors = [
    for (final e in balances.entries)
      if (e.value < -tolerance) MapEntry(e.key, -e.value),
  ];
  final creditors = [
    for (final e in balances.entries)
      if (e.value > tolerance) MapEntry(e.key, e.value),
  ];
  int byAmount(MapEntry<String, int> a, MapEntry<String, int> b) =>
      b.value.compareTo(a.value);
  final result = <Transfer>[];
  while (debtors.isNotEmpty && creditors.isNotEmpty) {
    debtors.sort(byAmount);
    creditors.sort(byAmount);
    final d = debtors.first;
    final c = creditors.first;
    final amount = d.value < c.value ? d.value : c.value;
    result.add(Transfer(d.key, c.key, amount));
    debtors[0] = MapEntry(d.key, d.value - amount);
    creditors[0] = MapEntry(c.key, c.value - amount);
    debtors.removeWhere((e) => e.value <= tolerance);
    creditors.removeWhere((e) => e.value <= tolerance);
  }
  return result;
}

/// True when every balance is 0 within one minor unit.
bool isSettled(Map<String, int> balances) =>
    balances.values.every((v) => v.abs() <= 1);
