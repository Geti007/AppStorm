// End-to-end tests of the main flows. The factory runs these on an Android
// emulator: flutter test integration_test/app_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/data/storage.dart';
import 'package:glassful/main.dart';
import 'package:glassful/services/ads.dart';
import 'package:glassful/state/app_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> launch(WidgetTester tester) async {
  final state = AppState(storage: PrefsStorage());
  await tester.pumpWidget(GlassfulApp(state: state, ads: NoAdsService()));
  await state.load();
  await tester.pumpAndSettle();
  return state;
}

String text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('AC-2 AC-4 AC-6 AC-8 AC-19 a full day on the device', (
    tester,
  ) async {
    var state = await launch(tester);
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal_field')), '2500');
    await tapKey(tester, 'start_button');
    expect(text(tester, 'total'), '0 / 2500 ml');

    await tapKey(tester, 'add_250');
    await tapKey(tester, 'add_500');
    expect(text(tester, 'total'), '750 / 2500 ml');
    expect(text(tester, 'percent'), '30%');

    await tapKey(tester, 'add_custom');
    await tester.enterText(find.byKey(const Key('custom_field')), '330');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom_add')));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '1080 / 2500 ml');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(text(tester, 'total'), '750 / 2500 ml');

    // Close and reopen: everything is still there (AC-19).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    state = await launch(tester);
    expect(find.byKey(const Key('onboarding')), findsNothing);
    expect(text(tester, 'total'), '750 / 2500 ml');
    expect(state.todayDrinks, hasLength(2));
  });

  testWidgets('AC-12 AC-17 AC-18 history, units and reset on the device', (
    tester,
  ) async {
    final state = await launch(tester);
    await tapKey(tester, 'start_button');
    await tapKey(tester, 'add_500');
    await tapKey(tester, 'add_500');

    await tapKey(tester, 'tab_history');
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(Key('bar_$i')), findsOneWidget);
    }
    expect(text(tester, 'streak'), 'No streak yet');

    await tapKey(tester, 'tab_settings');
    await tester.tap(find.text('fl oz'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'tab_today');
    expect(text(tester, 'total'), '34 / 68 fl oz');
    expect(find.text('8 fl oz'), findsOneWidget);

    await tapKey(tester, 'tab_settings');
    await tapKey(tester, 'reset_all');
    await tapKey(tester, 'reset_confirm');
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(state.hasAnyDrinks, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsStorage.key), isNull);
  });

  testWidgets('AC-9 AC-11 AC-15 deleting the only drink empties both screens', (
    tester,
  ) async {
    final state = await launch(tester);
    await tapKey(tester, 'start_button');
    await tapKey(tester, 'add_250');
    expect(text(tester, 'total'), '250 / 2000 ml');
    await tapKey(tester, 'delete_1');
    expect(text(tester, 'total'), '0 / 2000 ml');
    expect(
      find.text('No drinks yet today. Tap a glass to start.'),
      findsOneWidget,
    );
    expect(state.hasAnyDrinks, isFalse);
    await tapKey(tester, 'tab_history');
    expect(
      find.text('Your week will show up here once you log a drink.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('history_banner')), findsNothing);
  });
}
