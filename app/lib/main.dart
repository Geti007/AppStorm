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
    _state.addListener(_onStateChanged);
    _state.load();
  }

  bool _startedUp = false;
  bool _premiumChecked = false;
  bool _adsStarted = false;

  /// Runs the launch steps once data has loaded (also after "Try again" on
  /// the error screen), and starts the ads SDK whenever the user is on the
  /// free plan, including when Premium lapses mid-session.
  void _onStateChanged() {
    if (!widget.startServices || !_state.loaded) return;
    if (!_startedUp) {
      _startedUp = true;
      _startUp();
    }
    if (_premiumChecked && _state.adsEnabled && !_adsStarted) {
      _adsStarted = true;
      widget.services.ads.start().catchError((Object _) {});
    }
  }

  Future<void> _startUp() async {
    try {
      // Premium is re-checked with the store before any ad is requested.
      await _state.refreshPremium();
    } on Object {
      // Offline or store unavailable: the cached status stays in use.
    }
    _premiumChecked = true;
    _onStateChanged();
    _state.refreshRates().catchError((Object _) => null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Premium is re-checked whenever the app comes back (AC-40a).
    if (s == AppLifecycleState.resumed &&
        _state.loaded &&
        widget.startServices) {
      _state.refreshPremium().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_onStateChanged);
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
          builder: (context, child) => ReadableWidth(child: child!),
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
