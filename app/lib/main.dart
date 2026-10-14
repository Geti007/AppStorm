import 'dart:async';

import 'package:flutter/material.dart';

import 'data/storage.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/ads.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ads = GoogleAdsService(await AdUnits.load());
  await runGlassful(storage: PrefsStorage(), ads: ads);
}

/// Starts the app. Tests pass their own storage, ads and clock.
Future<void> runGlassful({
  required Storage storage,
  required AdsService ads,
  Clock? clock,
}) async {
  final state = AppState(storage: storage, clock: clock);
  runApp(GlassfulApp(state: state, ads: ads));
  await state.load();
}

class GlassfulApp extends StatefulWidget {
  const GlassfulApp({super.key, required this.state, required this.ads});

  final AppState state;
  final AdsService ads;

  @override
  State<GlassfulApp> createState() => _GlassfulAppState();
}

class _GlassfulAppState extends State<GlassfulApp> with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Timer? _midnight;
  bool _errorShown = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(_onState);
    // The data may already have loaded before this widget was attached.
    _onState();
    _scheduleMidnight();
    // Consent and ads start at every launch, without blocking the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.ads.start());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.removeListener(_onState);
    _midnight?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      state.refreshDay();
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = state.now;
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      state.refreshDay();
      _scheduleMidnight();
    });
  }

  void _onState() {
    if (state.loaded && state.loadFailed && !_errorShown) {
      _errorShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text("Couldn't read saved data. Starting fresh."),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glassful',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.loaded) {
            return const Scaffold(
              key: Key('loading'),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!state.onboarded) return OnboardingScreen(state: state);
          return HomeShell(state: state, ads: widget.ads);
        },
      ),
    );
  }
}
