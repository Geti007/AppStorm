import 'package:flutter/material.dart';

import '../data/currencies.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/currency_picker.dart';
import 'premium_screen.dart';
import 'trips_screen.dart';

const int tripNameMax = 40;
const int personNameMax = 24;

/// Create or edit a trip (AC-2, AC-3, AC-4, AC-7).
class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.trip?.name ?? '',
  );
  final TextEditingController _person = TextEditingController();
  late String _currency;
  late int _cover;
  DateTimeRange? _dates;
  late List<Participant> _people;
  String? _personError;
  bool _saving = false;

  bool get _editing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _cover = t?.cover ?? 0;
    _people = List.of(t?.participants ?? const <Participant>[]);
    if (t?.startDate != null) {
      _dates = DateTimeRange(
        start: t!.startDate!,
        end: t.endDate ?? t.startDate!,
      );
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initCurrency) {
      _currency =
          widget.trip?.baseCurrency ?? AppScope.read(context).defaultCurrency;
      _initCurrency = true;
    }
  }

  bool _initCurrency = false;

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _people.length >= 2;

  Future<void> _addPerson() async {
    final name = _person.text.trim();
    if (name.isEmpty) {
      setState(() => _personError = 'Enter a name');
      return;
    }
    if (_people.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _personError = 'Name already in this trip');
      return;
    }
    final state = AppScope.read(context);
    if (!state.canAddParticipant(_people.length)) {
      await openPremium(context, PaywallSource.participantLimit);
      return;
    }
    setState(() {
      _people.add(Participant(id: newId(), name: name));
      _person.clear();
      _personError = null;
    });
  }

  void _removePerson(Participant p) {
    final trip = widget.trip;
    if (trip != null &&
        AppScope.read(context).participantInUse(trip.id, p.id)) {
      showMessage(
        context,
        "${p.name} is part of expenses or payments in this trip, so they can't be removed.",
      );
      return;
    }
    setState(() => _people.remove(p));
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: _dates,
    );
    if (r != null) setState(() => _dates = r);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final old = widget.trip;
    final trip = Trip(
      id: old?.id ?? newId(),
      name: _name.text.trim(),
      baseCurrency: old?.baseCurrency ?? _currency,
      cover: _cover,
      participants: _people,
      createdAt: old?.createdAt ?? state.now,
      startDate: _dates == null ? null : dateOnly(_dates!.start),
      endDate: _dates == null ? null : dateOnly(_dates!.end),
    );
    try {
      await state.saveTrip(trip);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, "Couldn't save the trip. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final currency = currencyFor(_currency);
    final datesText = _dates == null
        ? ''
        : formatTripDates(
            Trip(
              id: '',
              name: '',
              baseCurrency: '',
              cover: 0,
              participants: const [],
              createdAt: DateTime(2000),
              startDate: _dates!.start,
              endDate: _dates!.end,
            ),
          );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('close_form'),
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_editing ? 'Edit trip' : 'New trip'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('trip_name'),
              controller: _name,
              maxLength: tripNameMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Trip name',
                helperText: 'Up to 40 characters',
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('trip_dates'),
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDates,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Dates (optional)',
                  suffixIcon: _dates == null
                      ? const Icon(Icons.date_range_outlined)
                      : IconButton(
                          key: const Key('clear_dates'),
                          tooltip: 'Clear dates',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _dates = null),
                        ),
                ),
                child: Text(datesText, style: t.bodyLarge),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('trip_currency'),
              borderRadius: BorderRadius.circular(12),
              // Expenses and payments are stored against the trip currency,
              // so it can't change once the trip exists.
              onTap: _editing
                  ? null
                  : () async {
                      final c = await pickCurrency(context);
                      if (c != null) setState(() => _currency = c);
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Trip currency',
                  helperText: _editing
                      ? "The trip currency can't be changed after the trip is created."
                      : 'All totals are shown in this currency.',
                  helperMaxLines: 3,
                  suffixIcon: _editing
                      ? const Icon(Icons.lock_outline)
                      : const Icon(Icons.expand_more),
                ),
                child: Text(
                  '${currency.code} · ${currency.name}',
                  style: t.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Cover', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < tripCovers.length; i++)
                  Semantics(
                    label: '${tripCovers[i].$1} cover',
                    selected: i == _cover,
                    button: true,
                    child: InkWell(
                      key: Key('cover_$i'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _cover = i),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: coverGradient(i),
                          border: Border.all(
                            color: i == _cover
                                ? scheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: i == _cover
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Travel crew', style: t.titleMedium)),
                Text(
                  plural(_people.length, 'person', 'people'),
                  style: t.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in _people)
              ListTile(
                key: Key('person_${p.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: p.name),
                title: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  key: Key('remove_${p.name}'),
                  tooltip: 'Remove ${p.name}',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removePerson(p),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('person_name'),
                    controller: _person,
                    maxLength: personNameMax,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addPerson(),
                    onChanged: (_) {
                      if (_personError != null) {
                        setState(() => _personError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Add a person',
                      errorText: _personError,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    key: const Key('add_person'),
                    tooltip: 'Add person',
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                    icon: const Icon(Icons.person_add_alt),
                    onPressed: _addPerson,
                  ),
                ),
              ],
            ),
            if (_people.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Add at least 2 people to split costs.',
                  key: const Key('crew_hint'),
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const Key('save_trip'),
            onPressed: _valid && !_saving ? _save : null,
            child: Text(_editing ? 'Save changes' : 'Create trip'),
          ),
        ),
      ),
    );
  }
}
