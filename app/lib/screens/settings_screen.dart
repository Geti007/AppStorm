import 'package:flutter/material.dart';

import '../data/units.dart';
import '../services/ads.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'amount_dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state, required this.ads});

  final AppState state;
  final AdsService ads;

  Future<void> _editGoal(BuildContext context) async {
    final ml = await showGoalDialog(context, state.unit, state.todayGoal);
    if (ml != null) await state.setGoal(ml);
  }

  Future<void> _reset(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('reset_dialog'),
        title: const Text('Reset all data?'),
        content: const Text(
          "This deletes every drink and your goal. It can't be undone.",
        ),
        actions: [
          TextButton(
            key: const Key('reset_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('reset_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await state.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          key: const Key('settings'),
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                key: const Key('settings_goal'),
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily goal'),
                subtitle: Text(state.unit.format(state.todayGoal)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editGoal(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Units', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<VolumeUnit>(
                      key: const Key('settings_unit'),
                      segments: const [
                        ButtonSegment(value: VolumeUnit.ml, label: Text('ml')),
                        ButtonSegment(
                          value: VolumeUnit.oz,
                          label: Text('fl oz'),
                        ),
                      ],
                      selected: {state.unit},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => state.setUnit(s.first),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ads.privacyOptionsRequired,
                builder: (context, required, _) {
                  if (!required) return const SizedBox.shrink();
                  return ListTile(
                    key: const Key('privacy_options'),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy options'),
                    onTap: ads.showPrivacyOptions,
                  );
                },
              ),
              const Divider(height: 24),
              ListTile(
                key: const Key('reset_all'),
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Reset all data',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => _reset(context),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Glassful 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: brand.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
