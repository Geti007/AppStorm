import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/categories.dart';
import '../data/models.dart';
import '../data/money.dart';
import '../state/app_state.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'premium_screen.dart';

/// Spending by category (free) and the Premium sections (AC-28 to AC-30).
class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final expenses = state.expensesOf(trip.id);
    if (expenses.isEmpty) {
      return const EmptyState(
        key: Key('stats_empty'),
        art: Art(ArtKind.chart),
        title: 'No stats yet',
        body: 'Add expenses to see where the money goes.',
      );
    }
    final cur = trip.baseCurrency;
    final base = {for (final e in expenses) e.id: baseAmountOf(e, cur)};
    final total = base.values.fold(0, (a, b) => a + b);

    // Spending by category, largest first.
    final byCategory = <String, int>{};
    for (final e in expenses) {
      byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + base[e.id]!;
    }
    final slices = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final advanced = Column(
      children: [
        _DailyCard(trip: trip, expenses: expenses, base: base),
        const SizedBox(height: 16),
        _PeopleCard(trip: trip, expenses: expenses),
        const SizedBox(height: 16),
        _TopCard(trip: trip, expenses: expenses, base: base),
      ],
    );

    return ListView(
      key: const Key('stats_list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _CategoryCard(
          slices: [for (final s in slices) (state.category(s.key), s.value)],
          total: total,
          currency: cur,
        ),
        const SizedBox(height: 16),
        if (state.hasPassFeatures) advanced else _Locked(child: advanced),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.slices,
    required this.total,
    required this.currency,
  });

  final List<(CategoryInfo, int)> slices;
  final int total;
  final String currency;

  String _pct(int v) => total == 0 ? '0%' : '${(v * 100 / total).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = Theme.of(context).brightness;
    final summary = slices.map((s) => '${s.$1.name} ${_pct(s.$2)}').join(', ');
    return _StatCard(
      key: const Key('stats_by_category'),
      title: 'Spending by category',
      child: Column(
        children: [
          Semantics(
            label: 'Spending by category: $summary',
            excludeSemantics: true,
            child: SizedBox(
              height: 160,
              width: 160,
              child: CustomPaint(
                painter: _DonutPainter([
                  for (final s in slices) (s.$1.color(b), s.$2),
                ], Theme.of(context).colorScheme.surface),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: FittedBox(
                      child: Text(
                        formatMoney(total, currency),
                        style: t.titleMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CategoryBadge(category: s.$1, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.$1.name, style: t.bodyLarge)),
                  const SizedBox(width: 12),
                  // Amount over percentage, so large text never overflows.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(s.$2, currency),
                        textAlign: TextAlign.end,
                        style: t.titleMedium,
                      ),
                      Text(
                        _pct(s.$2),
                        textAlign: TextAlign.end,
                        style: t.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.gap);

  final List<(Color, int)> parts;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold(0, (a, p) => a + p.$2);
    final rect = Offset.zero & size;
    const stroke = 26.0;
    final arcRect = rect.deflate(stroke / 2);
    var start = -math.pi / 2;
    for (final p in parts) {
      if (total == 0 || p.$2 <= 0) continue;
      final sweep = p.$2 / total * math.pi * 2;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..color = p.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      if (parts.length > 1) {
        canvas.drawArc(
          arcRect,
          start + sweep - 0.01,
          0.02,
          false,
          Paint()
            ..color = gap
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke + 1,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.trip,
    required this.expenses,
    required this.base,
  });

  final Trip trip;
  final List<Expense> expenses;
  final Map<String, int> base;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final byDay = <DateTime, int>{};
    for (final e in expenses) {
      final d = dateOnly(e.date);
      byDay[d] = (byDay[d] ?? 0) + base[e.id]!;
    }
    final days = byDay.keys.toList()..sort();
    final max = byDay.values.fold(1, math.max);
    final summary = days
        .map(
          (d) =>
              '${DateFormat('d MMM').format(d)} ${formatMoney(byDay[d]!, trip.baseCurrency)}',
        )
        .join(', ');
    return _StatCard(
      key: const Key('stats_daily'),
      title: 'Daily spending',
      child: Semantics(
        label: 'Daily spending: $summary',
        excludeSemantics: true,
        child: SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final d in days)
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: byDay[d]! / max,
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d/M').format(d),
                        style: t.labelSmall,
                        textScaler: TextScaler.noScaling,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.trip, required this.expenses});

  final Trip trip;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cur = trip.baseCurrency;
    final paid = <String, int>{};
    final share = <String, int>{};
    for (final e in expenses) {
      paid[e.paidBy] = (paid[e.paidBy] ?? 0) + baseAmountOf(e, cur);
      baseSharesOf(e, cur).forEach((id, v) => share[id] = (share[id] ?? 0) + v);
    }
    final max = [...paid.values, ...share.values, 1].reduce(math.max);
    Widget bar(int v, Color c) => LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 10,
          width: math.max(4, box.maxWidth * v / max),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
    return _StatCard(
      key: const Key('stats_people'),
      title: 'Who paid and who spent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            children: [
              _Legend(color: scheme.primary, label: 'Paid'),
              _Legend(color: scheme.secondary, label: 'Share'),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in trip.participants)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                label:
                    '${p.name}: paid ${formatMoney(paid[p.id] ?? 0, cur)}, share ${formatMoney(share[p.id] ?? 0, cur)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: t.bodyLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: bar(paid[p.id] ?? 0, scheme.primary)),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(paid[p.id] ?? 0, cur),
                          style: t.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: bar(share[p.id] ?? 0, scheme.secondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(share[p.id] ?? 0, cur),
                          style: t.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.trip,
    required this.expenses,
    required this.base,
  });

  final Trip trip;
  final List<Expense> expenses;
  final Map<String, int> base;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final top = List.of(expenses)
      ..sort((a, b) => base[b.id]!.compareTo(base[a.id]!));
    return _StatCard(
      key: const Key('stats_top'),
      title: 'Top 5 expenses',
      child: Column(
        children: [
          for (final e in top.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CategoryBadge(
                    category: state.category(e.categoryId),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.title,
                      style: t.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatMoney(base[e.id]!, trip.baseCurrency),
                    style: t.titleMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The Premium sections, blurred under one unlock card (AC-29).
class _Locked extends StatelessWidget {
  const _Locked({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(
      key: const Key('stats_locked'),
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: child,
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, -0.6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'See where the money went',
                        style: t.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daily spending, who paid what, and your biggest expenses.',
                        style: t.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('unlock_stats'),
                        onPressed: () =>
                            openPremium(context, PaywallSource.advancedStats),
                        child: const Text('Unlock with Premium'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
