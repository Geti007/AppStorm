import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'balances_tab.dart';
import 'expense_form_screen.dart';
import 'expenses_tab.dart';
import 'export_sheet.dart';
import 'stats_tab.dart';
import 'trip_form_screen.dart';

/// One trip: header stats (AC-27) and the Expenses, Balances and Stats tabs.
class TripDashboardScreen extends StatefulWidget {
  const TripDashboardScreen({
    super.key,
    required this.tripId,
    this.initialTab = 0,
  });

  final String tripId;
  final int initialTab;

  @override
  State<TripDashboardScreen> createState() => _TripDashboardScreenState();
}

class _TripDashboardScreenState extends State<TripDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addExpense(Trip trip) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ExpenseFormScreen(tripId: trip.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trip = state.trip(widget.tripId);
    if (trip == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final t = Theme.of(context).textTheme;
    final expenses = state.expensesOf(trip.id);
    final total = state.totalOf(trip);
    final average = trip.participants.isEmpty
        ? 0
        : (total / trip.participants.length).round();
    final white = t.bodyLarge?.copyWith(color: Colors.white);
    final header = Container(
      decoration: BoxDecoration(gradient: headerGradient(trip.cover)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total spent', style: white),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(total, trip.baseCurrency),
                key: const Key('header_total'),
                style: t.displaySmall?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 4,
              children: [
                Text(
                  plural(expenses.length, 'expense', 'expenses'),
                  key: const Key('header_count'),
                  style: white,
                ),
                Text(
                  '${formatMoney(average, trip.baseCurrency)} avg per person',
                  key: const Key('header_average'),
                  style: white,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      floatingActionButton: _tabs.index < 2
          ? FloatingActionButton(
              key: const Key('add_expense'),
              tooltip: 'Add expense',
              onPressed: () => _addExpense(trip),
              child: const Icon(Icons.add),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: tripCovers[trip.cover % tripCovers.length].$3,
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(gradient: headerGradient(trip.cover)),
            ),
            title: Text(
              trip.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            actions: [
              IconButton(
                key: const Key('open_export'),
                tooltip: 'Share or export',
                icon: const Icon(Icons.ios_share),
                onPressed: () => showExportSheet(context, trip),
              ),
              IconButton(
                key: const Key('edit_trip'),
                tooltip: 'Edit trip',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => TripFormScreen(trip: trip),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(child: header),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(key: Key('tab_expenses'), text: 'Expenses'),
                  Tab(key: Key('tab_balances'), text: 'Balances'),
                  Tab(key: Key('tab_stats'), text: 'Stats'),
                ],
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            ExpensesTab(trip: trip, onAdd: () => _addExpense(trip)),
            BalancesTab(trip: trip),
            StatsTab(trip: trip),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}
