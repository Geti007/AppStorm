import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

const String premiumProductId = 'trippi_premium_monthly';

/// The subscription as the store offers it to this user right now.
class StoreOffer {
  const StoreOffer({
    required this.price,
    required this.trialEligible,
    this.details,
    this.offerToken,
  });

  /// Localised price per month, exactly as the store returns it.
  final String price;

  /// True only when the store says this user can get the free trial.
  final bool trialEligible;
  final ProductDetails? details;
  final String? offerToken;
}

enum PurchaseOutcome {
  purchased,
  restored,
  nothingToRestore,
  pending,
  cancelled,
  failed,
}

/// Apple and Google subscriptions behind one small interface.
abstract class BillingService {
  /// Purchase results, including ones that finish while the app is closed.
  Stream<PurchaseOutcome> get outcomes;

  /// The offer, or null when the store is unavailable or has no product.
  Future<StoreOffer?> loadOffer();

  Future<void> buy(StoreOffer offer);

  Future<void> restore();

  /// Whether the subscription is active now, or null when the store can't
  /// be reached (the cached status is used then).
  Future<bool?> checkActive();

  /// The store page where the user manages or cancels the subscription.
  Uri get manageUrl;
}

class StoreBillingService implements BillingService {
  StoreBillingService({required this.packageName}) {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
  }

  final String packageName;
  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<PurchaseOutcome> _outcomes =
      StreamController.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  bool _restoring = false;
  bool _restoredAny = false;

  @override
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != premiumProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _outcomes.add(PurchaseOutcome.pending);
        case PurchaseStatus.purchased:
          _outcomes.add(PurchaseOutcome.purchased);
        case PurchaseStatus.restored:
          _restoredAny = true;
          _outcomes.add(PurchaseOutcome.restored);
        case PurchaseStatus.canceled:
          _outcomes.add(PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          _outcomes.add(PurchaseOutcome.failed);
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  @override
  Future<StoreOffer?> loadOffer() async {
    try {
      if (!await _iap.isAvailable()) return null;
      final res = await _iap.queryProductDetails({premiumProductId});
      if (res.error != null || res.productDetails.isEmpty) return null;
      if (Platform.isAndroid) return _androidOffer(res.productDetails);
      final details = res.productDetails.first;
      var eligible = false;
      try {
        eligible = await SK2Product.isIntroductoryOfferEligible(
          premiumProductId,
        );
      } on Exception {
        eligible = false;
      }
      return StoreOffer(
        price: details.price,
        trialEligible: eligible,
        details: details,
      );
    } on Exception {
      return null;
    }
  }

  /// Google Play returns one entry per offer the user can get; a free-trial
  /// offer is only among them when the user is eligible for it.
  StoreOffer? _androidOffer(List<ProductDetails> all) {
    GooglePlayProductDetails? base;
    GooglePlayProductDetails? trial;
    for (final d in all.whereType<GooglePlayProductDetails>()) {
      final index = d.subscriptionIndex;
      final offers = d.productDetails.subscriptionOfferDetails;
      if (index == null || offers == null || index >= offers.length) continue;
      final offer = offers[index];
      final phases = offer.pricingPhases;
      if (phases.isEmpty) continue;
      if (offer.offerId == null) base ??= d;
      if (phases.first.priceAmountMicros == 0) trial ??= d;
    }
    final chosen = trial ?? base;
    if (chosen == null) return null;
    final offers = chosen.productDetails.subscriptionOfferDetails!;
    final offer = offers[chosen.subscriptionIndex!];
    final recurring = offer.pricingPhases.last;
    return StoreOffer(
      price: recurring.formattedPrice,
      trialEligible: trial != null,
      details: chosen,
      offerToken: offer.offerIdToken,
    );
  }

  @override
  Future<void> buy(StoreOffer offer) async {
    final details = offer.details;
    if (details == null) return;
    final PurchaseParam param = Platform.isAndroid
        ? GooglePlayPurchaseParam(
            productDetails: details,
            offerToken: offer.offerToken,
          )
        : PurchaseParam(productDetails: details);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    _restoredAny = false;
    try {
      await _iap.restorePurchases();
      // Restored purchases arrive on the purchase stream; give them a moment.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_restoredAny) _outcomes.add(PurchaseOutcome.nothingToRestore);
    } on Exception {
      _outcomes.add(PurchaseOutcome.failed);
    } finally {
      _restoring = false;
    }
  }

  @override
  Future<bool?> checkActive() async {
    try {
      if (!await _iap.isAvailable()) return null;
      if (Platform.isAndroid) {
        final addition = _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final res = await addition.queryPastPurchases();
        if (res.error != null) return null;
        return res.pastPurchases.any(
          (p) =>
              p.productID == premiumProductId &&
              (p.status == PurchaseStatus.purchased ||
                  p.status == PurchaseStatus.restored),
        );
      }
      final transactions = await SK2Transaction.transactions();
      final now = DateTime.now().millisecondsSinceEpoch;
      return transactions.any((t) {
        if (t.productId != premiumProductId) return false;
        final expires = int.tryParse(t.expirationDate ?? '');
        return expires != null && expires > now;
      });
    } on Exception {
      return null;
    }
  }

  @override
  Uri get manageUrl => Platform.isAndroid
      ? Uri.parse(
          'https://play.google.com/store/account/subscriptions?sku=$premiumProductId&package=$packageName',
        )
      : Uri.parse('https://apps.apple.com/account/subscriptions');

  void dispose() {
    _sub.cancel();
    _outcomes.close();
  }
}
