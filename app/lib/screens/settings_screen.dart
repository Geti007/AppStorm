import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/backup.dart';
import '../data/currencies.dart';
import '../services/billing.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/currency_picker.dart';
import 'categories_screen.dart';
import 'premium_screen.dart';
import 'text_page.dart';

const String appVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backingUp = false;
  bool _restoringPurchases = false;

  Future<void> _restorePurchases(AppState state) async {
    setState(() => _restoringPurchases = true);
    final billing = state.services.billing;
    final result = billing.outcomes
        .firstWhere(
          (o) =>
              o == PurchaseOutcome.restored ||
              o == PurchaseOutcome.nothingToRestore ||
              o == PurchaseOutcome.failed,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => PurchaseOutcome.failed,
        );
    try {
      await billing.restore();
    } on Object {
      // Reported through the outcome below.
    }
    final outcome = await result.catchError((_) => PurchaseOutcome.failed);
    if (!mounted) return;
    setState(() => _restoringPurchases = false);
    switch (outcome) {
      case PurchaseOutcome.restored:
        await state.setPremium(true);
        if (mounted) showMessage(context, 'Welcome to Premium!');
      case PurchaseOutcome.nothingToRestore:
        showMessage(context, 'No previous purchase found.');
      default:
        showMessage(context, "Couldn't restore purchases. Please try again.");
    }
  }

  Future<void> _backup(AppState state) async {
    if (!state.isPremium) {
      await openPremium(context, PaywallSource.backup);
      return;
    }
    setState(() => _backingUp = true);
    try {
      final backup = state.makeBackup();
      final name =
          'trippi-backup-${DateFormat('yyyy-MM-dd').format(backup.savedAt)}.json';
      await state.services.files.shareFile(
        Uint8List.fromList(utf8.encode(backup.encode())),
        name,
        'application/json',
      );
    } on Object {
      if (mounted) {
        showMessage(context, "Couldn't create the backup. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore(AppState state) async {
    if (!state.isPremium) {
      await openPremium(context, PaywallSource.backup);
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await state.services.files.pickFile();
    } on Object {
      bytes = null;
    }
    if (bytes == null || !mounted) return;
    Backup backup;
    try {
      backup = Backup.decode(utf8.decode(bytes));
    } on Object {
      await inform(context, "This isn't a Trippi backup");
      return;
    }
    if (!mounted) return;
    final trips = plural(backup.tripCount, 'trip', 'trips');
    final expenses = plural(backup.expenseCount, 'expense', 'expenses');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This file has $trips and $expenses, saved ${DateFormat('d MMM y').format(backup.savedAt)}. It will replace everything on this phone.',
        ),
        actions: [
          TextButton(
            key: const Key('dialog_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('dialog_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await state.restoreBackup(backup);
      if (mounted) showMessage(context, 'Backup restored');
    } on Object {
      if (mounted) {
        await inform(
          context,
          "Couldn't restore this backup. Nothing was changed.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locked = !state.isPremium;
    Widget lock() => Icon(Icons.lock_outline, color: scheme.onSurfaceVariant);
    final ads = state.services.ads;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        key: const Key('settings_list'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: t.bodyLarge),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  key: const Key('theme_mode'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System', key: Key('theme_system')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light', key: Key('theme_light')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark', key: Key('theme_dark')),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (s) => state.setThemeMode(s.first),
                ),
                const SizedBox(height: 20),
                Text('Accent theme', style: t.bodyLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final a in AccentTheme.values)
                      _AccentSwatch(
                        accent: a,
                        selected: state.accent == a,
                        locked:
                            a != AccentTheme.lagoon && !state.hasPassFeatures,
                        onTap: () {
                          if (a != AccentTheme.lagoon &&
                              !state.hasPassFeatures) {
                            openPremium(context, PaywallSource.themes);
                          } else {
                            state.setAccent(a);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader('Trips'),
          ListTile(
            key: const Key('default_currency'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Default currency'),
            subtitle: Text(
              '${state.defaultCurrency} · ${currencyFor(state.defaultCurrency).name}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final c = await pickCurrency(context);
              if (c != null) await state.setDefaultCurrency(c);
            },
          ),
          ListTile(
            key: const Key('open_categories'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Categories'),
            trailing: locked ? lock() : const Icon(Icons.chevron_right),
            onTap: () => locked
                ? openPremium(context, PaywallSource.categories)
                : Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoriesScreen(),
                    ),
                  ),
          ),
          const SectionHeader('Your data'),
          ListTile(
            key: const Key('backup'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            enabled: !_backingUp,
            title: const Text('Back up'),
            subtitle: Text(
              _backingUp ? 'Preparing backup…' : 'Save all trips to a file',
            ),
            trailing: _backingUp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : locked
                ? lock()
                : null,
            onTap: () => _backup(state),
          ),
          ListTile(
            key: const Key('restore'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Restore'),
            subtitle: const Text('Replace data from a backup file'),
            trailing: locked ? lock() : null,
            onTap: () => _restore(state),
          ),
          const SectionHeader('Premium'),
          if (state.isPremium) ...[
            const ListTile(
              key: Key('premium_active_row'),
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('Premium active'),
            ),
            ListTile(
              key: const Key('manage_subscription'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: const Text('Manage subscription'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () =>
                  state.services.openUrl(state.services.billing.manageUrl),
            ),
          ] else ...[
            ListTile(
              key: const Key('get_premium'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Get Premium'),
              subtitle: state.passActive
                  ? Text(passActiveText(state.passEnd!))
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPremium(context, PaywallSource.settings),
            ),
          ],
          ListTile(
            key: const Key('settings_restore_purchases'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Restore purchases'),
            onTap: _restoringPurchases ? null : () => _restorePurchases(state),
          ),
          const SectionHeader('Privacy'),
          if (state.adsEnabled)
            ValueListenableBuilder<bool>(
              valueListenable: ads.privacyOptionsRequired,
              builder: (context, required, _) => required
                  ? ListTile(
                      key: const Key('privacy_options'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      title: const Text('Privacy options'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: ads.showPrivacyOptions,
                    )
                  : const SizedBox.shrink(),
            ),
          ListTile(
            key: const Key('settings_privacy'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTextPage(context, TextPageKind.privacy),
          ),
          ListTile(
            key: const Key('settings_terms'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Terms of use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTextPage(context, TextPageKind.terms),
          ),
          const SectionHeader('About'),
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20),
            title: Text('Version $appVersion'),
            subtitle: Text('Made for travel crews'),
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final AccentTheme accent;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = accentName(accent);
    return Semantics(
      label: locked ? '$name theme, Premium' : '$name theme',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: Key('accent_${accent.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentSwatch(accent),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline
                      : selected
                      ? Icons.check
                      : null,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
