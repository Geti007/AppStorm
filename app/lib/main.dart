import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'data/repository.dart';
import 'screens/onboarding_screen.dart';
import 'screens/trips_screen.dart';
import 'services/ads.dart';
import 'services/billing.dart';
import 'services/files.dart';
import 'services/rates.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

const String packageId = 'com.geti007.trippi';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final units = await AdUnits.load();
  final services = AppServices(
    repository: SqliteRepository(),
    rates: FrankfurterRateService(),
    billing: StoreBillingService(packageName: packageId),
    ads: units.isConfigured ? GoogleAdsService(units) : NoAdsService(),
    files: SystemFiles(),
    isIOS: Platform.isIOS,
  );
  runApp(TrippiApp(services: services));
}

class TrippiApp extends StatefulWidget {
  const TrippiApp({
    super.key,
    required this.services,
    this.startServices = true,
  });

  final AppServices services;

  /// Whether to contact the store, the ads SDK and the rate service at
  /// launch. Tests turn this off and drive the services themselves.
  final bool startServices;

  @override
  State<TrippiApp> createState() => _TrippiAppState();
}

class _TrippiAppState extends State<TrippiApp> with WidgetsBindingObserver {
  late final AppState _state = AppState(widget.services);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    await _state.load();
    if (!_state.loaded || !widget.startServices) return;
    await _state.refreshPremium();
    if (_state.adsEnabled) {
      widget.services.ads.start();
    }
    _state.refreshRates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Premium is re-checked whenever the app comes back (AC-40a).
    if (s == AppLifecycleState.resumed &&
        _state.loaded &&
        widget.startServices) {
      _state.refreshPremium();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => MaterialApp(
          title: 'Trippi',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, _state.accent),
          darkTheme: buildTheme(Brightness.dark, _state.accent),
          themeMode: _state.themeMode,
          home: const _Home(),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.loadError != null) {
      return Scaffold(body: ErrorState(onRetry: state.load));
    }
    if (!state.loaded) {
      return const Scaffold(body: SafeArea(child: SkeletonList()));
    }
    if (!state.onboardingDone) return const OnboardingScreen();
    return const TripsScreen();
  }
}
