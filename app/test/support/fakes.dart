import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/models.dart';
import 'package:glassful/data/storage.dart';
import 'package:glassful/data/units.dart';
import 'package:glassful/main.dart';
import 'package:glassful/services/ads.dart';
import 'package:glassful/state/app_state.dart';

class MemoryStorage implements Storage {
  MemoryStorage([this.data]);

  String? data;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async {
    writes++;
    data = d;
  }

  @override
  Future<void> clear() async => data = null;

  Map<String, dynamic> get json => jsonDecode(data!) as Map<String, dynamic>;
}

/// A clock the test can move.
class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

class FakeBanner implements BannerSlot {
  FakeBanner({required bool loads}) {
    if (loads) _loaded.value = true;
  }

  final ValueNotifier<bool> _loaded = ValueNotifier(false);
  bool disposed = false;

  @override
  ValueListenable<bool> get loaded => _loaded;

  @override
  double get height => 50;

  @override
  Widget build() => const ColoredBox(
    key: Key('fake_ad'),
    color: Colors.amber,
    child: SizedBox.expand(),
  );

  @override
  void dispose() => disposed = true;

  /// Simulates a later refresh that loads or fails.
  void setLoaded(bool value) => _loaded.value = value;
}

class FakeAds implements AdsService {
  FakeAds({
    bool canRequest = true,
    bool privacyRequired = false,
    this.bannerLoads = true,
  }) : canRequest = ValueNotifier(canRequest),
       privacyRequired = ValueNotifier(privacyRequired);

  final ValueNotifier<bool> canRequest;
  final ValueNotifier<bool> privacyRequired;
  bool bannerLoads;
  int started = 0;
  int bannersCreated = 0;
  int privacyShown = 0;
  final List<FakeBanner> banners = [];

  @override
  Future<void> start() async => started++;

  @override
  ValueListenable<bool> get canRequestAds => canRequest;

  @override
  ValueListenable<bool> get privacyOptionsRequired => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async => privacyShown++;

  @override
  Future<BannerSlot?> createBanner(int width) async {
    if (!canRequest.value) return null;
    bannersCreated++;
    final banner = FakeBanner(loads: bannerLoads);
    banners.add(banner);
    return banner;
  }
}

/// Saved data as the app writes it.
String savedJson({
  bool onboarded = true,
  VolumeUnit unit = VolumeUnit.ml,
  List<(DateTime, double)> goals = const [],
  List<(DateTime, double)> drinks = const [],
}) {
  var id = 1;
  return jsonEncode({
    'onboarded': onboarded,
    'unit': unit.storageName,
    'goals': [
      for (final g in goals) GoalChange(day: dayOf(g.$1), ml: g.$2).toJson(),
    ],
    'drinks': [
      for (final d in drinks) Drink(id: id++, time: d.$1, ml: d.$2).toJson(),
    ],
  });
}

/// A fixed "now" for tests: Wednesday 14 October 2026, 15:00.
final DateTime testNow = DateTime(2026, 10, 14, 15);

DateTime daysAgo(int n, {int hour = 10}) =>
    DateTime(testNow.year, testNow.month, testNow.day - n, hour);

class Harness {
  Harness(this.state, this.storage, this.ads, this.clock);

  final AppState state;
  final MemoryStorage storage;
  final FakeAds ads;
  final TestClock clock;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  MemoryStorage? storage,
  FakeAds? ads,
  TestClock? clock,
  bool settle = true,
  bool phoneView = true,
}) async {
  if (phoneView) usePhoneView(tester);
  final s = storage ?? MemoryStorage(savedJson(goals: [(daysAgo(30), 2000)]));
  final a = ads ?? FakeAds();
  final c = clock ?? TestClock(testNow);
  final state = AppState(storage: s, clock: c.call);
  await tester.pumpWidget(GlassfulApp(state: state, ads: a));
  await state.load();
  if (settle) await tester.pumpAndSettle();
  return Harness(state, s, a, c);
}

/// Simulates closing and reopening the app with the same saved data.
Future<Harness> restart(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  return pumpApp(
    tester,
    storage: h.storage,
    ads: h.ads,
    clock: h.clock,
    phoneView: false,
  );
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

/// A tall phone screen (412 x 915 dp) so whole screens fit, like a Pixel 7.
void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}
