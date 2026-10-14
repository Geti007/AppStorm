import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/units.dart';
import '../state/app_state.dart';
import '../widgets/glass_symbol.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  VolumeUnit _unit = VolumeUnit.ml;
  final _goal = TextEditingController(text: '2000');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  void _switchUnit(VolumeUnit unit) {
    if (unit == _unit) return;
    final value = parseWhole(_goal.text);
    final ml = value == null ? defaultGoalMl : _unit.toMl(value);
    setState(() {
      _unit = unit;
      _goal.text = unit.display(ml).toString();
      _error = null;
    });
  }

  Future<void> _start() async {
    if (_saving) return;
    final value = parseWhole(_goal.text);
    if (value == null || value < _unit.goalMin || value > _unit.goalMax) {
      setState(() => _error = _unit.goalRangeError);
      return;
    }
    _saving = true;
    await widget.state.completeOnboarding(
      goalMl: _unit.toMl(value),
      unit: _unit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('onboarding'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(child: GlassSymbol(size: 96)),
              const SizedBox(height: 24),
              Text(
                'Welcome to Glassful',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Set a daily water goal. You can change it any time in '
                'Settings.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Center(
                child: SegmentedButton<VolumeUnit>(
                  key: const Key('unit_toggle'),
                  segments: const [
                    ButtonSegment(value: VolumeUnit.ml, label: Text('ml')),
                    ButtonSegment(value: VolumeUnit.oz, label: Text('fl oz')),
                  ],
                  selected: {_unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _switchUnit(s.first),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('goal_field'),
                controller: _goal,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Daily goal',
                  suffixText: _unit.symbol,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('start_button'),
                onPressed: _start,
                child: const Text('Start tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
