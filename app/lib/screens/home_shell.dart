import 'package:flutter/material.dart';

import '../services/ads.dart';
import '../state/app_state.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state, required this.ads});

  final AppState state;
  final AdsService ads;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(state: widget.state),
          HistoryScreen(
            state: widget.state,
            ads: widget.ads,
            visible: _tab == 1,
          ),
          SettingsScreen(state: widget.state, ads: widget.ads),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('nav'),
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          // Undo belongs to Today; on History it would float over the ad.
          if (i != _tab) ScaffoldMessenger.of(context).removeCurrentSnackBar();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            key: Key('tab_today'),
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Today',
          ),
          NavigationDestination(
            key: Key('tab_history'),
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'History',
          ),
          NavigationDestination(
            key: Key('tab_settings'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
