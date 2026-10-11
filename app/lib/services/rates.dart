import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Euro reference rates published for one day: units of each currency per
/// 1 EUR (EUR itself is 1).
class RateTable {
  const RateTable(this.date, this.perEuro);

  final String date;
  final Map<String, double> perEuro;

  /// Units of [to] worth one unit of [from], or null when either currency
  /// is not in the table.
  double? rate(String from, String to) {
    if (from == to) return 1;
    final f = perEuro[from];
    final t = perEuro[to];
    if (f == null || t == null || f <= 0) return null;
    return t / f;
  }

  Map<String, Object?> toJson() => {'date': date, 'rates': perEuro};

  static RateTable? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    final rates = json['rates'];
    if (date is! String || rates is! Map) return null;
    return RateTable(date, {
      'EUR': 1,
      for (final e in rates.entries)
        if (e.key is String && e.value is num)
          e.key as String: (e.value as num).toDouble(),
    });
  }
}

/// Fetches exchange rates. Only currency codes and dates are ever sent.
abstract class RateService {
  /// The most recent published rates, or null when they can't be fetched.
  Future<RateTable?> latest();

  /// The rates published for [day] (or the last working day before it).
  Future<RateTable?> onDate(DateTime day);
}

/// The free Frankfurter API (European Central Bank reference rates).
class FrankfurterRateService implements RateService {
  FrankfurterRateService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _hosts = [
    'https://api.frankfurter.dev/v1',
    'https://api.frankfurter.app',
  ];

  Future<RateTable?> _get(String path) async {
    for (final host in _hosts) {
      try {
        final res = await _client
            .get(Uri.parse('$host/$path'))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final table = RateTable.fromJson(jsonDecode(res.body));
          if (table != null) return table;
        }
      } on Exception {
        // Try the next host.
      }
    }
    return null;
  }

  @override
  Future<RateTable?> latest() => _get('latest');

  @override
  Future<RateTable?> onDate(DateTime day) {
    final d =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _get(d);
  }
}
