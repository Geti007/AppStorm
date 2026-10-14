import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The History banner's ad unit. Debug and profile builds always use
/// Google's published test ad unit ("Enable test ads" page for Flutter);
/// release builds read the owner's id from config/ads.release.json.
class AdUnits {
  const AdUnits({required this.historyBanner});

  final String historyBanner;

  bool get isConfigured => historyBanner.isNotEmpty;

  static const androidTest = AdUnits(
    historyBanner: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const iosTest = AdUnits(
    historyBanner: 'ca-app-pub-3940256099942544/2934735716',
  );

  static Future<AdUnits> load() async {
    if (!kReleaseMode) return Platform.isAndroid ? androidTest : iosTest;
    try {
      final json = jsonDecode(
        await rootBundle.loadString('config/ads.release.json'),
      ) as Map<String, dynamic>;
      final p = (json[Platform.isAndroid ? 'android' : 'ios'] as Map)
          .cast<String, dynamic>();
      return AdUnits(historyBanner: (p['history_banner'] as String?) ?? '');
    } on Object {
      return const AdUnits(historyBanner: '');
    }
  }
}

/// A banner that reports when it has loaded. Until it loads (or if it never
/// does) nothing is shown, so a failed ad leaves no gap.
abstract class BannerSlot {
  ValueListenable<bool> get loaded;
  double get height;
  Widget build();
  void dispose();
}

abstract class AdsService {
  /// Updates consent with Google's UMP SDK, shows the consent form when it is
  /// required, and starts the ads SDK once ads may be requested.
  Future<void> start();

  ValueListenable<bool> get canRequestAds;

  /// True when the consent SDK says a "Privacy options" entry is required.
  ValueListenable<bool> get privacyOptionsRequired;

  Future<void> showPrivacyOptions();

  /// Starts loading an anchored adaptive banner [width] logical pixels wide.
  /// Null when ads may not be requested.
  Future<BannerSlot?> createBanner(int width);
}

class GoogleAdsService implements AdsService {
  GoogleAdsService(this._units);

  final AdUnits _units;
  final ValueNotifier<bool> _canRequest = ValueNotifier(false);
  final ValueNotifier<bool> _privacyRequired = ValueNotifier(false);
  bool _started = false;
  bool _sdkReady = false;

  @override
  ValueListenable<bool> get canRequestAds => _canRequest;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyRequired;

  // iOS ads are always non-personalised, so the app never tracks on iOS.
  AdRequest get _request => AdRequest(nonPersonalizedAds: Platform.isIOS);

  @override
  Future<void> start() async {
    if (_started || !_units.isConfigured) return;
    _started = true;
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        await _afterConsent();
        if (!done.isCompleted) done.complete();
      },
      (_) async {
        // Offline or the update failed; a choice made earlier still applies.
        await _afterConsent();
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  Future<void> _afterConsent() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyRequired.value =
          status == PrivacyOptionsRequirementStatus.required;
      if (await ConsentInformation.instance.canRequestAds()) {
        if (!_sdkReady) {
          await MobileAds.instance.initialize();
          await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
          );
          _sdkReady = true;
        }
        _canRequest.value = true;
      }
    } on Object {
      _canRequest.value = false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) async {
      await _afterConsent();
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  Future<BannerSlot?> createBanner(int width) async {
    if (!_canRequest.value || width <= 0) return null;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !_canRequest.value) return null;
    final slot = _GoogleBannerSlot(size);
    slot._ad = BannerAd(
      adUnitId: _units.historyBanner,
      size: size,
      request: _request,
      listener: BannerAdListener(
        onAdLoaded: (_) => slot._loaded.value = true,
        onAdFailedToLoad: (ad, _) {
          slot._loaded.value = false;
          ad.dispose();
          slot._ad = null;
        },
      ),
    )..load();
    return slot;
  }
}

class _GoogleBannerSlot implements BannerSlot {
  _GoogleBannerSlot(this._size);

  final AdSize _size;
  final ValueNotifier<bool> _loaded = ValueNotifier(false);
  BannerAd? _ad;

  @override
  ValueListenable<bool> get loaded => _loaded;

  @override
  double get height => _size.height.toDouble();

  @override
  Widget build() {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return AdWidget(ad: ad);
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

/// Used when ads cannot run (tests, store screenshots).
class NoAdsService implements AdsService {
  @override
  Future<void> start() async {}

  @override
  ValueListenable<bool> get canRequestAds => ValueNotifier(false);

  @override
  ValueListenable<bool> get privacyOptionsRequired => ValueNotifier(false);

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<BannerSlot?> createBanner(int width) async => null;
}
