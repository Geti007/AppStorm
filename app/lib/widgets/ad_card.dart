import 'package:flutter/material.dart';

import '../services/ads.dart';
import 'common.dart';

/// A native ad styled like the app's cards, labelled "Sponsored" (AC-43).
/// It takes no space until an ad has loaded, so a failed or offline ad
/// leaves no gap.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAdSlot? _slot;

  /// Creates the ad once ads are allowed; disposes it if Premium starts.
  NativeAdSlot? _ensureSlot() {
    final state = AppScope.of(context);
    final ads = state.services.ads;
    if (!state.adsEnabled) {
      _slot?.dispose();
      _slot = null;
    } else if (_slot == null && ads.canRequestAds.value) {
      _slot = ads.createNativeAd(Theme.of(context));
    }
    return _slot;
  }

  @override
  void dispose() {
    _slot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = AppScope.of(context).services.ads;
    return ValueListenableBuilder<bool>(
      valueListenable: ads.canRequestAds,
      builder: (context, _, _) => _buildAd(context),
    );
  }

  Widget _buildAd(BuildContext context) {
    final slot = _ensureSlot();
    if (slot == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: slot.loaded,
      builder: (context, loaded, _) {
        if (!loaded) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: widget.padding,
          child: Card(
            key: const Key('native_ad'),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sponsored',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  slot.build(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
