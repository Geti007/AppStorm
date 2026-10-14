import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/units.dart';
import '../services/ads.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/banner_area.dart';
import '../widgets/glass_symbol.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.state,
    required this.ads,
    this.visible = true,
  });

  final AppState state;
  final AdsService ads;

  /// The banner is only created while this tab is on screen.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          key: const Key('history'),
          appBar: AppBar(title: const Text('History')),
          body: state.hasAnyDrinks ? _content(context) : const _Empty(),
        );
      },
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final days = state.lastSevenDays;
    final streak = state.streak;
    final unit = state.unit;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.water_drop,
                        size: 40,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              streak > 0
                                  ? '$streak-day streak'
                                  : 'No streak yet',
                              key: const Key('streak'),
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              streak > 0
                                  ? 'Days in a row you met your goal'
                                  : 'Meet your goal to start one',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: brand.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last 7 days', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _WeekChart(days: days, unit: unit),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final d in days.reversed) _DayRow(day: d, unit: unit),
            ],
          ),
        ),
        if (visible) BannerArea(ads: ads),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassSymbol(
              size: 96,
              color: BrandColors.of(context).muted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Your week will show up here once you log a drink.',
              key: const Key('history_empty'),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.unit});

  final List<DayTotal> days;
  final VolumeUnit unit;

  static const _barArea = 140.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandColors.of(context);
    final goal = days.last.goalMl;
    var top = goal;
    for (final d in days) {
      if (d.ml > top) top = d.ml;
      if (d.goalMl > top) top = d.goalMl;
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final goalY = _barArea * (goal / top);
    return Semantics(
      label: [
        for (final d in days)
          '${DateFormat('EEEE').format(d.day)} ${unit.format(d.ml)}'
              '${d.met ? ', goal met' : ''}',
      ].join('. '),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: _barArea + 24,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: goalY,
                  child: CustomPaint(
                    size: const Size(double.infinity, 2),
                    painter: _DashPainter(brand.muted),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: goalY + 4,
                  child: Text(
                    'Goal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: brand.muted,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (i == days.length - 1 && days[i].met)
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: scheme.secondary,
                                ),
                              TweenAnimationBuilder<double>(
                                key: Key('bar_$i'),
                                tween: Tween(
                                  begin: 0,
                                  end: _barArea * (days[i].ml / top),
                                ),
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                builder: (context, h, _) => Container(
                                  height: h,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == days.length - 1
                                        ? scheme.secondary
                                        : days[i].met
                                        ? scheme.primary
                                        : scheme.primary.withValues(
                                            alpha: 0.45,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('EEE').format(days[i].day),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: i == days.length - 1
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 1), Offset(x + 5, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.unit});

  final DayTotal day;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('day_${dayKey(day.day)}'),
      contentPadding: EdgeInsets.zero,
      title: Text(DateFormat('EEE, d MMM').format(day.day)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(unit.format(day.ml), style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: day.met
                ? Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.secondary,
                    semanticLabel: 'Goal met',
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
