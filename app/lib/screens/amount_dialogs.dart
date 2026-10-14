import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/units.dart';

/// The custom amount dialog. Returns the amount in millilitres, or null.
Future<double?> showCustomAmountDialog(BuildContext context, VolumeUnit unit) {
  return showDialog<double>(
    context: context,
    builder: (_) => _CustomAmountDialog(unit: unit),
  );
}

class _CustomAmountDialog extends StatefulWidget {
  const _CustomAmountDialog({required this.unit});

  final VolumeUnit unit;

  @override
  State<_CustomAmountDialog> createState() => _CustomAmountDialogState();
}

class _CustomAmountDialogState extends State<_CustomAmountDialog> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _valid {
    final v = parseWhole(_amount.text);
    if (v == null || v < widget.unit.customMin || v > widget.unit.customMax) {
      return null;
    }
    return v;
  }

  void _add() {
    final v = _valid;
    if (v != null) Navigator.of(context).pop(widget.unit.toMl(v));
  }

  @override
  Widget build(BuildContext context) {
    final valid = _valid != null;
    return AlertDialog(
      key: const Key('custom_dialog'),
      title: const Text('Custom amount'),
      content: SingleChildScrollView(
        child: TextField(
          key: const Key('custom_field'),
          controller: _amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Amount',
            suffixText: widget.unit.symbol,
            helperText: widget.unit.customRangeHelp,
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _add(),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('custom_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('custom_add'),
          onPressed: valid ? _add : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// The Settings goal dialog. Returns the new goal in millilitres, or null.
Future<double?> showGoalDialog(
  BuildContext context,
  VolumeUnit unit,
  double currentMl,
) {
  return showDialog<double>(
    context: context,
    builder: (_) => _GoalDialog(unit: unit, currentMl: currentMl),
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.unit, required this.currentMl});

  final VolumeUnit unit;
  final double currentMl;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _goal = TextEditingController(
    text: widget.unit.display(widget.currentMl).toString(),
  );
  String? _error;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  void _save() {
    final u = widget.unit;
    final v = parseWhole(_goal.text);
    if (v == null || v < u.goalMin || v > u.goalMax) {
      setState(() => _error = u.goalRangeError);
      return;
    }
    // Keep the exact stored goal when the shown value did not change.
    final unchanged = v == u.display(widget.currentMl);
    Navigator.of(context).pop(unchanged ? widget.currentMl : u.toMl(v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('goal_dialog'),
      title: const Text('Daily goal'),
      content: SingleChildScrollView(
        child: TextField(
          key: const Key('goal_dialog_field'),
          controller: _goal,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Daily goal',
            suffixText: widget.unit.symbol,
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('goal_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('goal_save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
