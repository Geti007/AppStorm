import 'units.dart';

/// A drink the user logged.
class Drink {
  const Drink({required this.id, required this.time, required this.ml});

  final int id;
  final DateTime time;
  final double ml;

  Map<String, Object> toJson() => {
    'id': id,
    't': time.toIso8601String(),
    'ml': ml,
  };

  static Drink fromJson(Map<String, dynamic> json) => Drink(
    id: json['id'] as int,
    time: DateTime.parse(json['t'] as String),
    ml: (json['ml'] as num).toDouble(),
  );
}

/// The daily goal that applies from [day] on, until the next change.
class GoalChange {
  const GoalChange({required this.day, required this.ml});

  final DateTime day;
  final double ml;

  Map<String, Object> toJson() => {'day': dayKey(day), 'ml': ml};

  static GoalChange fromJson(Map<String, dynamic> json) => GoalChange(
    day: DateTime.parse(json['day'] as String),
    ml: (json['ml'] as num).toDouble(),
  );
}

/// One day's total, for History.
class DayTotal {
  const DayTotal({required this.day, required this.ml, required this.goalMl});

  final DateTime day;
  final double ml;
  final double goalMl;

  bool get met => isGoalMet(ml, goalMl);
}

bool isGoalMet(double totalMl, double goalMl) =>
    totalMl >= goalMl - goalTolerance;

/// Local midnight at the start of [t]'s day.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
