/// Units, conversions and the limits from the spec.
library;

enum VolumeUnit { ml, oz }

/// Millilitres in one US fluid ounce.
const double mlPerOz = 29.5735;

/// A goal is met when the total is within this many millilitres of it, so
/// ounce amounts that add up to the goal always meet it.
const double goalTolerance = 0.5;

const double defaultGoalMl = 2000;

extension VolumeUnitX on VolumeUnit {
  String get symbol => this == VolumeUnit.ml ? 'ml' : 'fl oz';

  String get spoken => this == VolumeUnit.ml ? 'millilitres' : 'fluid ounces';

  String get storageName => this == VolumeUnit.ml ? 'ml' : 'oz';

  /// The amount in this unit, rounded to a whole number for display.
  int display(double ml) =>
      this == VolumeUnit.ml ? ml.round() : (ml / mlPerOz).round();

  /// Millilitres for an amount typed or tapped in this unit, without rounding.
  double toMl(num amount) =>
      this == VolumeUnit.ml ? amount.toDouble() : amount * mlPerOz;

  String format(double ml) => '${display(ml)} $symbol';

  /// The three quick-add sizes, in this unit.
  List<int> get quickAdds =>
      this == VolumeUnit.ml ? const [150, 250, 500] : const [6, 8, 16];

  int get goalMin => this == VolumeUnit.ml ? 500 : 17;
  int get goalMax => this == VolumeUnit.ml ? 6000 : 202;

  int get customMin => 1;
  int get customMax => this == VolumeUnit.ml ? 2000 : 67;

  String get goalRangeError =>
      'Enter a goal between $goalMin and $goalMax $symbol';

  String get customRangeHelp => '$customMin to $customMax $symbol';
}

VolumeUnit unitFromStorage(String? name) =>
    name == 'oz' ? VolumeUnit.oz : VolumeUnit.ml;

/// Parses a whole number the user typed; null when it is not one.
int? parseWhole(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}
