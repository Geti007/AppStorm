import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ad_card.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import 'trip_dashboard_screen.dart';
import 'trip_form_screen.dart';

/// "12 – 19 Aug 2026", "28 Aug – 3 Sep 2026" or "" when no dates are set.
String formatTripDates(Trip t) {
  final s = t.startDate;
  final e = t.endDate ?? s;
  if (s == null || e == null) return '';
  final full = DateFormat('d MMM y');
  if (s == e) return full.format(s);
  if (s.year == e.year && s.month == e.month) {
    return '${s.day} – ${full.format(e)}';
  }
  if (s.year == e.year) {
    return '${DateFormat('d MMM').format(s)} – ${full.format(e)}';
  }
  return '${full.format(s)} – ${full.format(e)}';
}

/// Opens the trip form, or the Premium screen when the free trip limit is
/// reached (AC-6).
Future<void> startNewTrip(BuildContext context) async {
  final state = AppScope.read(context);
  if (!state.canCreateTrip) {
    await openPremium(context, PaywallSource.tripLimit);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const TripFormScreen(),
    ),
  );
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trips = state.trips;
    final t = Theme.of(context).textTheme;
    final items = <Widget>[];
    if (state.showUpgradeCard) items.add(const _UpgradeCard());
    for (var i = 0; i < trips.length; i++) {
      items.add(_TripCard(trip: trips[i]));
      // One native ad after the 2nd trip (AC-43).
      if (i == 1 && state.adsEnabled) {
        items.add(const NativeAdCard(key: Key('trips_ad')));
      }
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trippi', style: t.headlineSmall),
            Text(
              'Your trips',
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('open_settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: trips.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('new_trip'),
              onPressed: () => startNewTrip(context),
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
      body: trips.isEmpty
          ? EmptyState(
              key: const Key('trips_empty'),
              art: const Art(ArtKind.suitcase),
              title: 'No trips yet',
              body: 'Create a trip, add your travel crew, and start tracking shared costs.',
              action: FilledButton(
                key: const Key('create_first_trip'),
                onPressed: () => startNewTrip(context),
                child: const Text('Create your first trip'),
              ),
            )
          : ListView.separated(
              key: const Key('trips_list'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) => items[i],
            ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  Future<void> _menu(BuildContext context, String action) async {
    final state = AppScope.read(context);
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TripFormScreen(trip: trip),
        ),
      );
    } else if (action == 'delete') {
      final ok = await confirm(
        context,
        title: 'Delete this trip?',
        body:
            "${trip.name} and all its expenses and payments will be deleted. This can't be undone.",
        confirmLabel: 'Delete',
      );
      if (ok) await state.deleteTrip(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dates = formatTripDates(trip);
    final people = trip.participants;
    final total = state.totalOf(trip);
    return Card(
      key: Key('trip_${trip.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TripDashboardScreen(tripId: trip.id),
          ),
        ),
        onLongPress: () => _showOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 88),
              // The cover, then a scrim under the text so it stays readable.
              decoration: BoxDecoration(gradient: coverGradient(trip.cover)),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x59000000)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              trip.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (dates.isNotEmpty)
                              Text(
                                dates,
                                style: t.bodyMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: Key('trip_menu_${trip.id}'),
                        tooltip: 'Trip options',
                        iconColor: Colors.white,
                        onSelected: (v) => _menu(context, v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit trip'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete trip'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: t.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatMoney(total, trip.baseCurrency),
                        key: Key('trip_total_${trip.id}'),
                        style: t.titleMedium,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 26.0 * (people.length.clamp(1, 4)) + 10,
                        height: 36,
                        child: Stack(
                          children: [
                            for (var i = 0; i < people.length && i < 4; i++)
                              Positioned(
                                left: i * 26.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: scheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Avatar(name: people[i].name, size: 32),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          people.length > 4
                              ? '+${people.length - 4} · ${plural(people.length, 'person', 'people')}'
                              : plural(people.length, 'person', 'people'),
                          style: t.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit trip'),
              onTap: () {
                Navigator.pop(sheet);
                _menu(context, 'edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete trip'),
              onTap: () {
                Navigator.pop(sheet);
                _menu(context, 'delete');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = AppScope.of(context);
    return Card(
      key: const Key('upgrade_card'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Trip settled!', style: t.titleLarge)),
                IconButton(
                  key: const Key('dismiss_upgrade'),
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: state.dismissUpgradeCard,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Go Premium for unlimited trips, PDF and Excel exports, and no ads.',
                style: t.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('see_premium'),
              onPressed: () => openPremium(context, PaywallSource.upgradeCard),
              child: const Text('See Premium'),
            ),
          ],
        ),
      ),
    );
  }
}
