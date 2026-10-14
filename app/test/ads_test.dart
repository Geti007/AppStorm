import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

MemoryStorage withDrinks() => MemoryStorage(
  savedJson(
    goals: [(daysAgo(30), 2000)],
    drinks: [(daysAgo(1), 1500), (daysAgo(0, hour: 9), 500)],
  ),
);

void main() {
  testWidgets('AC-21 one banner on History only, below the content', (
    tester,
  ) async {
    final h = await pumpApp(tester, storage: withDrinks());
    expect(h.ads.started, 1);
    // Today: no ad.
    expect(find.byKey(const Key('history_banner')), findsNothing);
    expect(find.byKey(const Key('fake_ad')), findsNothing);

    await openTab(tester, 'tab_history');
    expect(find.byKey(const Key('history_banner')), findsOneWidget);
    expect(find.byKey(const Key('fake_ad')), findsOneWidget);
    // Anchored below the scrolling content, above the navigation bar.
    final banner = tester.getRect(find.byKey(const Key('history_banner')));
    final nav = tester.getRect(find.byKey(const Key('nav')));
    final list = tester.getRect(find.byType(ListView).last);
    expect(banner.bottom, lessThanOrEqualTo(nav.top));
    expect(banner.top, greaterThanOrEqualTo(list.bottom));

    await openTab(tester, 'tab_settings');
    expect(find.byKey(const Key('fake_ad')), findsNothing);
    await openTab(tester, 'tab_today');
    expect(find.byKey(const Key('fake_ad')), findsNothing);
  });

  testWidgets('AC-21 no ad on onboarding', (tester) async {
    await pumpApp(tester, storage: MemoryStorage());
    expect(find.byKey(const Key('onboarding')), findsOneWidget);
    expect(find.byKey(const Key('fake_ad')), findsNothing);
  });

  testWidgets('AC-21 no ad request before consent allows it', (tester) async {
    final ads = FakeAds(canRequest: false);
    await pumpApp(tester, storage: withDrinks(), ads: ads);
    await openTab(tester, 'tab_history');
    expect(ads.bannersCreated, 0);
    expect(find.byKey(const Key('history_banner')), findsNothing);
    ads.canRequest.value = true;
    await tester.pumpAndSettle();
    expect(ads.bannersCreated, 1);
    expect(find.byKey(const Key('history_banner')), findsOneWidget);
  });

  testWidgets('AC-22 a failed banner leaves no gap', (tester) async {
    final ads = FakeAds(bannerLoads: false);
    await pumpApp(tester, storage: withDrinks(), ads: ads);
    await openTab(tester, 'tab_history');
    expect(ads.bannersCreated, 1);
    expect(find.byKey(const Key('history_banner')), findsNothing);
    final list = tester.getRect(find.byType(ListView).last);
    final nav = tester.getRect(find.byKey(const Key('nav')));
    expect(list.bottom, nav.top);
  });

  testWidgets('AC-22 offline (ads never allowed) leaves no gap', (
    tester,
  ) async {
    final ads = FakeAds(canRequest: false);
    await pumpApp(tester, storage: withDrinks(), ads: ads);
    await openTab(tester, 'tab_history');
    final list = tester.getRect(find.byType(ListView).last);
    final nav = tester.getRect(find.byKey(const Key('nav')));
    expect(list.bottom, nav.top);
  });
}
