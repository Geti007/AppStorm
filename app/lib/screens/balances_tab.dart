import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import 'settle_screen.dart';

/// Net balances, the fewest payments to settle up, and payment history
/// (AC-22 to AC-26).
class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final expenses = state.expensesOf(trip.id);
    final payments = state.paymentsOf(trip.id);
    if (expenses.isEmpty && payments.isEmpty) {
      return const EmptyState(
        key: Key('balances_empty'),
        art: Art(ArtKind.settled),
        title: 'Nothing to settle yet',
        body: 'Balances appear once you add an expense.',
      );
    }
    final balances = state.balancesOf(trip);
    final settled = isSettled(balances);
    final transfers = settled ? const <Transfer>[] : simplifyDebts(balances);
    final cur = trip.baseCurrency;

    return ListView(
      key: const Key('balances_list'),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const SectionHeader('Balances'),
        for (final p in trip.participants)
          _BalanceRow(name: p.name, amount: balances[p.id] ?? 0, currency: cur),
        if (settled)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _SettledCard(),
          )
        else ...[
          const SectionHeader('Suggested payments'),
          for (final tr in transfers)
            ListTile(
              key: Key(
                'transfer_${trip.nameOf(tr.fromId)}_${trip.nameOf(tr.toId)}',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                '${trip.nameOf(tr.fromId)} → ${trip.nameOf(tr.toId)}',
                style: t.bodyLarge,
              ),
              subtitle: Text(
                formatMoney(tr.amountMinor, cur),
                style: t.titleMedium,
              ),
              trailing: Semantics(
                label:
                    'Settle ${formatMoney(tr.amountMinor, cur)} from ${trip.nameOf(tr.fromId)} to ${trip.nameOf(tr.toId)}',
                button: true,
                excludeSemantics: true,
                child: FilledButton.tonal(
                  key: Key(
                    'settle_${trip.nameOf(tr.fromId)}_${trip.nameOf(tr.toId)}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: () => openSettle(context, trip, suggestion: tr),
                  child: const Text('Settle'),
                ),
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('record_payment'),
              onPressed: () => openSettle(context, trip),
              icon: const Icon(Icons.add),
              label: const Text('Record payment'),
            ),
          ),
        ),
        if (payments.isNotEmpty) ...[
          const SectionHeader('Payment history'),
          for (final p in payments)
            ListTile(
              key: Key('payment_${p.id}'),
              contentPadding: const EdgeInsets.only(left: 20, right: 8),
              title: Text(
                '${trip.nameOf(p.fromId)} paid ${trip.nameOf(p.toId)}',
              ),
              subtitle: Text(DateFormat('d MMM y').format(p.date)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatMoney(p.amountMinor, cur), style: t.titleMedium),
                  PopupMenuButton<String>(
                    key: Key('payment_menu_${p.id}'),
                    tooltip: 'Payment options',
                    onSelected: (_) async {
                      final ok = await confirm(
                        context,
                        title: 'Delete this payment?',
                        confirmLabel: 'Delete',
                      );
                      if (ok) await state.deletePayment(p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete payment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.name,
    required this.amount,
    required this.currency,
  });

  final String name;
  final int amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final String text;
    final Color color;
    if (amount.abs() <= 1) {
      text = 'Settled';
      color = scheme.onSurfaceVariant;
    } else if (amount > 0) {
      text = '${formatMoney(amount, currency, signed: true)} gets back';
      color = positiveColor(context);
    } else {
      text = '${formatMoney(amount, currency)} owes';
      color = scheme.error;
    }
    return ListTile(
      key: Key('balance_$name'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Avatar(name: name),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          text,
          textAlign: TextAlign.end,
          style: t.titleMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SettledCard extends StatelessWidget {
  const _SettledCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('all_settled'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Stack(
        children: [
          const Positioned.fill(child: Confetti()),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text('All settled up', style: t.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Everyone is even. Nice trip!',
                  style: t.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
