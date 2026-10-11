import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backup.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/money.dart';
import '../data/repository.dart';
import '../services/ads.dart';
import '../services/billing.dart';
import '../services/files.dart';
import '../services/rates.dart';

/// Premium accent themes (AC-38). Lagoon is the default brand theme.
enum AccentTheme { lagoon, sunset, forest, midnight }

/// Where the Premium screen was opened from. Only the features a Premium
/// Pass unlocks may offer the rewarded video (AC-45, AC-45a).
enum PaywallSource {
  tripLimit,
  participantLimit,
  advancedStats,
  export,
  historicalRate,
  themes,
  categories,
  backup,
  settings,
  upgradeCard;

  bool get passUnlocks =>
      this == advancedStats ||
      this == export ||
      this == historicalRate ||
      this == themes;
}

const int freeTripLimit = 3;
const int freeParticipantLimit = 6;
const int rewardedDailyCap = 3;
const Duration passLength = Duration(hours: 24);
const Duration upgradeCardPause = Duration(days: 7);

class AppServices {
  AppServices({
    required this.repository,
    required this.rates,
    required this.billing,
    required this.ads,
    required this.files,
    DateTime Function()? clock,
    Future<void> Function(Uri url)? openUrl,
    this.isIOS = false,
  }) : now = clock ?? DateTime.now,
       openUrl = openUrl ?? _launch;

  static Future<void> _launch(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  final Repository repository;
  final RateService rates;
  final BillingService billing;
  final AdsService ads;
  final DeviceFiles files;
  final DateTime Function() now;

  /// Opens a web page or store page outside the app.
  final Future<void> Function(Uri url) openUrl;
  final bool isIOS;
}

/// All app data in memory, written through to the repository on change.
class AppState extends ChangeNotifier {
  AppState(this.services);

  final AppServices services;

  bool loaded = false;
  Object? loadError;

  final List<Trip> _trips = [];
  final Map<String, List<Expense>> _expenses = {};
  final Map<String, List<Payment>> _payments = {};
  final List<CustomCategory> _categories = [];
  final Map<String, String> _settings = {};
  RateTable? _latestRates;
  StreamSubscription<PurchaseOutcome>? _billingSub;

  Repository get _repo => services.repository;
  DateTime get now => services.now();

  // ------------------------------------------------------------- loading

  Future<void> load() async {
    loadError = null;
    try {
      final s = await _repo.load();
      _apply(s);
      _settings
        ..clear()
        ..addAll(s.settings);
      _latestRates = RateTable.fromJson(_decode(_settings['rates_latest']));
      loaded = true;
      _billingSub ??= services.billing.outcomes.listen(_onPurchase);
    } on Object catch (e) {
      loadError = e;
    }
    notifyListeners();
  }

  void _apply(Snapshot s) {
    _trips
      ..clear()
      ..addAll(s.trips)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _expenses.clear();
    for (final e in s.expenses) {
      _expenses.putIfAbsent(e.tripId, () => []).add(e);
    }
    _payments.clear();
    for (final p in s.payments) {
      _payments.putIfAbsent(p.tripId, () => []).add(p);
    }
    _categories
      ..clear()
      ..addAll(s.categories);
  }

  static Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  Future<void> _set(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
    await _repo.setSetting(key, value);
  }

  @override
  void dispose() {
    _billingSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- settings

  bool get onboardingDone => _settings['onboarding_done'] == '1';

  Future<void> completeOnboarding() async {
    await _set('onboarding_done', '1');
    notifyListeners();
  }

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_settings['theme_mode']] ?? ThemeMode.system;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _set('theme_mode', mode.name);
    notifyListeners();
  }

  AccentTheme get chosenAccent =>
      AccentTheme.values.asNameMap()[_settings['accent']] ?? AccentTheme.lagoon;

  /// The accent in use: premium themes fall back to Lagoon when Premium and
  /// the Pass have both ended (AC-40a).
  AccentTheme get accent => hasPassFeatures ? chosenAccent : AccentTheme.lagoon;

  Future<void> setAccent(AccentTheme a) async {
    await _set('accent', a.name);
    notifyListeners();
  }

  String get defaultCurrency => _settings['default_currency'] ?? 'EUR';

  Future<void> setDefaultCurrency(String code) async {
    await _set('default_currency', code);
    notifyListeners();
  }

  List<String> get recentCurrencies => (_settings['recent_currencies'] ?? '')
      .split(',')
      .where((c) => c.isNotEmpty)
      .toList();

  Future<void> useCurrency(String code) async {
    final list = [code, ...recentCurrencies.where((c) => c != code)].take(5);
    await _set('recent_currencies', list.join(','));
  }

  // ------------------------------------------------------------- premium

  bool get isPremium => _settings['premium'] == '1';

  DateTime? get passEnd => DateTime.tryParse(_settings['pass_end'] ?? '');

  bool get passActive => passEnd != null && passEnd!.isAfter(now);

  /// Advanced stats, exports, historical rates and themes (AC-29, AC-32,
  /// AC-33, AC-21, AC-38).
  bool get hasPassFeatures => isPremium || passActive;

  /// Premium users never see, load or request ads (AC-46).
  bool get adsEnabled => !isPremium;

  bool get canCreateTrip => isPremium || _trips.length < freeTripLimit;

  bool canAddParticipant(int current) =>
      isPremium || current < freeParticipantLimit;

  Future<void> setPremium(bool value) async {
    if (value == isPremium) return;
    await _set('premium', value ? '1' : null);
    notifyListeners();
  }

  void _onPurchase(PurchaseOutcome o) {
    if (o == PurchaseOutcome.purchased || o == PurchaseOutcome.restored) {
      setPremium(true);
    }
  }

  /// Re-checks the subscription with the store; keeps the cached status
  /// when the store can't be reached (AC-36, AC-40a).
  Future<void> refreshPremium() async {
    final active = await services.billing.checkActive();
    if (active != null) await setPremium(active);
  }

  String get _today => dateOnly(now).toIso8601String().substring(0, 10);

  int get rewardedWatchedToday => _settings['rewarded_day'] == _today
      ? int.tryParse(_settings['rewarded_count'] ?? '') ?? 0
      : 0;

  bool get rewardedCapReached => rewardedWatchedToday >= rewardedDailyCap;

  /// Grants a 24-hour Premium Pass. Called only from the ad SDK's reward
  /// callback (AC-45).
  Future<void> grantPass() async {
    final count = rewardedWatchedToday + 1;
    await _set('rewarded_day', _today);
    await _set('rewarded_count', '$count');
    await _set('pass_end', now.add(passLength).toIso8601String());
    notifyListeners();
  }

  /// One dismissible upgrade card after the first fully settled trip, at
  /// most once per 7 days (AC-41).
  bool get showUpgradeCard {
    if (isPremium) return false;
    final dismissed = DateTime.tryParse(_settings['upgrade_dismissed'] ?? '');
    if (dismissed != null && now.difference(dismissed) < upgradeCardPause) {
      return false;
    }
    return _trips.any(
      (t) => expensesOf(t.id).isNotEmpty && isSettled(balancesOf(t)),
    );
  }

  Future<void> dismissUpgradeCard() async {
    await _set('upgrade_dismissed', now.toIso8601String());
    notifyListeners();
  }

  // ------------------------------------------------------------- trips

  List<Trip> get trips => List.unmodifiable(_trips);

  Trip? trip(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> saveTrip(Trip trip) async {
    await _repo.saveTrip(trip);
    final i = _trips.indexWhere((t) => t.id == trip.id);
    if (i >= 0) {
      _trips[i] = trip;
    } else {
      _trips.insert(0, trip);
    }
    notifyListeners();
  }

  Future<void> deleteTrip(String tripId) async {
    await _repo.deleteTrip(tripId);
    _trips.removeWhere((t) => t.id == tripId);
    _expenses.remove(tripId);
    _payments.remove(tripId);
    notifyListeners();
  }

  /// True when the participant appears in any expense or payment (AC-4).
  bool participantInUse(String tripId, String participantId) =>
      expensesOf(tripId).any(
        (e) =>
            e.paidBy == participantId || e.splitAmong.contains(participantId),
      ) ||
      paymentsOf(tripId)
          .any((p) => p.fromId == participantId || p.toId == participantId);

  // ------------------------------------------------------------- expenses

  /// Expenses newest date first (AC-14).
  List<Expense> expensesOf(String tripId) {
    final list = List.of(_expenses[tripId] ?? const <Expense>[]);
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> saveExpense(Expense e) async {
    await _repo.saveExpense(e);
    final list = _expenses.putIfAbsent(e.tripId, () => []);
    final i = list.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      list[i] = e;
    } else {
      list.add(e);
    }
    notifyListeners();
  }

  Future<void> deleteExpense(Expense e) async {
    await _repo.deleteExpense(e.id);
    _expenses[e.tripId]?.removeWhere((x) => x.id == e.id);
    notifyListeners();
  }

  // ------------------------------------------------------------- payments

  /// Payments newest first (AC-25).
  List<Payment> paymentsOf(String tripId) {
    final list = List.of(_payments[tripId] ?? const <Payment>[]);
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> savePayment(Payment p) async {
    await _repo.savePayment(p);
    _payments.putIfAbsent(p.tripId, () => []).add(p);
    notifyListeners();
  }

  Future<void> deletePayment(Payment p) async {
    await _repo.deletePayment(p.id);
    _payments[p.tripId]?.removeWhere((x) => x.id == p.id);
    notifyListeners();
  }

  Map<String, int> balancesOf(Trip t) =>
      balancesFor(t, expensesOf(t.id), paymentsOf(t.id));

  int totalOf(Trip t) =>
      expensesOf(t.id)
          .fold(0, (sum, e) => sum + baseAmountOf(e, t.baseCurrency));

  // ------------------------------------------------------------- categories

  List<CustomCategory> get customCategories => List.unmodifiable(_categories);

  List<CategoryInfo> get allCategories => [
    ...builtInCategories,
    for (final c in _categories) customCategoryInfo(c),
  ];

  CategoryInfo category(String id) {
    for (final c in allCategories) {
      if (c.id == id) return c;
    }
    return builtInCategories.last;
  }

  int categoryUseCount(String categoryId) => _expenses.values
      .expand((l) => l)
      .where((e) => e.categoryId == categoryId)
      .length;

  bool categoryNameTaken(String name, {String? exceptId}) {
    final n = name.trim().toLowerCase();
    return allCategories.any(
      (c) => c.id != exceptId && c.name.toLowerCase() == n,
    );
  }

  Future<void> saveCategory(CustomCategory c) async {
    await _repo.saveCategory(c);
    final i = _categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _categories[i] = c;
    } else {
      _categories.add(c);
    }
    notifyListeners();
  }

  /// Deletes an unused custom category; returns false when it is in use.
  Future<bool> deleteCategory(String id) async {
    if (categoryUseCount(id) > 0) return false;
    await _repo.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------- rates

  RateTable? get latestRates => _latestRates;

  /// Fetches the latest rates and caches them for offline use (AC-18).
  Future<RateTable?> refreshRates() async {
    final table = await services.rates.latest();
    if (table != null) {
      _latestRates = table;
      await _set('rates_latest', jsonEncode(table.toJson()));
      notifyListeners();
    }
    return table;
  }

  // ------------------------------------------------------------- backup

  Backup makeBackup() => Backup(
    savedAt: now,
    data: Snapshot(
      trips: _trips,
      expenses: _expenses.values.expand((l) => l).toList(),
      payments: _payments.values.expand((l) => l).toList(),
      categories: _categories,
    ),
  );

  /// Replaces all trips and categories with the backup's (AC-40).
  Future<void> restoreBackup(Backup b) async {
    await _repo.replaceData(b.data);
    _apply(b.data);
    notifyListeners();
  }
}
