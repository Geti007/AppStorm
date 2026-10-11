import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'AC-50 onboarding shows on first launch and Get started ends it',
    (tester) async {
      usePhone(tester);
      final h = Harness(onboarded: false);
      await h.pump(tester);
      expect(find.text('Split costs with your travel crew'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Any currency, one total'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Settle up in fewer payments'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trips_empty')), findsOneWidget);
      expect(h.repo.settings['onboarding_done'], '1');

      // Not shown again after a restart.
      await tester.pumpWidget(const SizedBox());
      await h.pump(tester);
      expect(find.text('Split costs with your travel crew'), findsNothing);
      expect(find.byKey(const Key('trips_empty')), findsOneWidget);
    },
  );

  testWidgets('AC-50 onboarding can be skipped', (tester) async {
    usePhone(tester);
    final h = Harness(onboarded: false);
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trips_empty')), findsOneWidget);
  });

  testWidgets('AC-44 onboarding never shows an ad', (tester) async {
    usePhone(tester);
    final h = Harness(onboarded: false);
    await h.pump(tester);
    expect(find.byKey(const Key('native_ad')), findsNothing);
    expect(h.ads.nativeRequests, 0);
  });
}
