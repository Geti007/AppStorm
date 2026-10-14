import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/units.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/progress_ring.dart';
import 'amount_dialogs.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});

  final AppState state;

  Future<void> _add(BuildContext context, double ml) async {
    final messenger = ScaffoldMessenger.of(context);
    final drink = await state.addDrink(ml);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('added_snackbar'),
          content: Text('Added ${state.unit.format(ml)}'),
          // Undo is for the drink just added. Current Flutter keeps a
          // snackbar with an action on screen forever unless told not to.
          persist: false,
          action: SnackBarAction(
            key: const Key('undo'),
            label: 'Undo',
            onPressed: () => state.removeDrink(drink.id),
          ),
        ),
      );
  }

  /// Time since the last delete, per app state.
  static final _sinceDelete = Expando<Stopwatch>();

  /// Deletes a drink. The rows below slide up at once, so a quick second
  /// tap would land on the next drink's delete button; ignore it.
  void _delete(int id) {
    final since = _sinceDelete[state];
    if (since != null && since.elapsed < kDoubleTapTimeout) return;
    _sinceDelete[state] = Stopwatch()..start();
    state.removeDrink(id);
  }

  Future<void> _custom(BuildContext context) async {
    final ml = await showCustomAmountDialog(context, state.unit);
    if (ml != null && context.mounted) await _add(context, ml);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final unit = state.unit;
        final total = state.todayTotal;
        final goal = state.todayGoal;
        final percent = (total / goal * 100).round();
        final met = state.todayGoalMet;
        final drinks = state.todayDrinks;
        // White on the light aqua is only 3.4:1; the spec asks for 4.5:1.
        final chipText = theme.brightness == Brightness.dark
            ? theme.colorScheme.onSecondary
            : theme.colorScheme.onSurface;
        return Scaffold(
          key: const Key('today'),
          appBar: AppBar(
            toolbarHeight: 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today'),
                Text(
                  DateFormat('EEEE, d MMMM').format(state.now),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: brand.muted,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Semantics(
                        key: const Key('progress'),
                        label:
                            '${unit.display(total)} of ${unit.display(goal)} '
                            '${unit.spoken}, $percent percent',
                        excludeSemantics: true,
                        child: ProgressRing(
                          fraction: goal <= 0 ? 0 : total / goal,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$percent%',
                                  key: const Key('percent'),
                                  style: theme.textTheme.displaySmall,
                                ),
                                Text(
                                  '${unit.display(total)} / '
                                  '${unit.display(goal)} ${unit.symbol}',
                                  key: const Key('total'),
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (met) ...[
                        const SizedBox(height: 16),
                        Chip(
                          key: const Key('goal_reached'),
                          avatar: Icon(Icons.check_circle, color: chipText),
                          label: const Text('Goal reached'),
                          backgroundColor: theme.colorScheme.secondary,
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            color: chipText,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Add a drink', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _QuickAdds(
                unit: unit,
                onAdd: (ml) => _add(context, ml),
                onCustom: () => _custom(context),
              ),
              const SizedBox(height: 24),
              Text("Today's drinks", style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (drinks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No drinks yet today. Tap a glass to start.',
                    key: const Key('today_empty'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: brand.muted,
                    ),
                  ),
                )
              else
                for (final d in drinks)
                  _DrinkTile(
                    drink: d,
                    unit: unit,
                    onDelete: () => _delete(d.id),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAdds extends StatelessWidget {
  const _QuickAdds({
    required this.unit,
    required this.onAdd,
    required this.onCustom,
  });

  final VolumeUnit unit;
  final ValueChanged<double> onAdd;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      for (final size in unit.quickAdds)
        _AddButton(
          key: Key('add_${unit.toMl(size).round()}'),
          label: '$size ${unit.symbol}',
          semantics: 'Add $size ${unit.symbol}',
          icon: Icons.local_drink_outlined,
          onPressed: () => onAdd(unit.toMl(size)),
        ),
      _AddButton(
        key: const Key('add_custom'),
        label: 'Custom',
        semantics: 'Add a custom amount',
        icon: Icons.edit_outlined,
        onPressed: onCustom,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (c.maxWidth < 328 || scale > 1.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in buttons)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: b),
            ],
          );
        }
        return Column(
          children: [
            for (var row = 0; row < 2; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == 0 ? 12 : 0),
                child: Row(
                  children: [
                    Expanded(child: buttons[row * 2]),
                    const SizedBox(width: 12),
                    Expanded(child: buttons[row * 2 + 1]),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    super.key,
    required this.label,
    required this.semantics,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String semantics;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _DrinkTile extends StatelessWidget {
  const _DrinkTile({
    required this.drink,
    required this.unit,
    required this.onDelete,
  });

  final Drink drink;
  final VolumeUnit unit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(drink.time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final amount = unit.format(drink.ml);
    return ListTile(
      key: Key('drink_${drink.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.local_drink,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: Text(amount),
      subtitle: Text(time),
      trailing: IconButton(
        key: Key('delete_${drink.id}'),
        tooltip: 'Delete $amount drink at $time',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
