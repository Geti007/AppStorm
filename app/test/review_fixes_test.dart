import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassful/main.dart';
import 'package:glassful/state/app_state.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('AC-10 1995 of 2000 ml shows 99% and no Goal reached', (
    tester,
  ) async {
    await pumpApp(
      tester,
      storage: MemoryStorage(
        savedJson(
          goals: [(daysAgo(5), 2000)],
          drinks: [(daysAgo(0, hour: 9), 1995)],
        ),
      ),
    );
    expect(text(tester, 'percent'), '99%');
    expect(find.byKey(const Key('goal_reached')), findsNothing);
  });

  testWidgets('AC-20 the message shows even when data loaded before launch', (
    tester,
  ) async {
    usePhoneView(tester);
    final state = AppState(storage: MemoryStorage('{broken'));
    await state.load();
    await tester.pumpWidget(GlassfulApp(state: state, ads: FakeAds()));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't read saved data. Starting fresh."),
      findsOneWidget,
    );
  });
}
