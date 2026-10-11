import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/categories.dart';
import '../data/currencies.dart';
import '../data/models.dart';
import '../data/money.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/currency_picker.dart';
import 'premium_screen.dart';

enum _RateStatus { none, loading, ready, missing, failed }

/// Add or edit an expense (AC-9 to AC-21). It never shows an upgrade prompt
/// unless the user taps the locked historical-rate action (AC-41).
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.tripId, this.expense});

  final String tripId;
  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _percent = {};
  final Map<String, TextEditingController> _custom = {};

  late Trip _trip;
  late String _currency;
  double? _rateValue;
  String? _rateDate;
  bool _editingRate = false;
  _RateStatus _rateStatus = _RateStatus.none;

  /// Which request "Try again" repeats after a failed rate fetch.
  bool _lastFetchHistorical = false;
  late String _category;
  late DateTime _date;
  late String _paidBy;
  SplitMethod _method = SplitMethod.equal;
  final Set<String> _selected = {};
  bool _saving = false;
  bool _ready = false;

  bool get _editing => widget.expense != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final state = AppScope.read(context);
    _trip = state.trip(widget.tripId)!;
    for (final p in _trip.participants) {
      _percent[p.id] = TextEditingController();
      _custom[p.id] = TextEditingController();
    }
    final e = widget.expense;
    if (e == null) {
      _currency = _trip.baseCurrency;
      _category = builtInCategories.first.id;
      _date = dateOnly(state.now);
      _paidBy = _trip.participants.first.id;
      _selected.addAll(_trip.participants.map((p) => p.id));
    } else {
      _title.text = e.title;
      _amount.text = formatAmountInput(e.amountMinor, e.currency);
      _currency = e.currency;
      _rateValue = e.rate;
      _rateDate = e.rateDate;
      _rateStatus = _RateStatus.ready;
      _rate.text = _formatRate(e.rate);
      _category = e.categoryId;
      _date = e.date;
      _paidBy = e.paidBy;
      _method = e.method;
      _selected.addAll(e.splitAmong);
      for (final id in e.splitAmong) {
        final v = e.splitInputs[id];
        if (v == null) continue;
        if (e.method == SplitMethod.percent) {
          _percent[id]?.text = formatPercent(v).replaceAll('%', '');
        } else if (e.method == SplitMethod.custom) {
          _custom[id]?.text = formatAmountInput(v, e.currency);
        }
      }
      _note.text = e.note;
    }
    for (final c in [
      _title,
      _amount,
      _rate,
      ..._percent.values,
      ..._custom.values,
    ]) {
      c.addListener(_changed);
    }
    if (e == null && _currency != _trip.baseCurrency) _loadRate();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _title,
      _amount,
      _rate,
      _note,
      ..._percent.values,
      ..._custom.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatRate(double r) {
    final s = r.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Currency get _cur => currencyFor(_currency);

  // ------------------------------------------------------------- rates

  void _setRate(double rate, String date) {
    _rateValue = rate;
    _rateDate = date;
    _rate.text = _formatRate(rate);
    _rateStatus = _RateStatus.ready;
  }

  /// Fills in the latest rate: the cached one at once, then a fresh one
  /// when the phone is online (AC-18, AC-19).
  Future<void> _loadRate() async {
    final state = AppScope.read(context);
    final from = _currency;
    final to = _trip.baseCurrency;
    if (from == to) {
      setState(() => _rateStatus = _RateStatus.none);
      return;
    }
    _editingRate = false;
    final cached = state.latestRates?.rate(from, to);
    setState(() {
      if (cached != null) {
        _setRate(cached, state.latestRates!.date);
      } else {
        _rateValue = null;
        _rateDate = null;
        _rate.clear();
        _rateStatus = _RateStatus.loading;
      }
    });
    if (!autoRateCodes.contains(from) || !autoRateCodes.contains(to)) {
      if (cached == null) setState(() => _rateStatus = _RateStatus.missing);
      return;
    }
    final fresh = await state.refreshRates();
    if (!mounted || _currency != from || _editingRate) return;
    final r = fresh?.rate(from, to);
    setState(() {
      if (r != null) {
        _setRate(r, fresh!.date);
      } else if (cached == null) {
        // A published currency, but the request failed (AC-19 offers retry).
        _lastFetchHistorical = false;
        _rateStatus = _RateStatus.failed;
      }
    });
  }

  /// Premium or Premium Pass: the rate published on the expense date (AC-21).
  Future<void> _historicalRate() async {
    final state = AppScope.read(context);
    if (!state.hasPassFeatures) {
      await openPremium(context, PaywallSource.historicalRate);
      return;
    }
    final from = _currency;
    setState(() => _rateStatus = _RateStatus.loading);
    final table = await state.services.rates.onDate(_date);
    if (!mounted || _currency != from) return;
    final r = table?.rate(from, _trip.baseCurrency);
    setState(() {
      if (r != null) {
        _editingRate = false;
        _setRate(r, table!.date);
      } else {
        _lastFetchHistorical = true;
        _rateStatus = _rateValue != null
            ? _RateStatus.ready
            : _RateStatus.failed;
        showMessage(
          context,
          "Couldn't get the rate. Check your connection or enter it yourself.",
        );
      }
    });
  }

  // ------------------------------------------------------------- validation

  ParsedAmount get _parsedAmount => parseAmount(_amount.text, _cur.minorUnits);

  String? get _amountError {
    if (_amount.text.trim().isEmpty) return null;
    final p = _parsedAmount;
    return switch (p.error) {
      null => null,
      AmountError.tooManyDecimals =>
        _cur.minorUnits == 0
            ? 'Use whole numbers for ${_cur.code}'
            : 'Use up to ${_cur.minorUnits} decimals for ${_cur.code}',
      _ => 'Enter an amount greater than 0',
    };
  }

  bool get _needsRate => _currency != _trip.baseCurrency;

  double? get _effectiveRate {
    if (!_needsRate) return 1;
    if (_editingRate ||
        _rateStatus == _RateStatus.missing ||
        _rateStatus == _RateStatus.failed) {
      return parseRate(_rate.text);
    }
    return _rateValue;
  }

  List<String> get _ordered => [for (final p in _trip.participants) p.id];

  Map<String, int> get _percentInputs => {
    for (final id in _ordered)
      if ((parsePercent(_percent[id]!.text) ?? 0) > 0)
        id: parsePercent(_percent[id]!.text)!,
  };

  bool get _percentValid =>
      _ordered.every((id) => parsePercent(_percent[id]!.text) != null);

  Map<String, int> get _customInputs {
    final m = <String, int>{};
    for (final id in _ordered) {
      final text = _custom[id]!.text.trim();
      if (text.isEmpty) continue;
      final p = parseAmount(text, _cur.minorUnits);
      if (p.minor != null) m[id] = p.minor!;
    }
    return m;
  }

  bool get _customValid => _ordered.every((id) {
    final text = _custom[id]!.text.trim();
    if (text.isEmpty) return true;
    final p = parseAmount(text, _cur.minorUnits);
    return p.minor != null || text.replaceAll(RegExp('[0.,]'), '').isEmpty;
  });

  int get _percentRemaining =>
      10000 - _percentInputs.values.fold(0, (a, b) => a + b);

  int? get _customRemaining {
    final amount = _parsedAmount.minor;
    if (amount == null) return null;
    return amount - _customInputs.values.fold(0, (a, b) => a + b);
  }

  bool get _splitValid => switch (_method) {
    SplitMethod.equal => _selected.isNotEmpty,
    SplitMethod.percent =>
      _percentValid && _percentInputs.isNotEmpty && _percentRemaining == 0,
    SplitMethod.custom =>
      _customValid && _customInputs.isNotEmpty && _customRemaining == 0,
  };

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _parsedAmount.minor != null &&
      _effectiveRate != null &&
      _effectiveRate! > 0 &&
      _splitValid;

  Expense? _build() {
    final amount = _parsedAmount.minor;
    final rate = _effectiveRate;
    if (amount == null || rate == null) return null;
    final List<String> among;
    final Map<String, int> inputs;
    switch (_method) {
      case SplitMethod.equal:
        among = _ordered.where(_selected.contains).toList();
        inputs = const {};
      case SplitMethod.percent:
        inputs = _percentInputs;
        among = _ordered.where(inputs.containsKey).toList();
      case SplitMethod.custom:
        inputs = _customInputs;
        among = _ordered.where(inputs.containsKey).toList();
    }
    final state = AppScope.read(context);
    final old = widget.expense;
    return Expense(
      id: old?.id ?? newId(),
      tripId: _trip.id,
      title: _title.text.trim(),
      amountMinor: amount,
      currency: _currency,
      rate: _needsRate ? rate : 1,
      rateDate: _needsRate ? (_editingRate ? null : _rateDate) : null,
      categoryId: _category,
      date: _date,
      paidBy: _paidBy,
      method: _method,
      splitAmong: among,
      splitInputs: inputs,
      createdAt: old?.createdAt ?? state.now,
      note: _note.text.trim(),
    );
  }

  Future<void> _save() async {
    final e = _build();
    if (e == null || !_valid || _saving) return;
    setState(() => _saving = true);
    try {
      await AppScope.read(context).saveExpense(e);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, "Couldn't save the expense. Please try again.");
      }
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    if (await deleteExpenseWithUndo(context, widget.expense!)) {
      navigator.pop();
    }
  }

  // ------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('close_form'),
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_editing ? 'Edit expense' : 'Add expense'),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('delete_expense'),
              tooltip: 'Delete expense',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    key: const Key('expense_currency'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 60),
                    ),
                    onPressed: () async {
                      final c = await pickCurrency(context);
                      if (c != null && c != _currency) {
                        setState(() => _currency = c);
                        _loadRate();
                      }
                    },
                    child: Text(_currency, style: t.titleMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('expense_amount'),
                    controller: _amount,
                    style: t.displaySmall,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: _cur.minorUnits == 0 ? '0' : '0.00',
                      errorText: _amountError,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
            if (_needsRate) _rateBlock(t, scheme),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense_title'),
              controller: _title,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What was it for?'),
            ),
            const SizedBox(height: 8),
            Text('Category', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in state.allCategories)
                  ChoiceChip(
                    key: Key('category_${c.id}'),
                    avatar: Icon(
                      c.icon,
                      size: 18,
                      color: c.color(Theme.of(context).brightness),
                    ),
                    label: Text(c.name),
                    selected: _category == c.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('expense_date'),
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _date = dateOnly(d));
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  DateFormat('EEE, d MMM y').format(_date),
                  style: t.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Paid by', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _trip.participants)
                  ChoiceChip(
                    key: Key('payer_${p.name}'),
                    avatar: Avatar(name: p.name, size: 24),
                    label: Text(p.name),
                    selected: _paidBy == p.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _paidBy = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Split', style: t.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SplitMethod>(
              key: const Key('split_method'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: SplitMethod.equal,
                  label: Text('Equally', key: Key('split_equal')),
                ),
                ButtonSegment(
                  value: SplitMethod.percent,
                  label: Text('By %', key: Key('split_percent')),
                ),
                ButtonSegment(
                  value: SplitMethod.custom,
                  label: Text('By amount', key: Key('split_custom')),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 8),
            ..._splitRows(t, scheme),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense_note'),
              controller: _note,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const Key('save_expense'),
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save expense'),
          ),
        ),
      ),
    );
  }

  Widget _rateBlock(TextTheme t, ColorScheme scheme) {
    final base = _trip.baseCurrency;
    final manual =
        _editingRate ||
        _rateStatus == _RateStatus.missing ||
        _rateStatus == _RateStatus.failed;
    final children = <Widget>[];
    if (_rateStatus == _RateStatus.loading) {
      children.add(
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text("Getting today's rate…", style: t.bodyMedium)),
          ],
        ),
      );
    } else if (!manual && _rateValue != null) {
      final date = _rateDate == null
          ? ''
          : ' · rate from ${DateFormat('d MMM y').format(DateTime.parse(_rateDate!))}';
      children.add(
        Row(
          children: [
            Expanded(
              child: Text(
                '1 $_currency = ${_formatRate(_rateValue!)} $base$date',
                key: const Key('rate_line'),
                style: t.bodyMedium,
              ),
            ),
            TextButton(
              key: const Key('edit_rate'),
              onPressed: () => setState(() => _editingRate = true),
              child: const Text('Edit'),
            ),
          ],
        ),
      );
    }
    if (_rateStatus == _RateStatus.missing) {
      children.add(
        Text(
          'No rate available offline. Enter the rate.',
          key: const Key('rate_missing'),
          style: t.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    if (_rateStatus == _RateStatus.failed) {
      children.add(
        Row(
          children: [
            Expanded(
              child: Text(
                "Couldn't get the rate. Check your connection or enter it yourself.",
                style: t.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
            TextButton(
              key: const Key('retry_rate'),
              onPressed: _lastFetchHistorical ? _historicalRate : _loadRate,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (manual) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            key: const Key('rate_field'),
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Exchange rate',
              helperText: '1 $_currency = ? $base',
            ),
          ),
        ),
      );
    }
    final premium = AppScope.of(context).hasPassFeatures;
    children.add(
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('historical_rate'),
          onPressed: _historicalRate,
          icon: Icon(premium ? Icons.history : Icons.lock_outline, size: 18),
          label: const Text('Use the rate on the expense date'),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _splitRows(TextTheme t, ColorScheme scheme) {
    final amount = _parsedAmount.minor ?? 0;
    final rows = <Widget>[];
    switch (_method) {
      case SplitMethod.equal:
        final among = _ordered.where(_selected.contains).toList();
        final shares = splitEqual(amount, among.length);
        final allSelected = _selected.length == _ordered.length;
        rows.add(
          CheckboxListTile(
            key: const Key('select_all'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Select all'),
            value: allSelected,
            onChanged: (v) => setState(() {
              _selected.clear();
              if (v ?? false) _selected.addAll(_ordered);
            }),
          ),
        );
        for (final p in _trip.participants) {
          final i = among.indexOf(p.id);
          rows.add(
            CheckboxListTile(
              key: Key('share_${p.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.name),
              secondary: Text(
                i >= 0 ? formatMoney(shares[i], _currency) : '',
                style: t.titleMedium,
              ),
              value: _selected.contains(p.id),
              onChanged: (v) => setState(() {
                if (v ?? false) {
                  _selected.add(p.id);
                } else {
                  _selected.remove(p.id);
                }
              }),
            ),
          );
        }
      case SplitMethod.percent:
        final shares = splitPercent(amount, [
          for (final id in _ordered) parsePercent(_percent[id]!.text) ?? 0,
        ]);
        for (final (i, p) in _trip.participants.indexed) {
          rows.add(
            _inputRow(
              p,
              _percent[p.id]!,
              'percent',
              suffix: '%',
              trailing: formatMoney(shares[i], _currency),
              t: t,
            ),
          );
        }
        final rest = _percentRemaining;
        rows.add(
          _remaining('Remaining: ${formatPercent(rest)}', rest == 0, t, scheme),
        );
      case SplitMethod.custom:
        for (final p in _trip.participants) {
          rows.add(_inputRow(p, _custom[p.id]!, 'custom', t: t));
        }
        final rest = _customRemaining;
        if (rest != null) {
          rows.add(
            _remaining(
              'Remaining: ${formatMoney(rest, _currency)}',
              rest == 0,
              t,
              scheme,
            ),
          );
        }
    }
    return rows;
  }

  Widget _inputRow(
    Participant p,
    TextEditingController c,
    String kind, {
    String? suffix,
    String? trailing,
    required TextTheme t,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Avatar(name: p.name),
        const SizedBox(width: 12),
        Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            key: Key('${kind}_${p.name}'),
            controller: c,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: suffix,
              isDense: true,
              hintText: '0',
            ),
          ),
        ),
        if (trailing != null)
          SizedBox(
            width: 88,
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              style: t.bodyMedium,
            ),
          ),
      ],
    ),
  );

  Widget _remaining(String text, bool ok, TextTheme t, ColorScheme scheme) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          key: const Key('split_remaining'),
          style: t.titleMedium?.copyWith(color: ok ? null : scheme.error),
        ),
      );
}
