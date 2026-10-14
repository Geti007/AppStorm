import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/storage.dart';
import '../data/units.dart';

typedef Clock = DateTime Function();

/// Everything the app shows, kept in memory and saved to [Storage] after
/// every change.
class AppState extends ChangeNotifier {
  AppState({required this.storage, Clock? clock})
    : _clock = clock ?? DateTime.now;

  final Storage storage;
  final Clock _clock;

  bool _loaded = false;
  bool _loadFailed = false;
  bool _onboarded = false;
  VolumeUnit _unit = VolumeUnit.ml;
  List<Drink> _drinks = [];
  List<GoalChange> _goals = [];
  int _nextId = 1;

  bool get loaded => _loaded;

  /// True when saved data existed but could not be read.
  bool get loadFailed => _loadFailed;
  bool get onboarded => _onboarded;
  VolumeUnit get unit => _unit;
  DateTime get now => _clock();
  DateTime get today => dayOf(_clock());
  bool get hasAnyDrinks => _drinks.isNotEmpty;

  Future<void> load() async {
    try {
      final raw = await storage.read();
      if (raw != null) _decode(raw);
    } on Object {
      _loadFailed = true;
      _onboarded = false;
      _unit = VolumeUnit.ml;
      _drinks = [];
      _goals = [];
    }
    _loaded = true;
    notifyListeners();
  }

  void _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final drinks = [
      for (final d in json['drinks'] as List)
        Drink.fromJson(d as Map<String, dynamic>),
    ]..sort((a, b) => a.time.compareTo(b.time));
    final goals = [
      for (final g in json['goals'] as List)
        GoalChange.fromJson(g as Map<String, dynamic>),
    ]..sort((a, b) => a.day.compareTo(b.day));
    _onboarded = json['onboarded'] as bool;
    _unit = unitFromStorage(json['unit'] as String?);
    _drinks = drinks;
    _goals = goals;
    _nextId = drinks.fold<int>(0, (m, d) => d.id > m ? d.id : m) + 1;
  }

  String _encode() => jsonEncode({
    'onboarded': _onboarded,
    'unit': _unit.storageName,
    'goals': [for (final g in _goals) g.toJson()],
    'drinks': [for (final d in _drinks) d.toJson()],
  });

  Future<void> _save() async {
    notifyListeners();
    try {
      await storage.write(_encode());
    } on Object catch (e) {
      debugPrint('Glassful: could not save: $e');
    }
  }

  /// Call when the day may have changed (app resumed, midnight passed).
  void refreshDay() => notifyListeners();

  // ---------------------------------------------------------------- goals

  /// The goal in force on [day]: the latest change on or before it.
  double goalOn(DateTime day) {
    final d = dayOf(day);
    double? goal;
    for (final g in _goals) {
      if (!g.day.isAfter(d)) goal = g.ml;
    }
    return goal ?? (_goals.isNotEmpty ? _goals.first.ml : defaultGoalMl);
  }

  double get todayGoal => goalOn(today);

  Future<void> setGoal(double ml) async {
    final t = today;
    _goals = [
      for (final g in _goals)
        if (g.day.isBefore(t)) g,
      GoalChange(day: t, ml: ml),
    ];
    await _save();
  }

  Future<void> setUnit(VolumeUnit unit) async {
    _unit = unit;
    await _save();
  }

  Future<void> completeOnboarding({
    required double goalMl,
    required VolumeUnit unit,
  }) async {
    _unit = unit;
    _goals = [GoalChange(day: today, ml: goalMl)];
    _onboarded = true;
    _loadFailed = false;
    await _save();
  }

  // ---------------------------------------------------------------- drinks

  List<Drink> drinksOn(DateTime day) {
    final d = dayOf(day);
    return [
      for (final x in _drinks)
        if (dayOf(x.time) == d) x,
    ];
  }

  double totalOn(DateTime day) =>
      drinksOn(day).fold(0.0, (sum, d) => sum + d.ml);

  /// Today's drinks, newest first.
  List<Drink> get todayDrinks => drinksOn(today).reversed.toList();

  double get todayTotal => totalOn(today);

  bool get todayGoalMet => isGoalMet(todayTotal, todayGoal);

  Future<Drink> addDrink(double ml) async {
    final drink = Drink(id: _nextId++, time: _clock(), ml: ml);
    _drinks = [..._drinks, drink];
    await _save();
    return drink;
  }

  Future<void> removeDrink(int id) async {
    _drinks = [
      for (final d in _drinks)
        if (d.id != id) d,
    ];
    await _save();
  }

  // ---------------------------------------------------------------- history

  /// The last 7 days, oldest first, today last.
  List<DayTotal> get lastSevenDays {
    final t = today;
    return [
      for (var i = 6; i >= 0; i--)
        _dayTotal(DateTime(t.year, t.month, t.day - i)),
    ];
  }

  DayTotal _dayTotal(DateTime day) =>
      DayTotal(day: day, ml: totalOn(day), goalMl: goalOn(day));

  /// Consecutive days the goal was met, ending today or, if today is not
  /// met yet, yesterday.
  int get streak {
    if (_drinks.isEmpty) return 0;
    final metDays = <DateTime>{};
    final totals = <DateTime, double>{};
    for (final d in _drinks) {
      final day = dayOf(d.time);
      totals[day] = (totals[day] ?? 0) + d.ml;
    }
    totals.forEach((day, ml) {
      if (isGoalMet(ml, goalOn(day))) metDays.add(day);
    });
    final t = today;
    var day = metDays.contains(t) ? t : DateTime(t.year, t.month, t.day - 1);
    var count = 0;
    while (metDays.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  // ---------------------------------------------------------------- reset

  Future<void> resetAll() async {
    _drinks = [];
    _goals = [];
    _unit = VolumeUnit.ml;
    _onboarded = false;
    _nextId = 1;
    notifyListeners();
    try {
      await storage.clear();
    } on Object catch (e) {
      debugPrint('Glassful: could not clear: $e');
    }
  }
}
