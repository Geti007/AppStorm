import 'dart:convert';

import 'models.dart';
import 'money.dart' show maxRate;

/// A Trippi backup file: every trip with its expenses and payments, plus
/// custom categories. Settings and purchases are not part of it.
class Backup {
  const Backup({required this.savedAt, required this.data});

  final DateTime savedAt;
  final Snapshot data;

  int get tripCount => data.trips.length;
  int get expenseCount => data.expenses.length;

  static const String marker = 'trippi-backup';

  String encode() => const JsonEncoder.withIndent(' ').convert({
    'format': marker,
    'version': 1,
    'savedAt': savedAt.toIso8601String(),
    'trips': [for (final t in data.trips) t.toJson()],
    'expenses': [for (final e in data.expenses) e.toJson()],
    'payments': [for (final p in data.payments) p.toJson()],
    'categories': [for (final c in data.categories) c.toJson()],
  });

  /// Reads a backup file; throws [FormatException] for anything else.
  static Backup decode(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['format'] != marker || j['version'] != 1) {
        throw const FormatException('not a Trippi backup');
      }
      List<Map<String, Object?>> list(String key) => [
        for (final x in (j[key] as List)) (x as Map).cast<String, Object?>(),
      ];
      final trips = [for (final t in list('trips')) Trip.fromJson(t)];
      final people = {
        for (final t in trips) t.id: {for (final p in t.participants) p.id},
      };
      final expenses = [for (final e in list('expenses')) Expense.fromJson(e)];
      final payments = [for (final p in list('payments')) Payment.fromJson(p)];
      // Every expense and payment must belong to a trip and only name that
      // trip's people, or balances would show phantom entries.
      bool inTrip(String tripId, Iterable<String> ids) {
        final known = people[tripId];
        return known != null && ids.every(known.contains);
      }

      if (trips.any((t) => !_validTrip(t)) ||
          expenses.any(
            (e) =>
                !inTrip(e.tripId, [e.paidBy, ...e.splitAmong]) ||
                !_validExpense(e),
          ) ||
          payments.any(
            (p) =>
                !inTrip(p.tripId, [p.fromId, p.toId]) ||
                p.amountMinor <= 0 ||
                p.fromId == p.toId,
          )) {
        throw const FormatException('inconsistent backup');
      }
      return Backup(
        savedAt: DateTime.parse(j['savedAt'] as String),
        data: Snapshot(
          trips: trips,
          expenses: expenses,
          payments: payments,
          categories: [
            for (final c in list('categories')) CustomCategory.fromJson(c),
          ],
        ),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('not a Trippi backup');
    }
  }
}

/// A trip the app can show: at least 2 people with unique ids and names.
bool _validTrip(Trip t) {
  final ids = {for (final p in t.participants) p.id};
  return t.name.trim().isNotEmpty &&
      t.participants.length >= 2 &&
      ids.length == t.participants.length &&
      t.participants.every((p) => p.name.trim().isNotEmpty);
}

/// An expense whose split adds up, as the expense form would save it.
bool _validExpense(Expense e) {
  if (e.amountMinor <= 0 ||
      !(e.rate > 0) ||
      e.rate > maxRate ||
      e.splitAmong.isEmpty) {
    return false;
  }
  if (e.rateDate != null && DateTime.tryParse(e.rateDate!) == null) {
    return false;
  }
  final inputs = [for (final id in e.splitAmong) e.splitInputs[id] ?? 0];
  final sum = inputs.fold(0, (a, b) => a + b);
  return switch (e.method) {
    SplitMethod.equal => true,
    SplitMethod.percent => sum == 10000 && inputs.every((v) => v >= 0),
    SplitMethod.custom => sum == e.amountMinor && inputs.every((v) => v >= 0),
  };
}
