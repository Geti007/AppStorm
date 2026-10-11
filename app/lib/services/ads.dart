import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit ids. Debug and profile builds always use Google's published test
/// ads; release builds read the owner's ids from config/ads.release.json.
class AdUnits {
  const AdUnits({required this.native, required this.rewarded});

  final String native;
  final String rewarded;

  bool get isConfigured => native.isNotEmpty && rewarded.isNotEmpty;

  // Google's test ad units ("Enable test ads" page; also used in the
  // google_mobile_ads example app).
  static const androidTest = AdUnits(
    native: 'ca-app-pub-3940256099942544/2247696110',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const iosTest = AdUnits(
    native: 'ca-app-pub-3940256099942544/3986624511',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  );

  static Future<AdUnits> load() async {
    final platformKey = Platform.isAndroid ? 'android' : 'ios';
    if (!kReleaseMode) {
      return Platform.isAndroid ? androidTest : iosTest;
    }
    try {
      final json = jsonDecode(
        await rootBundle.loadString('config/ads.release.json'),
      ) as Map<String, dynamic>;
      final p = (json[platformKey] as Map).cast<String, dynamic>();
      return AdUnits(
        native: (p['native_lists'] as String?) ?? '',
        rewarded: (p['rewarded_pass'] as String?) ?? '',
      );
    } on Object {
      return const AdUnits(native: '', rewarded: '');
    }
  }
}

/// A native ad that reports when it has loaded. Until then (or if it never
/// loads) nothing is shown, so a failed ad leaves no gap.
abstract class NativeAdSlot {
  ValueListenable<bool> get loaded;
  Widget build(BuildContext context);
  void dispose();
}

abstract class AdsService {
  /// Runs the consent flow (Google UMP) and starts the ads SDK once ads may
  /// be requested. Call once at launch for free users only.
  Future<void> start();

  /// True once consent allows requesting ads.
  ValueListenable<bool> get canRequestAds;

  /// True when the consent SDK says a "Privacy options" entry is required.
  ValueListenable<bool> get privacyOptionsRequired;

  Future<void> showPrivacyOptions();

  NativeAdSlot? createNativeAd(ThemeData theme);

  /// Whether a rewarded video is loaded and ready to show.
  ValueListenable<bool> get rewardedReady;

  /// Starts loading a rewarded video if none is loaded.
  void loadRewarded();

  /// Shows the rewarded video. Completes with true only when the ads SDK
  /// reports that the reward was earned.
  Future<bool> showRewarded();
}

class GoogleAdsService implements AdsService {
  GoogleAdsService(this._units);

  final AdUnits _units;
  final ValueNotifier<bool> _canRequest = ValueNotifier(false);
  final ValueNotifier<bool> _privacyRequired = ValueNotifier(false);
  final ValueNotifier<bool> _rewardedReady = ValueNotifier(false);
  bool _started = false;
  bool _sdkReady = false;
  bool _loadingRewarded = false;
  RewardedAd? _rewarded;

  @override
  ValueListenable<bool> get canRequestAds => _canRequest;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyRequired;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

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
        // Consent info couldn't be updated (e.g. offline); a choice made
        // earlier still applies.
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
            RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
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
  NativeAdSlot? createNativeAd(ThemeData theme) {
    if (!_canRequest.value || !_sdkReady) return null;
    return _GoogleNativeAdSlot(_units.native, _request, theme);
  }

  @override
  void loadRewarded() {
    if (!_canRequest.value || !_sdkReady || _rewarded != null) return;
    if (_loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: _units.rewarded,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          _rewardedReady.value = false;
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (ad == null) return Future.value(false);
    _rewarded = null;
    _rewardedReady.value = false;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}

class _GoogleNativeAdSlot implements NativeAdSlot {
  _GoogleNativeAdSlot(String unit, AdRequest request, ThemeData theme) {
    final scheme = theme.colorScheme;
    _ad = NativeAd(
      adUnitId: unit,
      request: request,
      listener: NativeAdListener(
        onAdLoaded: (_) => _loaded.value = true,
        onAdFailedToLoad: (_, _) => _loaded.value = false,
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: scheme.surface,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: scheme.onSurface,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: scheme.onSurfaceVariant,
          size: 13,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: scheme.onSurfaceVariant,
          size: 13,
        ),
      ),
    )..load();
  }

  late final NativeAd _ad;
  final ValueNotifier<bool> _loaded = ValueNotifier(false);

  @override
  ValueListenable<bool> get loaded => _loaded;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 120, child: AdWidget(ad: _ad));

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ad.dispose();
  }
}

/// No ads at all: used for Premium users before the app restarts, and when
/// release builds have no ad unit ids configured.
class NoAdsService implements AdsService {
  final ValueNotifier<bool> _false = ValueNotifier(false);

  @override
  Future<void> start() async {}

  @override
  ValueListenable<bool> get canRequestAds => _false;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  NativeAdSlot? createNativeAd(ThemeData theme) => null;

  @override
  ValueListenable<bool> get rewardedReady => _false;

  @override
  void loadRewarded() {}

  @override
  Future<bool> showRewarded() async => false;
}
