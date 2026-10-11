import 'dart:math';

/// How an expense is divided between people.
enum SplitMethod { equal, percent, custom }

final Random _random = Random();

/// A new unique id. Ids are strings so backups can be merged and read back.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return '$time$noise';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

class Participant {
  const Participant({required this.id, required this.name});

  final String id;
  final String name;

  Participant copyWith({String? name}) =>
      Participant(id: id, name: name ?? this.name);

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory Participant.fromJson(Map<String, Object?> j) =>
      Participant(id: j['id']! as String, name: j['name']! as String);
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.baseCurrency,
    required this.cover,
    required this.participants,
    required this.createdAt,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final String baseCurrency;
  final int cover;
  final List<Participant> participants;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  Participant? participant(String id) {
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nameOf(String participantId) => participant(participantId)?.name ?? '';

  Trip copyWith({
    String? name,
    String? baseCurrency,
    int? cover,
    List<Participant>? participants,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    cover: cover ?? this.cover,
    participants: participants ?? this.participants,
    createdAt: createdAt,
    startDate: clearDates ? null : (startDate ?? this.startDate),
    endDate: clearDates ? null : (endDate ?? this.endDate),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseCurrency': baseCurrency,
    'cover': cover,
    'participants': [for (final p in participants) p.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'startDate': startDate == null ? null : _dateKey(startDate!),
    'endDate': endDate == null ? null : _dateKey(endDate!),
  };

  factory Trip.fromJson(Map<String, Object?> j) => Trip(
    id: j['id']! as String,
    name: j['name']! as String,
    baseCurrency: j['baseCurrency']! as String,
    cover: (j['cover'] as num?)?.toInt() ?? 0,
    participants: [
      for (final p in (j['participants']! as List))
        Participant.fromJson((p as Map).cast<String, Object?>()),
    ],
    createdAt: DateTime.parse(j['createdAt']! as String),
    startDate: _parseDate(j['startDate']),
    endDate: _parseDate(j['endDate']),
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amountMinor,
    required this.currency,
    required this.rate,
    required this.categoryId,
    required this.date,
    required this.paidBy,
    required this.method,
    required this.splitAmong,
    required this.splitInputs,
    required this.createdAt,
    this.rateDate,
    this.note = '',
  });

  final String id;
  final String tripId;
  final String title;

  /// Amount in minor units of [currency].
  final int amountMinor;
  final String currency;

  /// How many units of the trip currency one unit of [currency] is worth.
  /// Stored with the expense so later rate changes never alter it.
  final double rate;
  final String? rateDate;
  final String categoryId;
  final DateTime date;
  final String paidBy;
  final SplitMethod method;

  /// People in the split, in the order they are listed in the trip.
  final List<String> splitAmong;

  /// Percent in hundredths (100% = 10000) or custom amounts in minor units,
  /// by participant id. Empty for an equal split.
  final Map<String, int> splitInputs;
  final DateTime createdAt;
  final String note;

  Expense copyWith({String? categoryId}) => Expense(
    id: id,
    tripId: tripId,
    title: title,
    amountMinor: amountMinor,
    currency: currency,
    rate: rate,
    rateDate: rateDate,
    categoryId: categoryId ?? this.categoryId,
    date: date,
    paidBy: paidBy,
    method: method,
    splitAmong: splitAmong,
    splitInputs: splitInputs,
    createdAt: createdAt,
    note: note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'amountMinor': amountMinor,
    'currency': currency,
    'rate': rate,
    'rateDate': rateDate,
    'categoryId': categoryId,
    'date': _dateKey(date),
    'paidBy': paidBy,
    'method': method.name,
    'splitAmong': splitAmong,
    'splitInputs': splitInputs,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  factory Expense.fromJson(Map<String, Object?> j) => Expense(
    id: j['id']! as String,
    tripId: j['tripId']! as String,
    title: j['title']! as String,
    amountMinor: (j['amountMinor']! as num).toInt(),
    currency: j['currency']! as String,
    rate: (j['rate']! as num).toDouble(),
    rateDate: j['rateDate'] as String?,
    categoryId: j['categoryId']! as String,
    date: DateTime.parse(j['date']! as String),
    paidBy: j['paidBy']! as String,
    method: SplitMethod.values.byName(j['method']! as String),
    splitAmong: [for (final s in (j['splitAmong']! as List)) s as String],
    splitInputs: {
      for (final e in ((j['splitInputs'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    createdAt: DateTime.parse(j['createdAt']! as String),
    note: (j['note'] as String?) ?? '',
  );
}

class Payment {
  const Payment({
    required this.id,
    required this.tripId,
    required this.fromId,
    required this.toId,
    required this.amountMinor,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String fromId;
  final String toId;

  /// Amount in minor units of the trip currency.
  final int amountMinor;
  final DateTime date;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'tripId': tripId,
    'fromId': fromId,
    'toId': toId,
    'amountMinor': amountMinor,
    'date': _dateKey(date),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Payment.fromJson(Map<String, Object?> j) => Payment(
    id: j['id']! as String,
    tripId: j['tripId']! as String,
    fromId: j['fromId']! as String,
    toId: j['toId']! as String,
    amountMinor: (j['amountMinor']! as num).toInt(),
    date: DateTime.parse(j['date']! as String),
    createdAt: DateTime.parse(j['createdAt']! as String),
  );
}

class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorIndex,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorIndex;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'iconKey': iconKey,
    'colorIndex': colorIndex,
  };

  factory CustomCategory.fromJson(Map<String, Object?> j) => CustomCategory(
    id: j['id']! as String,
    name: j['name']! as String,
    iconKey: j['iconKey']! as String,
    colorIndex: (j['colorIndex']! as num).toInt(),
  );
}

/// Everything the app stores, as loaded from the database or a backup file.
class Snapshot {
  const Snapshot({
    this.trips = const [],
    this.expenses = const [],
    this.payments = const [],
    this.categories = const [],
    this.settings = const {},
  });

  final List<Trip> trips;
  final List<Expense> expenses;
  final List<Payment> payments;
  final List<CustomCategory> categories;
  final Map<String, String> settings;
}
