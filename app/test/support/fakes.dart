import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/data/repository.dart';
import 'package:trippi/main.dart';
import 'package:trippi/services/ads.dart';
import 'package:trippi/services/billing.dart';
import 'package:trippi/services/files.dart';
import 'package:trippi/services/rates.dart';
import 'package:trippi/state/app_state.dart';
import 'package:trippi/widgets/common.dart';

class FakeBilling implements BillingService {
  final controller = StreamController<PurchaseOutcome>.broadcast();
  StoreOffer? offer = const StoreOffer(price: r'$1.99', trialEligible: true);
  bool? active;
  int buys = 0;
  int restores = 0;
  PurchaseOutcome? buyResult = PurchaseOutcome.purchased;
  PurchaseOutcome? restoreResult = PurchaseOutcome.nothingToRestore;

  @override
  Stream<PurchaseOutcome> get outcomes => controller.stream;

  @override
  Future<StoreOffer?> loadOffer() async => offer;

  @override
  Future<void> buy(StoreOffer offer) async {
    buys++;
    if (buyResult != null) controller.add(buyResult!);
  }

  @override
  Future<void> restore() async {
    restores++;
    if (restoreResult != null) controller.add(restoreResult!);
  }

  @override
  Future<bool?> checkActive() async => active;

  @override
  Uri get manageUrl => Uri.parse('https://example.com/manage');
}

class FakeNativeSlot implements NativeAdSlot {
  FakeNativeSlot(bool loads) : _loaded = ValueNotifier(loads);

  final ValueNotifier<bool> _loaded;
  bool disposed = false;

  @override
  ValueListenable<bool> get loaded => _loaded;

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 120, child: Text('Test ad'));

  @override
  void dispose() => disposed = true;
}

class FakeAds implements AdsService {
  final canRequest = ValueNotifier(true);
  final privacyRequired = ValueNotifier(false);
  final ready = ValueNotifier(false);

  /// Whether native ads load (false simulates offline or no fill).
  bool nativeLoads = true;
  bool rewardEarned = true;
  int started = 0;
  int nativeRequests = 0;
  int rewardedLoads = 0;
  int rewardedShows = 0;

  @override
  Future<void> start() async => started++;

  @override
  ValueListenable<bool> get canRequestAds => canRequest;

  @override
  ValueListenable<bool> get privacyOptionsRequired => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  NativeAdSlot? createNativeAd(ThemeData theme) {
    if (!canRequest.value) return null;
    nativeRequests++;
    return FakeNativeSlot(nativeLoads);
  }

  @override
  ValueListenable<bool> get rewardedReady => ready;

  @override
  void loadRewarded() => rewardedLoads++;

  @override
  Future<bool> showRewarded() async {
    rewardedShows++;
    ready.value = false;
    return rewardEarned;
  }
}

class FakeRates implements RateService {
  RateTable? latestTable = const RateTable('2026-10-10', {
    'EUR': 1,
    'USD': 1.10,
    'JPY': 160,
    'GBP': 0.85,
  });
  RateTable? historicalTable = const RateTable('2026-08-01', {
    'EUR': 1,
    'USD': 1.25,
    'JPY': 150,
  });
  int latestCalls = 0;
  int historicalCalls = 0;

  @override
  Future<RateTable?> latest() async {
    latestCalls++;
    return latestTable;
  }

  @override
  Future<RateTable?> onDate(DateTime day) async {
    historicalCalls++;
    return historicalTable;
  }
}

class FakeFiles implements DeviceFiles {
  final List<String> texts = [];
  final List<(Uint8List, String, String)> sharedFiles = [];
  Uint8List? toPick;
  bool failShare = false;

  @override
  Future<void> shareText(String text, {String? subject}) async =>
      texts.add(text);

  @override
  Future<void> shareFile(Uint8List bytes, String fileName, String mime) async {
    if (failShare) throw Exception('share failed');
    sharedFiles.add((bytes, fileName, mime));
  }

  @override
  Future<Uint8List?> pickFile() async => toPick;
}

/// The in-memory store, with switches to simulate storage failures.
class TestRepository extends MemoryRepository {
  TestRepository([super.initial]);

  /// How many of the next loads fail.
  int failLoads = 0;

  /// Whether deleting an expense fails.
  bool failDeletes = false;

  /// When set, loads wait for this before reading.
  Future<void>? holdLoads;

  @override
  Future<Snapshot> load() async {
    if (holdLoads != null) await holdLoads;
    if (failLoads > 0) {
      failLoads--;
      throw Exception('database unavailable');
    }
    return super.load();
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    if (failDeletes) throw Exception('disk full');
    return super.deleteExpense(expenseId);
  }
}

/// Everything a test needs to drive the app.
class Harness {
  Harness({
    Snapshot initial = const Snapshot(),
    bool onboarded = true,
    bool premium = false,
    DateTime? now,
    this.isIOS = false,
  }) : repo = TestRepository(
         Snapshot(
           trips: initial.trips,
           expenses: initial.expenses,
           payments: initial.payments,
           categories: initial.categories,
           settings: {
             if (onboarded) 'onboarding_done': '1',
             if (premium) 'premium': '1',
             ...initial.settings,
           },
         ),
       ),
       clockNow = now ?? DateTime(2026, 10, 11, 12);

  final TestRepository repo;
  final billing = FakeBilling();
  final ads = FakeAds();
  final rates = FakeRates();
  final files = FakeFiles();
  final bool isIOS;
  DateTime clockNow;

  late final AppServices services = AppServices(
    repository: repo,
    rates: rates,
    billing: billing,
    ads: ads,
    files: files,
    clock: () => clockNow,
    openUrl: (url) async => openedUrls.add(url),
    isIOS: isIOS,
  );

  final List<Uri> openedUrls = [];

  Future<void> pump(WidgetTester tester, {bool startServices = false}) async {
    await tester.pumpWidget(
      TrippiApp(services: services, startServices: startServices),
    );
    await tester.pumpAndSettle();
  }

  AppState state(WidgetTester tester) =>
      AppScope.read(tester.element(find.byType(Scaffold).first));
}

// ---------------------------------------------------------------- sample data

const ana = Participant(id: 'p-ana', name: 'Ana');
const ben = Participant(id: 'p-ben', name: 'Ben');
const cleo = Participant(id: 'p-cleo', name: 'Cleo');

Trip sampleTrip({
  String id = 't-lisbon',
  String name = 'Lisbon weekend',
  List<Participant> people = const [ana, ben, cleo],
  String currency = 'EUR',
  DateTime? created,
}) => Trip(
  id: id,
  name: name,
  baseCurrency: currency,
  cover: 0,
  participants: people,
  createdAt: created ?? DateTime(2026, 10, 1),
  startDate: DateTime(2026, 10, 2),
  endDate: DateTime(2026, 10, 5),
);

Expense sampleExpense({
  required String id,
  String tripId = 't-lisbon',
  String title = 'Dinner',
  int amount = 9000,
  String currency = 'EUR',
  double rate = 1,
  String paidBy = 'p-ana',
  List<String> among = const ['p-ana', 'p-ben', 'p-cleo'],
  SplitMethod method = SplitMethod.equal,
  Map<String, int> inputs = const {},
  String category = 'food',
  DateTime? date,
}) => Expense(
  id: id,
  tripId: tripId,
  title: title,
  amountMinor: amount,
  currency: currency,
  rate: rate,
  categoryId: category,
  date: date ?? DateTime(2026, 10, 3),
  paidBy: paidBy,
  method: method,
  splitAmong: among,
  splitInputs: inputs,
  createdAt: DateTime(2026, 10, 3, 20),
);

/// A typical phone screen (393 × 852 logical pixels).
void usePhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Taps a widget after scrolling it into view.
Future<void> tapOn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}
