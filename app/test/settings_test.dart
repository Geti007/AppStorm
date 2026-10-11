import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/backup.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/premium_screen.dart';
import 'package:trippi/services/billing.dart';
import 'package:trippi/state/app_state.dart';

import 'support/fakes.dart';

Future<Harness> openSettings(
  WidgetTester tester, {
  bool premium = false,
  Snapshot initial = const Snapshot(),
  bool isIOS = false,
}) async {
  usePhone(tester);
  final h = Harness(premium: premium, initial: initial, isIOS: isIOS);
  await h.pump(tester);
  await tester.tap(find.byKey(const Key('open_settings')));
  await tester.pumpAndSettle();
  return h;
}

Future<void> scrollTo(WidgetTester tester, Key key) async {
  await tester.dragUntilVisible(
    find.byKey(key),
    find.byKey(const Key('settings_list')),
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

MaterialApp app(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

void main() {
  testWidgets('AC-37 Manage subscription opens the store subscription page', (
    tester,
  ) async {
    final h = await openSettings(tester, premium: true);
    await scrollTo(tester, const Key('manage_subscription'));
    expect(find.text('Premium active'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage_subscription')));
    await tester.pumpAndSettle();
    expect(h.openedUrls, [h.billing.manageUrl]);
  });

  testWidgets(
    'AC-37 free users see Get Premium instead of Manage subscription',
    (tester) async {
      await openSettings(tester);
      await scrollTo(tester, const Key('get_premium'));
      expect(find.byKey(const Key('manage_subscription')), findsNothing);
      await tester.tap(find.byKey(const Key('get_premium')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    },
  );

  testWidgets('Restore purchases in Settings reports what the store found', (
    tester,
  ) async {
    final h = await openSettings(tester);
    await scrollTo(tester, const Key('settings_restore_purchases'));
    await tester.tap(find.byKey(const Key('settings_restore_purchases')));
    await tester.pumpAndSettle();
    expect(h.billing.restores, 1);
    expect(find.text('No previous purchase found.'), findsOneWidget);

    h.billing.restoreResult = PurchaseOutcome.restored;
    await tester.tap(find.byKey(const Key('settings_restore_purchases')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Premium!'), findsOneWidget);
    expect(h.state(tester).isPremium, isTrue);
  });

  testWidgets('AC-38 free users see the accent themes locked', (tester) async {
    final h = await openSettings(tester);
    final before = app(tester).theme!.colorScheme.primary;
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    await tester.tap(find.byKey(const Key('accent_sunset')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(h.state(tester).accent, AccentTheme.lagoon);
    expect(app(tester).theme!.colorScheme.primary, before);
  });

  testWidgets(
    'AC-38 Premium users can pick an accent theme that recolours the app',
    (tester) async {
      final h = await openSettings(tester, premium: true);
      final before = app(tester).theme!.colorScheme.primary;
      await tester.tap(find.byKey(const Key('accent_sunset')));
      await tester.pumpAndSettle();
      expect(h.state(tester).accent, AccentTheme.sunset);
      expect(app(tester).theme!.colorScheme.primary, isNot(before));
      expect(h.repo.settings['accent'], 'sunset');
    },
  );

  testWidgets('AC-38 a Premium Pass also unlocks the accent themes', (
    tester,
  ) async {
    final h = await openSettings(
      tester,
      initial: Snapshot(
        settings: {'pass_end': DateTime(2026, 10, 12).toIso8601String()},
      ),
    );
    await tester.tap(find.byKey(const Key('accent_forest')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
    expect(h.state(tester).accent, AccentTheme.forest);
  });

  testWidgets('AC-47 theme follows the system by default and can be forced', (
    tester,
  ) async {
    final h = await openSettings(tester);
    expect(app(tester).themeMode, ThemeMode.system);
    await tester.tap(find.byKey(const Key('theme_dark')));
    await tester.pumpAndSettle();
    expect(app(tester).themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Settings').first)).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byKey(const Key('theme_light')));
    await tester.pumpAndSettle();
    expect(app(tester).themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Settings').first)).brightness,
      Brightness.light,
    );
    expect(h.repo.settings['theme_mode'], isNotNull);
  });

  testWidgets('AC-39 categories are Premium; free users get the paywall', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('open_categories')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
  });

  testWidgets('AC-39 create, rename and delete a custom category', (
    tester,
  ) async {
    final h = await openSettings(tester, premium: true);
    await tester.tap(find.byKey(const Key('open_categories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categories_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('new_category')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('category_name')), 'Ski pass');
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('color_2')));
    await tapOn(tester, find.byKey(const Key('save_category')));
    expect(find.byKey(const Key('custom_Ski pass')), findsOneWidget);
    final created = h.repo.categories.values.single;
    expect((created.name, created.colorIndex), ('Ski pass', 2));

    await tester.tap(find.byKey(const Key('edit_Ski pass')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('category_name')), 'Lift pass');
    await tester.pumpAndSettle();
    await tapOn(tester, find.byKey(const Key('save_category')));
    expect(find.byKey(const Key('custom_Lift pass')), findsOneWidget);
    expect(h.repo.categories.values.single.id, created.id);

    await tester.tap(find.byKey(const Key('delete_Lift pass')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Lift pass?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialog_confirm')));
    await tester.pumpAndSettle();
    expect(h.repo.categories, isEmpty);
    expect(find.byKey(const Key('categories_empty')), findsOneWidget);
  });

  testWidgets('AC-39 a name is required and must be unique', (tester) async {
    await openSettings(
      tester,
      premium: true,
      initial: const Snapshot(
        categories: [
          CustomCategory(
            id: 'c1',
            name: 'Tips',
            iconKey: 'local_activity',
            colorIndex: 0,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('open_categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new_category')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('category_name')), 'tips');
    await tester.pumpAndSettle();
    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_category')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('category_name')), '  ');
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
  });

  testWidgets('AC-39 a category used by an expense cannot be deleted', (
    tester,
  ) async {
    final h = await openSettings(
      tester,
      premium: true,
      initial: Snapshot(
        trips: [sampleTrip()],
        expenses: [sampleExpense(id: 'e1', category: 'c1')],
        categories: const [
          CustomCategory(
            id: 'c1',
            name: 'Tips',
            iconKey: 'local_activity',
            colorIndex: 0,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('open_categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_Tips')));
    await tester.pumpAndSettle();
    expect(find.text('Category in use'), findsOneWidget);
    expect(
      find.text(
        '1 expense uses this category. Move them to another category first.',
      ),
      findsOneWidget,
    );
    expect(h.repo.categories, hasLength(1));
  });

  testWidgets(
    'AC-40 Back up writes one file with all trips to the share sheet',
    (tester) async {
      final h = await openSettings(
        tester,
        premium: true,
        initial: Snapshot(
          trips: [sampleTrip()],
          expenses: [sampleExpense(id: 'e1')],
        ),
      );
      await scrollTo(tester, const Key('backup'));
      await tester.tap(find.byKey(const Key('backup')));
      await tester.pumpAndSettle();
      final (bytes, name, mime) = h.files.sharedFiles.single;
      expect(name, 'trippi-backup-2026-10-11.json');
      expect(mime, 'application/json');
      final backup = Backup.decode(utf8.decode(bytes));
      expect(backup.tripCount, 1);
      expect(backup.expenseCount, 1);
    },
  );

  testWidgets(
    'AC-40 Restore previews the file and replaces data after confirming',
    (tester) async {
      final h = await openSettings(
        tester,
        premium: true,
        initial: Snapshot(trips: [sampleTrip(name: 'Old trip')]),
      );
      final file = Backup(
        savedAt: DateTime(2026, 9, 30),
        data: Snapshot(
          trips: [
            sampleTrip(id: 'a', name: 'Rome'),
            sampleTrip(id: 'b', name: 'Oslo'),
          ],
          expenses: [
            sampleExpense(id: 'e1', tripId: 'a'),
            sampleExpense(id: 'e2', tripId: 'a'),
            sampleExpense(id: 'e3', tripId: 'b'),
          ],
        ),
      );
      h.files.toPick = Uint8List.fromList(utf8.encode(file.encode()));
      await scrollTo(tester, const Key('restore'));

      await tester.tap(find.byKey(const Key('restore')));
      await tester.pumpAndSettle();
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(
        find.text(
          'This file has 2 trips and 3 expenses, saved 30 Sep 2026. It will replace everything on this phone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('dialog_cancel')));
      await tester.pumpAndSettle();
      expect(h.repo.trips.values.map((t) => t.name), ['Old trip']);

      await tester.tap(find.byKey(const Key('restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Backup restored'), findsOneWidget);
      expect(h.repo.trips.keys.toSet(), {'a', 'b'});
      expect(h.repo.expenses, hasLength(3));
    },
  );

  testWidgets('AC-40 an invalid file shows an error and changes nothing', (
    tester,
  ) async {
    final h = await openSettings(
      tester,
      premium: true,
      initial: Snapshot(trips: [sampleTrip()]),
    );
    h.files.toPick = Uint8List.fromList(utf8.encode('{"hello": 1}'));
    await scrollTo(tester, const Key('restore'));
    await tester.tap(find.byKey(const Key('restore')));
    await tester.pumpAndSettle();
    expect(find.text("This isn't a Trippi backup"), findsOneWidget);
    expect(h.repo.trips.keys, ['t-lisbon']);
  });

  testWidgets('AC-40 backup and restore are Premium for free users', (
    tester,
  ) async {
    final h = await openSettings(tester);
    await scrollTo(tester, const Key('backup'));
    await tester.tap(find.byKey(const Key('backup')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(h.files.sharedFiles, isEmpty);
  });

  testWidgets(
    'AC-34b Terms open from Settings; the Apple EULA link only on iOS',
    (tester) async {
      await openSettings(tester);
      await scrollTo(tester, const Key('settings_terms'));
      await tester.tap(find.byKey(const Key('settings_terms')));
      await tester.pumpAndSettle();
      expect(find.text('Terms of use'), findsWidgets);
      expect(
        find.byKey(const Key('terms_eula'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets('AC-34b on iOS the terms screen links the Apple EULA', (
    tester,
  ) async {
    final h = await openSettings(tester, isIOS: true);
    await scrollTo(tester, const Key('settings_terms'));
    await tester.tap(find.byKey(const Key('settings_terms')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('terms_eula')),
      find.byType(Scrollable).last,
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('terms_eula')));
    await tester.pumpAndSettle();
    expect(h.openedUrls.single, Uri.parse(appleEulaUrl));
  });

  testWidgets(
    'AC-41 after a settled trip the upgrade card shows; dismissing hides it for 7 days',
    (tester) async {
      usePhone(tester);
      final settled = Snapshot(
        trips: [sampleTrip()],
        expenses: [
          sampleExpense(id: 'e1', amount: 3000, among: ['p-ana']),
        ],
      );
      final h = Harness(initial: settled);
      await h.pump(tester);
      expect(find.byKey(const Key('upgrade_card')), findsOneWidget);
      expect(find.text('Trip settled!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dismiss_upgrade')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upgrade_card')), findsNothing);

      // 6 days later it is still hidden; after 7 days it may return.
      h.clockNow = DateTime(2026, 10, 17, 12);
      h.state(tester).notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upgrade_card')), findsNothing);
      h.clockNow = DateTime(2026, 10, 18, 13);
      h.state(tester).notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upgrade_card')), findsOneWidget);
    },
  );

  testWidgets(
    'AC-41 no upgrade card while a trip is unsettled or for Premium users',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(
          trips: [sampleTrip()],
          expenses: [sampleExpense(id: 'e1')],
        ),
      );
      await h.pump(tester);
      expect(find.byKey(const Key('upgrade_card')), findsNothing);
    },
  );

  testWidgets('AC-41 Premium users never see the upgrade card', (tester) async {
    usePhone(tester);
    final h = Harness(
      premium: true,
      initial: Snapshot(
        trips: [sampleTrip()],
        expenses: [
          sampleExpense(id: 'e1', amount: 3000, among: ['p-ana']),
        ],
      ),
    );
    await h.pump(tester);
    expect(find.text('Lisbon weekend'), findsOneWidget);
    expect(find.byKey(const Key('upgrade_card')), findsNothing);
  });

  testWidgets(
    'AC-41 See Premium on the card opens the paywall without a video offer',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        initial: Snapshot(
          trips: [sampleTrip()],
          expenses: [
            sampleExpense(id: 'e1', amount: 3000, among: ['p-ana']),
          ],
        ),
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('see_premium')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.textContaining('Watch a short video'), findsNothing);
    },
  );
}
