import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippi/data/models.dart';
import 'package:trippi/screens/premium_screen.dart';
import 'package:trippi/services/billing.dart';
import 'package:trippi/state/app_state.dart';

import 'support/fakes.dart';

Future<Harness> openPaywall(
  WidgetTester tester, {
  PaywallSource source = PaywallSource.settings,
  StoreOffer? offer = const StoreOffer(price: r'$1.99', trialEligible: true),
  bool premium = false,
  bool isIOS = false,
  Map<String, String> settings = const {},
}) async {
  usePhone(tester);
  final h = Harness(
    premium: premium,
    isIOS: isIOS,
    initial: Snapshot(settings: settings),
  );
  h.billing.offer = offer;
  await h.pump(tester);
  final context = tester.element(find.byType(Scaffold).first);
  // ignore: unawaited_futures
  openPremium(context, source);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets(
    'AC-34 the paywall lists the benefits, the store price and the trial when eligible',
    (tester) async {
      await openPaywall(tester);
      for (final b in premiumBenefits) {
        expect(find.text(b), findsOneWidget);
      }
      expect(find.text('Free for 7 days'), findsOneWidget);
      expect(
        find.text(r'then $1.99/month starting 18 Oct 2026'),
        findsOneWidget,
      );
      expect(find.text('Start free trial'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(
        find.text(
          'Renews automatically each month until cancelled. Cancel anytime in your Google Play subscription settings.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AC-34a no trial is offered when the store says the user is not eligible',
    (tester) async {
      await openPaywall(
        tester,
        offer: const StoreOffer(price: '€2,29', trialEligible: false),
      );
      expect(find.text('Free for 7 days'), findsNothing);
      expect(find.text('Start free trial'), findsNothing);
      expect(find.text('€2,29/month'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-34b terms open from the paywall; the Apple EULA link is iOS only',
    (tester) async {
      await openPaywall(tester);
      expect(find.text('Apple EULA'), findsNothing);
      await tapOn(tester, find.byKey(const Key('premium_terms')));
      expect(find.byKey(const Key('terms_page')), findsOneWidget);
      expect(find.text('Premium subscription'), findsOneWidget);
      expect(find.byKey(const Key('terms_eula')), findsNothing);
    },
  );

  testWidgets('AC-34b on iOS the paywall and terms link to the Apple EULA', (
    tester,
  ) async {
    await openPaywall(tester, isIOS: true);
    expect(find.text('Apple EULA'), findsOneWidget);
    expect(
      find.textContaining('App Store subscription settings'),
      findsOneWidget,
    );
    await tapOn(tester, find.byKey(const Key('premium_terms')));
    await tester.dragUntilVisible(
      find.byKey(const Key('terms_eula')),
      find.byKey(const Key('terms_page')),
      const Offset(0, -300),
    );
    expect(find.byKey(const Key('terms_eula')), findsOneWidget);
  });

  testWidgets('AC-34b the privacy policy opens from the paywall', (
    tester,
  ) async {
    await openPaywall(tester);
    await tapOn(tester, find.byKey(const Key('premium_privacy')));
    expect(find.byKey(const Key('privacy_page')), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Advertising (free plan only)'),
      find.byKey(const Key('privacy_page')),
      const Offset(0, -300),
    );
    expect(find.text('Advertising (free plan only)'), findsOneWidget);
  });

  testWidgets(
    'AC-35 when the store has no product the paywall says so and offers retry',
    (tester) async {
      final h = await openPaywall(tester, offer: null);
      expect(find.text("Premium isn't available right now"), findsOneWidget);
      expect(find.byKey(const Key('subscribe')), findsNothing);
      h.billing.offer = const StoreOffer(price: r'$1.99', trialEligible: false);
      await tester.tap(find.byKey(const Key('premium_retry')));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-36 a purchase turns Premium on at once and survives a restart',
    (tester) async {
      final h = await openPaywall(tester);
      await tapOn(tester, find.byKey(const Key('subscribe')));
      expect(h.billing.buys, 1);
      expect(find.byType(PremiumScreen), findsNothing);
      expect(find.text('Welcome to Premium!'), findsOneWidget);
      expect(h.repo.settings['premium'], '1');

      await tester.pumpWidget(const SizedBox());
      await h.pump(tester);
      expect(h.state(tester).isPremium, isTrue);
      expect(h.state(tester).adsEnabled, isFalse);
    },
  );

  testWidgets('AC-36 restore turns Premium on; nothing to restore says so', (
    tester,
  ) async {
    final h = await openPaywall(tester);
    await tapOn(tester, find.byKey(const Key('restore_purchases')));
    expect(find.text('No previous purchase found.'), findsOneWidget);
    expect(h.repo.settings['premium'], isNull);
    h.billing.restoreResult = PurchaseOutcome.restored;
    await tapOn(tester, find.byKey(const Key('restore_purchases')));
    expect(h.repo.settings['premium'], '1');
  });

  testWidgets('AC-36 a failed purchase keeps the user on the free plan', (
    tester,
  ) async {
    final h = await openPaywall(tester);
    h.billing.buyResult = PurchaseOutcome.failed;
    await tapOn(tester, find.byKey(const Key('subscribe')));
    expect(
      find.text("Purchase didn't go through. You weren't charged."),
      findsOneWidget,
    );
    expect(h.repo.settings['premium'], isNull);
  });

  testWidgets('AC-36 AC-40a Premium is re-checked with the store at launch', (
    tester,
  ) async {
    usePhone(tester);
    final lapsed = Harness(premium: true)..billing.active = false;
    await lapsed.pump(tester, startServices: true);
    expect(lapsed.state(tester).isPremium, isFalse);

    await tester.pumpWidget(const SizedBox());
    final offline = Harness(premium: true)..billing.active = null;
    await offline.pump(tester, startServices: true);
    expect(offline.state(tester).isPremium, isTrue);
  });

  testWidgets(
    'AC-40a Premium is re-checked when the app returns to the foreground',
    (tester) async {
      usePhone(tester);
      final h = Harness(premium: true)..billing.active = true;
      await h.pump(tester, startServices: true);
      expect(h.state(tester).isPremium, isTrue);
      h.billing.active = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.state(tester).isPremium, isFalse);
    },
  );

  testWidgets(
    'AC-40a after Premium lapses, data stays editable and only new items over the limits are blocked',
    (tester) async {
      usePhone(tester);
      final h = Harness(
        premium: true,
        initial: Snapshot(
          trips: [
            for (var i = 0; i < 4; i++)
              sampleTrip(
                id: 't$i',
                name: 'Trip $i',
                people: [
                  for (var j = 0; j < 7; j++)
                    Participant(id: 'p$i$j', name: 'P$j'),
                ],
              ),
          ],
          expenses: [
            sampleExpense(
              id: 'e1',
              tripId: 't0',
              paidBy: 'p00',
              among: ['p00', 'p01'],
              category: 'c1',
            ),
          ],
          categories: [
            const CustomCategory(
              id: 'c1',
              name: 'Ski pass',
              iconKey: 'downhill_skiing',
              colorIndex: 8,
            ),
          ],
          settings: {'accent': 'sunset'},
        ),
      );
      await h.pump(tester);
      final state = h.state(tester);
      expect(state.accent, AccentTheme.sunset);
      await state.setPremium(false);
      await tester.pumpAndSettle();
      expect(state.accent, AccentTheme.lagoon);
      expect(state.chosenAccent, AccentTheme.sunset);
      expect(state.canCreateTrip, isFalse);
      expect(state.canAddParticipant(7), isFalse);
      expect(state.hasPassFeatures, isFalse);
      // Existing data stays and keeps its custom category.
      expect(state.trips, hasLength(4));
      expect(state.category('c1').name, 'Ski pass');

      // An existing trip can still be edited and saved.
      await tester.tap(find.byKey(const Key('trip_menu_t0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit trip'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('trip_name')),
        'Renamed trip',
      );
      await tapOn(tester, find.byKey(const Key('save_trip')));
      expect(h.repo.trips['t0']!.name, 'Renamed trip');
      expect(h.repo.trips['t0']!.participants, hasLength(7));
    },
  );

  testWidgets(
    'AC-45 the rewarded offer states the reward and grants a 24-hour Pass only on reward',
    (tester) async {
      final h = await openPaywall(tester, source: PaywallSource.advancedStats);
      expect(
        find.text('Watch a short video for a free 24-hour Premium Pass'),
        findsOneWidget,
      );
      expect(h.ads.rewardedLoads, 1);
      // Not loaded yet: the offer is disabled.
      expect(find.text('No video available right now'), findsOneWidget);
      h.ads.ready.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Watch video'), findsOneWidget);

      // Closing the video early grants nothing.
      h.ads.rewardEarned = false;
      await tapOn(tester, find.byKey(const Key('watch_video')));
      expect(h.state(tester).passActive, isFalse);
      expect(find.byType(PremiumScreen), findsOneWidget);

      h.ads.ready.value = true;
      h.ads.rewardEarned = true;
      await tester.pumpAndSettle();
      await tapOn(tester, find.byKey(const Key('watch_video')));
      final state = h.state(tester);
      expect(state.passActive, isTrue);
      expect(state.passEnd, DateTime(2026, 10, 12, 12));
      expect(
        find.textContaining(
          RegExp(r'^Premium Pass active until 12:00\sPM, Mon$'),
        ),
        findsOneWidget,
      );
      expect(state.hasPassFeatures, isTrue);
      // A Pass does not remove ads or raise limits.
      expect(state.adsEnabled, isTrue);
      expect(state.isPremium, isFalse);
    },
  );

  testWidgets('AC-45 at most 3 rewarded videos a day', (tester) async {
    final h = await openPaywall(
      tester,
      source: PaywallSource.export,
      settings: {'rewarded_day': '2026-10-11', 'rewarded_count': '3'},
    );
    h.ads.ready.value = true;
    await tester.pumpAndSettle();
    expect(find.text('No video available right now'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('watch_video')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('AC-45 the Pass ends after 24 hours', (tester) async {
    usePhone(tester);
    final h = Harness();
    await h.pump(tester);
    final state = h.state(tester);
    await state.grantPass();
    expect(state.passActive, isTrue);
    h.clockNow = h.clockNow.add(const Duration(hours: 24, minutes: 1));
    expect(state.passActive, isFalse);
    expect(state.hasPassFeatures, isFalse);
  });

  for (final source in [
    PaywallSource.tripLimit,
    PaywallSource.participantLimit,
    PaywallSource.categories,
    PaywallSource.backup,
    PaywallSource.settings,
    PaywallSource.upgradeCard,
  ]) {
    testWidgets('AC-45a no rewarded offer when opened from ${source.name}', (
      tester,
    ) async {
      final h = await openPaywall(tester, source: source);
      expect(find.byKey(const Key('rewarded_offer')), findsNothing);
      expect(h.ads.rewardedLoads, 0);
    });
  }

  testWidgets('AC-46 Premium users never get a rewarded offer or ad requests', (
    tester,
  ) async {
    final h = await openPaywall(
      tester,
      source: PaywallSource.advancedStats,
      premium: true,
    );
    expect(find.byKey(const Key('rewarded_offer')), findsNothing);
    expect(find.text('Premium active'), findsOneWidget);
    expect(h.ads.rewardedLoads, 0);
    expect(h.ads.nativeRequests, 0);
  });

  testWidgets('AC-44 the paywall shows no native ad', (tester) async {
    final h = await openPaywall(tester);
    expect(find.byKey(const Key('native_ad')), findsNothing);
    expect(h.ads.nativeRequests, 0);
  });
}
