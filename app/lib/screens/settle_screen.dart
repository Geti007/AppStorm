import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/currencies.dart';
import '../data/models.dart';
import '../data/money.dart';
import '../widgets/common.dart';

Future<void> openSettle(
  BuildContext context,
  Trip trip, {
  Transfer? suggestion,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => SettleScreen(trip: trip, suggestion: suggestion),
  ),
);

/// Record a payment between two people (AC-24).
class SettleScreen extends StatefulWidget {
  const SettleScreen({super.key, required this.trip, this.suggestion});

  final Trip trip;
  final Transfer? suggestion;

  @override
  State<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends State<SettleScreen> {
  late String _from;
  late String _to;
  late final TextEditingController _amount;
  late DateTime _date;
  bool _saving = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final people = widget.trip.participants;
    final s = widget.suggestion;
    _from = s?.fromId ?? people.first.id;
    _to = s?.toId ?? people[1].id;
    _amount = TextEditingController(
      text: s == null
          ? ''
          : formatAmountInput(s.amountMinor, widget.trip.baseCurrency),
    )..addListener(() => setState(() {}));
    _date = dateOnly(AppScope.read(context).now);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _units => currencyFor(widget.trip.baseCurrency).minorUnits;

  ParsedAmount get _parsed => parseAmount(_amount.text, _units);

  String? get _amountError {
    if (_amount.text.trim().isEmpty) return null;
    return switch (_parsed.error) {
      null => null,
      AmountError.tooManyDecimals =>
        _units == 0
            ? 'Use whole numbers for ${widget.trip.baseCurrency}'
            : 'Use up to $_units decimals for ${widget.trip.baseCurrency}',
      _ => 'Enter an amount greater than 0',
    };
  }

  bool get _valid => _from != _to && _parsed.minor != null;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.savePayment(
        Payment(
          id: newId(),
          tripId: widget.trip.id,
          fromId: _from,
          toId: _to,
          amountMinor: _parsed.minor!,
          date: _date,
          createdAt: state.now,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Payment recorded')));
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, "Couldn't save the payment. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final people = widget.trip.participants;
    DropdownMenuItem<String> item(Participant p) =>
        DropdownMenuItem(value: p.id, child: Text(p.name));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('close_form'),
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Record payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            key: const Key('settle_from'),
            initialValue: _from,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'From'),
            items: [for (final p in people) item(p)],
            onChanged: (v) => setState(() => _from = v ?? _from),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('settle_to'),
            initialValue: _to,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'To',
              errorText: _from == _to ? 'Choose two different people' : null,
            ),
            items: [for (final p in people) item(p)],
            onChanged: (v) => setState(() => _to = v ?? _to),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('settle_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: t.titleLarge,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: widget.trip.baseCurrency,
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            key: const Key('settle_date'),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const Key('save_payment'),
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save payment'),
          ),
        ),
      ),
    );
  }
}
