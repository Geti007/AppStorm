import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Where the app keeps its data. The app holds everything in memory and
/// writes each change through to the repository.
abstract class Repository {
  Future<Snapshot> load();
  Future<void> saveTrip(Trip trip);
  Future<void> deleteTrip(String tripId);
  Future<void> saveExpense(Expense expense);
  Future<void> deleteExpense(String expenseId);
  Future<void> savePayment(Payment payment);
  Future<void> deletePayment(String paymentId);
  Future<void> saveCategory(CustomCategory category);
  Future<void> deleteCategory(String categoryId);
  Future<void> saveExpenses(List<Expense> expenses);
  Future<void> setSetting(String key, String? value);

  /// Replaces trips, expenses, payments and categories (settings are kept).
  Future<void> replaceData(Snapshot data);
}

/// SQLite storage on the device. The database opens on first use, so a
/// failure to open shows up as a load error the user can retry.
class SqliteRepository implements Repository {
  SqliteRepository({this.factory, this.path});

  final DatabaseFactory? factory;
  final String? path;
  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  Future<Database> _open() async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'trippi.db');
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute('CREATE TABLE trips(id TEXT PRIMARY KEY, json TEXT)');
          batch.execute(
            'CREATE TABLE expenses(id TEXT PRIMARY KEY, trip_id TEXT, json TEXT)',
          );
          batch.execute(
            'CREATE TABLE payments(id TEXT PRIMARY KEY, trip_id TEXT, json TEXT)',
          );
          batch.execute(
            'CREATE TABLE categories(id TEXT PRIMARY KEY, json TEXT)',
          );
          batch.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
          );
          await batch.commit(noResult: true);
        },
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<List<Map<String, Object?>>> _rows(String table) async => [
    for (final r in await (await _db).query(table))
      (jsonDecode(r['json']! as String) as Map).cast<String, Object?>(),
  ];

  @override
  Future<Snapshot> load() async {
    final settings = {
      for (final r in await (await _db).query('settings'))
        r['key']! as String: r['value']! as String,
    };
    return Snapshot(
      trips: [for (final j in await _rows('trips')) Trip.fromJson(j)],
      expenses: [for (final j in await _rows('expenses')) Expense.fromJson(j)],
      payments: [for (final j in await _rows('payments')) Payment.fromJson(j)],
      categories: [
        for (final j in await _rows('categories')) CustomCategory.fromJson(j),
      ],
      settings: settings,
    );
  }

  Future<void> _put(
    DatabaseExecutor db,
    String table,
    String id,
    Map<String, Object?> json, {
    String? tripId,
  }) => db.insert(table, {
    'id': id,
    'trip_id': ?tripId,
    'json': jsonEncode(json),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> saveTrip(Trip trip) async =>
      _put(await _db, 'trips', trip.id, trip.toJson());

  @override
  Future<void> deleteTrip(String tripId) async =>
      (await _db).transaction((txn) async {
        await txn.delete('expenses', where: 'trip_id = ?', whereArgs: [tripId]);
        await txn.delete('payments', where: 'trip_id = ?', whereArgs: [tripId]);
        await txn.delete('trips', where: 'id = ?', whereArgs: [tripId]);
      });

  @override
  Future<void> saveExpense(Expense e) async =>
      _put(await _db, 'expenses', e.id, e.toJson(), tripId: e.tripId);

  @override
  Future<void> saveExpenses(List<Expense> expenses) async =>
      (await _db).transaction((txn) async {
        for (final e in expenses) {
          await _put(txn, 'expenses', e.id, e.toJson(), tripId: e.tripId);
        }
      });

  @override
  Future<void> deleteExpense(String expenseId) async =>
      (await _db).delete('expenses', where: 'id = ?', whereArgs: [expenseId]);

  @override
  Future<void> savePayment(Payment pay) async =>
      _put(await _db, 'payments', pay.id, pay.toJson(), tripId: pay.tripId);

  @override
  Future<void> deletePayment(String paymentId) async =>
      (await _db).delete('payments', where: 'id = ?', whereArgs: [paymentId]);

  @override
  Future<void> saveCategory(CustomCategory c) async =>
      _put(await _db, 'categories', c.id, c.toJson());

  @override
  Future<void> deleteCategory(String categoryId) async => (await _db).delete(
    'categories',
    where: 'id = ?',
    whereArgs: [categoryId],
  );

  @override
  Future<void> setSetting(String key, String? value) async => value == null
      ? (await _db).delete('settings', where: 'key = ?', whereArgs: [key])
      : (await _db).insert('settings', {
          'key': key,
          'value': value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> replaceData(Snapshot data) async =>
      (await _db).transaction((txn) async {
        for (final t in ['trips', 'expenses', 'payments', 'categories']) {
          await txn.delete(t);
        }
        for (final t in data.trips) {
          await _put(txn, 'trips', t.id, t.toJson());
        }
        for (final e in data.expenses) {
          await _put(txn, 'expenses', e.id, e.toJson(), tripId: e.tripId);
        }
        for (final pay in data.payments) {
          await _put(txn, 'payments', pay.id, pay.toJson(), tripId: pay.tripId);
        }
        for (final c in data.categories) {
          await _put(txn, 'categories', c.id, c.toJson());
        }
      });
}

/// Keeps data in memory only; used by tests and as a fallback.
class MemoryRepository implements Repository {
  MemoryRepository([Snapshot initial = const Snapshot()])
    : trips = {for (final t in initial.trips) t.id: t},
      expenses = {for (final e in initial.expenses) e.id: e},
      payments = {for (final pay in initial.payments) pay.id: pay},
      categories = {for (final c in initial.categories) c.id: c},
      settings = Map.of(initial.settings);

  final Map<String, Trip> trips;
  final Map<String, Expense> expenses;
  final Map<String, Payment> payments;
  final Map<String, CustomCategory> categories;
  final Map<String, String> settings;

  @override
  Future<Snapshot> load() async => Snapshot(
    trips: trips.values.toList(),
    expenses: expenses.values.toList(),
    payments: payments.values.toList(),
    categories: categories.values.toList(),
    settings: Map.of(settings),
  );

  @override
  Future<void> saveTrip(Trip trip) async => trips[trip.id] = trip;

  @override
  Future<void> deleteTrip(String tripId) async {
    trips.remove(tripId);
    expenses.removeWhere((_, e) => e.tripId == tripId);
    payments.removeWhere((_, pay) => pay.tripId == tripId);
  }

  @override
  Future<void> saveExpense(Expense e) async => expenses[e.id] = e;

  @override
  Future<void> saveExpenses(List<Expense> list) async {
    for (final e in list) {
      expenses[e.id] = e;
    }
  }

  @override
  Future<void> deleteExpense(String expenseId) async =>
      expenses.remove(expenseId);

  @override
  Future<void> savePayment(Payment pay) async => payments[pay.id] = pay;

  @override
  Future<void> deletePayment(String paymentId) async =>
      payments.remove(paymentId);

  @override
  Future<void> saveCategory(CustomCategory c) async => categories[c.id] = c;

  @override
  Future<void> deleteCategory(String categoryId) async =>
      categories.remove(categoryId);

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      settings.remove(key);
    } else {
      settings[key] = value;
    }
  }

  @override
  Future<void> replaceData(Snapshot data) async {
    trips
      ..clear()
      ..addAll({for (final t in data.trips) t.id: t});
    expenses
      ..clear()
      ..addAll({for (final e in data.expenses) e.id: e});
    payments
      ..clear()
      ..addAll({for (final pay in data.payments) pay.id: pay});
    categories
      ..clear()
      ..addAll({for (final c in data.categories) c.id: c});
  }
}
