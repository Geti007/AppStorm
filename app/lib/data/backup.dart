import 'dart:convert';

import 'models.dart';

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
      final tripIds = {for (final t in trips) t.id};
      final expenses = [for (final e in list('expenses')) Expense.fromJson(e)];
      final payments = [for (final p in list('payments')) Payment.fromJson(p)];
      if (expenses.any((e) => !tripIds.contains(e.tripId)) ||
          payments.any((p) => !tripIds.contains(p.tripId))) {
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
