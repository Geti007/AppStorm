import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../widgets/ad_card.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'expense_form_screen.dart';

/// "Today", "Yesterday", "Mon, 12 Aug" (with the year when it differs).
String dayLabel(DateTime day, DateTime now) {
  final d = dateOnly(day);
  final today = dateOnly(now);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat(d.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y')
      .format(d);
}

/// Expenses grouped by day, newest first, with search (AC-14, AC-16).
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key, required this.trip, required this.onAdd});

  final Trip trip;
  final VoidCallback onAdd;

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trip = widget.trip;
    final all = state.expensesOf(trip.id);
    if (all.isEmpty) {
      return EmptyState(
        key: const Key('expenses_empty'),
        art: const Art(ArtKind.receipt),
        title: 'No expenses yet',
        body: 'Add the first thing someone paid for, like a hotel, dinner or taxi.',
        action: FilledButton(
          key: const Key('add_first_expense'),
          onPressed: widget.onAdd,
          child: const Text('Add expense'),
        ),
      );
    }
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all.where((e) => e.title.toLowerCase().contains(q)).toList();

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: TextField(
          key: const Key('expense_search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search expenses',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    key: const Key('clear_search'),
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
      ),
    ];
    if (shown.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No expenses match "${_search.text.trim()}"',
            key: const Key('no_search_results'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    DateTime? lastDay;
    var ads = 0;
    for (var i = 0; i < shown.length; i++) {
      final e = shown[i];
      final day = dateOnly(e.date);
      if (day != lastDay) {
        rows.add(SectionHeader(dayLabel(day, state.now)));
        lastDay = day;
      }
      rows.add(_ExpenseRow(trip: trip, expense: e));
      // A native ad after every 10th expense, at most 2 per list (AC-43).
      if ((i + 1) % 10 == 0 && ads < 2 && state.adsEnabled) {
        ads++;
        rows.add(
          NativeAdCard(
            key: Key('expenses_ad_$ads'),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
        );
      }
    }
    rows.add(const SizedBox(height: 96));
    return ListView(key: const Key('expense_list'), children: rows);
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.trip, required this.expense});

  final Trip trip;
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final e = expense;
    final category = state.category(e.categoryId);
    final differs = e.currency != trip.baseCurrency;
    return Dismissible(
      key: Key('expense_${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      // Deleting happens inside the confirmation, which also offers Undo.
      confirmDismiss: (_) => deleteExpenseWithUndo(context, e),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: CategoryBadge(category: category),
        title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Paid by ${trip.nameOf(e.paidBy)}'),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(e.amountMinor, e.currency),
                style: t.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (differs)
                Text(
                  '≈ ${formatMoney(baseAmountOf(e, trip.baseCurrency), trip.baseCurrency)}',
                  style: t.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ExpenseFormScreen(tripId: trip.id, expense: e),
          ),
        ),
      ),
    );
  }
}
