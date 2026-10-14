import 'package:flutter/material.dart';

import '../services/ads.dart';

/// The History banner: a row reserved below the content that only takes
/// space once an ad has loaded. Nothing is shown before, or if it fails.
class BannerArea extends StatefulWidget {
  const BannerArea({super.key, required this.ads});

  final AdsService ads;

  @override
  State<BannerArea> createState() => _BannerAreaState();
}

class _BannerAreaState extends State<BannerArea> {
  BannerSlot? _slot;
  int? _width;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    widget.ads.canRequestAds.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      _slot?.dispose();
      _slot = null;
      _maybeLoad();
    }
  }

  Future<void> _maybeLoad() async {
    final width = _width;
    if (_slot != null || _requesting || width == null) return;
    if (!widget.ads.canRequestAds.value) return;
    _requesting = true;
    final slot = await widget.ads.createBanner(width);
    _requesting = false;
    if (!mounted) {
      slot?.dispose();
      return;
    }
    if (slot != null) setState(() => _slot = slot);
  }

  @override
  void dispose() {
    widget.ads.canRequestAds.removeListener(_maybeLoad);
    _slot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    if (slot == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: slot.loaded,
      builder: (context, loaded, _) {
        if (!loaded) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: SizedBox(
            key: const Key('history_banner'),
            width: double.infinity,
            height: slot.height,
            child: Center(child: slot.build()),
          ),
        );
      },
    );
  }
}
