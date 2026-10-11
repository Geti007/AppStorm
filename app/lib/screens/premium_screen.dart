import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/billing.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'text_page.dart';

const String appleEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

Future<void> openPremium(BuildContext context, PaywallSource source) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PremiumScreen(source: source),
      ),
    );

const List<String> premiumBenefits = [
  'No ads',
  'Unlimited trips and people',
  'Advanced stats',
  'PDF and Excel export',
  'Historical exchange rates',
  'Custom categories',
  'Back up to a file',
  'Premium themes',
];

enum _OfferState { loading, ready, unavailable }

/// The paywall (AC-34 to AC-36, AC-45, AC-45a).
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, required this.source});

  final PaywallSource source;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  _OfferState _offerState = _OfferState.loading;
  StoreOffer? _offer;
  bool _pending = false;
  bool _watching = false;
  StreamSubscription<PurchaseOutcome>? _sub;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final state = AppScope.read(context);
    _sub = state.services.billing.outcomes.listen(_onOutcome);
    _loadOffer();
    if (_offersVideo(state)) state.services.ads.loadRewarded();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _offersVideo(AppState state) =>
      widget.source.passUnlocks && !state.isPremium;

  Future<void> _loadOffer() async {
    setState(() => _offerState = _OfferState.loading);
    final offer = await AppScope.read(context).services.billing.loadOffer();
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _offerState = offer == null ? _OfferState.unavailable : _OfferState.ready;
    });
  }

  void _onOutcome(PurchaseOutcome o) {
    if (!mounted) return;
    switch (o) {
      case PurchaseOutcome.pending:
        setState(() => _pending = true);
      case PurchaseOutcome.purchased || PurchaseOutcome.restored:
        final messenger = ScaffoldMessenger.of(context);
        AppScope.read(context).setPremium(true);
        Navigator.of(context).maybePop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Welcome to Premium!')),
        );
      case PurchaseOutcome.cancelled:
        setState(() => _pending = false);
      case PurchaseOutcome.failed:
        setState(() => _pending = false);
        showMessage(
          context,
          "Purchase didn't go through. You weren't charged.",
        );
      case PurchaseOutcome.nothingToRestore:
        setState(() => _pending = false);
        showMessage(context, 'No previous purchase found.');
    }
  }

  Future<void> _buy() async {
    final offer = _offer;
    if (offer == null || _pending) return;
    setState(() => _pending = true);
    try {
      await AppScope.read(context).services.billing.buy(offer);
    } on Object {
      if (mounted) {
        setState(() => _pending = false);
        showMessage(
          context,
          "Purchase didn't go through. You weren't charged.",
        );
      }
    }
  }

  Future<void> _watch() async {
    final state = AppScope.read(context);
    setState(() => _watching = true);
    await state.countRewardedShown();
    final earned = await state.services.ads.showRewarded();
    if (!mounted) return;
    setState(() => _watching = false);
    // The Pass is granted only when the ads SDK reports the reward.
    if (earned) {
      await state.grantPass();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        SnackBar(content: Text(passActiveText(state.passEnd!))),
      );
    } else if (!state.rewardedCapReached) {
      state.services.ads.loadRewarded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = state.services.isIOS ? 'App Store' : 'Google Play';
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(gradient: coverGradient(0)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      key: const Key('close_premium'),
                      tooltip: 'Close',
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ExcludeSemantics(child: _PinMark()),
                          const SizedBox(height: 16),
                          Text(
                            'Trippi Premium',
                            style: t.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Travel together. Split smarter.',
                            style: t.bodyLarge?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in premiumBenefits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(b, style: t.bodyLarge)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (state.isPremium)
                  Text(
                    'Premium active',
                    key: const Key('premium_active'),
                    style: t.titleLarge,
                  )
                else
                  _priceBlock(t, store),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    key: const Key('restore_purchases'),
                    onPressed: _pending
                        ? null
                        : () => state.services.billing.restore(),
                    child: const Text('Restore purchases'),
                  ),
                ),
                if (_offersVideo(state)) _rewardedCard(state, t, scheme),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      key: const Key('premium_privacy'),
                      onPressed: () =>
                          openTextPage(context, TextPageKind.privacy),
                      child: const Text('Privacy policy'),
                    ),
                    const Text('·'),
                    TextButton(
                      key: const Key('premium_terms'),
                      onPressed: () =>
                          openTextPage(context, TextPageKind.terms),
                      child: const Text('Terms of use'),
                    ),
                    if (state.services.isIOS) ...[
                      const Text('·'),
                      TextButton(
                        key: const Key('premium_eula'),
                        onPressed: () =>
                            AppScope.read(context).services
                                .openUrl(Uri.parse(appleEulaUrl)),
                        child: const Text('Apple EULA'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBlock(TextTheme t, String store) {
    final scheme = Theme.of(context).colorScheme;
    switch (_offerState) {
      case _OfferState.loading:
        return Column(
          key: const Key('price_loading'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 28,
              width: 180,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text('Loading prices…', style: t.bodyMedium),
          ],
        );
      case _OfferState.unavailable:
        return Column(
          key: const Key('premium_unavailable'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Premium isn't available right now", style: t.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('premium_retry'),
              onPressed: _loadOffer,
              child: const Text('Try again'),
            ),
          ],
        );
      case _OfferState.ready:
        final offer = _offer!;
        final start = DateFormat('d MMM y')
            .format(AppScope.read(context).now.add(const Duration(days: 7)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offer.trialEligible) ...[
              Text(
                'Free for 7 days',
                key: const Key('trial_title'),
                style: t.titleLarge,
              ),
              Text(
                'then ${offer.price}/month starting $start',
                key: const Key('price_text'),
                style: t.bodyLarge,
              ),
            ] else
              Text(
                '${offer.price}/month',
                key: const Key('price_text'),
                style: t.displaySmall,
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('subscribe'),
              onPressed: _pending ? null : _buy,
              child: _pending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      offer.trialEligible ? 'Start free trial' : 'Subscribe',
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'Renews automatically each month until cancelled. Cancel anytime in your $store subscription settings.',
              key: const Key('renewal_text'),
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
    }
  }

  Widget _rewardedCard(AppState state, TextTheme t, ColorScheme scheme) {
    final ads = state.services.ads;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('rewarded_offer'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<bool>(
            valueListenable: ads.rewardedReady,
            builder: (context, ready, _) {
              final pass = state.passActive;
              final available =
                  ready && !state.rewardedCapReached && !_watching;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_circle_outline, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Watch a short video for a free 24-hour Premium Pass',
                          style: t.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (pass) ...[
                    const SizedBox(height: 8),
                    Text(
                      passActiveText(state.passEnd!),
                      key: const Key('pass_active'),
                      style: t.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('watch_video'),
                    onPressed: available ? _watch : null,
                    child: Text(
                      available
                          ? 'Watch video'
                          : 'No video available right now',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Premium Pass active until 3:15 PM, Sat".
String passActiveText(DateTime end) =>
    'Premium Pass active until ${DateFormat.jm().format(end)}, ${DateFormat.E().format(end)}';

class _PinMark extends StatelessWidget {
  const _PinMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: CustomPaint(painter: _PinPainter()),
  );
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final pin = Path()
      ..moveTo(50 * s, 98 * s)
      ..cubicTo(14 * s, 62 * s, 8 * s, 50 * s, 8 * s, 42 * s)
      ..arcToPoint(Offset(92 * s, 42 * s), radius: Radius.circular(42 * s))
      ..cubicTo(92 * s, 50 * s, 86 * s, 62 * s, 50 * s, 98 * s)
      ..close();
    canvas.drawPath(pin, Paint()..color = Colors.white);
    final r = 24 * s;
    final c = Offset(50 * s, 42 * s);
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-3 * s, 0), radius: r),
      1.5708,
      3.1416,
      true,
      Paint()..color = const Color(0xFFFF7A59),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(3 * s, 0), radius: r),
      -1.5708,
      3.1416,
      true,
      Paint()..color = const Color(0xFF0A4A52),
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}
