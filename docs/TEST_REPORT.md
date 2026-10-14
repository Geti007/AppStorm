# Glassful: test report

Independent test pass against `docs/SPEC.md` (AC-1 to AC-30). All widget
tests were run in this session with `flutter test` on Flutter 3.47.7. The
integration tests (`app/integration_test/app_test.dart`) were **not run here**:
`flutter devices` lists only "Linux (desktop)" and there is no Android SDK or
emulator on this machine. The "Check an app" workflow runs them on an emulator.

Ads were tested only with a fake ad service (`FakeAds` in
`app/test/support/fakes.dart`). No real or test ad was loaded or tapped.

## Acceptance criteria

Result is for the widget tests run in this session. Every AC has at least one
automated test; none needs a person.

| AC | Test file and test name | Result |
|----|-------------------------|--------|
| AC-1 | `test/onboarding_test.dart`: "AC-1 first launch shows onboarding with 2000 ml" | PASS |
| AC-2 | `test/onboarding_test.dart`: "AC-2 Start tracking opens Today and onboarding stays done"; `test/edge_cases_test.dart`: "AC-2 double tap on Start tracking saves one goal", "AC-2 restart in the middle of onboarding starts it again" | PASS |
| AC-3 | `test/onboarding_test.dart`: "AC-3 out-of-range goal shows an error and stays"; `test/edge_cases_test.dart`: "AC-3 a 25-digit goal is rejected, not crashed on" | PASS |
| AC-4 | `test/today_test.dart`: "AC-4 tapping 250 ml adds to the total and the log"; `test/edge_cases_test.dart`: "AC-4 two fast taps on 250 ml log two drinks of 250" | PASS |
| AC-5 | `test/today_test.dart`: "AC-5 shows 1000 / 2000 ml and 50%"; `test/edge_cases_test.dart`: "AC-5 ring is half full and its label is spoken" | PASS |
| AC-6 | `test/today_test.dart`: "AC-6 a custom 330 ml is added"; `test/edge_cases_test.dart`: "AC-6 double tap on Add logs the custom amount once", "AC-6 Cancel adds nothing; custom in fl oz stores exact ml" | PASS |
| AC-7 | `test/today_test.dart`: "AC-7 Add is disabled for empty, 0 or too much"; `test/edge_cases_test.dart`: "AC-7 limits: 1 and 2000 ml allowed; 25 digits disabled", "AC-7 fl oz: 67 allowed, 68 disabled" | PASS |
| AC-8 | `test/today_test.dart`: "AC-8 Undo removes the drink just added"; `test/edge_cases_test.dart`: "AC-8 Undo after two drinks removes only the last one", "AC-8 the Undo snackbar goes away on its own", "AC-8 Undo after the drink was deleted does nothing harmful" | PASS (after fix, bug 1) |
| AC-9 | `test/today_test.dart`: "AC-9 deleting an entry updates the total"; `test/edge_cases_test.dart`: "AC-9 double tap on delete removes one entry only" | PASS (after fix, bug 4) |
| AC-10 | `test/today_test.dart`: "AC-10 reaching the goal shows Goal reached, ring stays full"; `test/edge_cases_test.dart`: "AC-10 the ring is full and never above 100% past the goal", "AC-10 within 0.5 ml of the goal counts as reached", "AC-10 1999 ml of a 2000 ml goal is not reached" | PASS |
| AC-11 | `test/today_test.dart`: "AC-11 empty day shows the empty message"; `test/edge_cases_test.dart`: "AC-11 deleting the last drink brings back the empty message" | PASS |
| AC-12 | `test/history_test.dart`: "AC-12 seven bars, today last, and daily totals"; `test/edge_cases_test.dart`: "AC-12 bars are proportional and today is the last bar", "AC-12 only old drinks: 7 empty bars, not the empty state" | PASS |
| AC-13 | `test/history_test.dart`: "AC-13 three met days in a row make a 3-day streak"; `test/edge_cases_test.dart`: "AC-13 a met today with an unmet yesterday is a 1-day streak", "AC-13 streak grows live when today reaches the goal" | PASS |
| AC-14 | `test/history_test.dart`: "AC-14 an unfinished today does not break the streak", "AC-14 the streak counts days older than the last week"; `test/edge_cases_test.dart`: "AC-14 nothing met yesterday or today shows No streak yet" | PASS |
| AC-15 | `test/history_test.dart`: "AC-15 no drinks ever: empty message and no ad"; `test/edge_cases_test.dart`: "AC-15 deleting every drink brings back the empty History" | PASS |
| AC-16 | `test/settings_test.dart`: "AC-16 changing the goal to 2500 shows on Today"; `test/edge_cases_test.dart`: "AC-16 goal edit in fl oz validates in ounces", "AC-16 saving the unchanged ounce goal keeps the exact ml" | PASS |
| AC-17 | `test/settings_test.dart`: "AC-17 switching to fl oz changes amounts and buttons"; `test/edge_cases_test.dart`: "AC-17 switching back to ml shows exact ml of oz drinks" | PASS |
| AC-18 | `test/settings_test.dart`: "AC-18 Reset deletes everything; Cancel deletes nothing"; `test/edge_cases_test.dart`: "AC-18 after reset the app starts clean and survives restart", "AC-18 dismissing the reset dialog deletes nothing", "AC-18 double tap on Reset does not skip onboarding" | PASS (after fix, bug 5) |
| AC-19 | `test/data_test.dart`: "AC-19 drinks, goal and unit survive a restart", "AC-19 shared_preferences storage round-trips the app data"; `test/edge_cases_test.dart`: "AC-19 restart with the custom dialog open loses nothing", "AC-19 drink times survive a restart", "AC-19 PrefsStorage key is stable" | PASS |
| AC-20 | `test/data_test.dart`: "AC-20 unreadable data starts fresh with a message", "AC-20 data with the wrong shape also starts fresh"; `test/edge_cases_test.dart`: "AC-20 storage that throws on read starts fresh", "AC-20 a bad drink entry inside valid JSON starts fresh", "AC-20 after starting fresh, new data replaces the bad data", "AC-20 a full disk does not crash logging", "AC-20 loading state shows a spinner and no ad" | PASS |
| AC-21 | `test/ads_test.dart`: "AC-21 one banner on History only, below the content", "AC-21 no ad on onboarding", "AC-21 no ad request before consent allows it"; `test/edge_cases_test.dart`: "AC-21 launch requests no ad and starts consent once", "AC-21 tab switching shows at most one banner, frees the old", "AC-21 no ad in the custom dialog, goal and reset dialogs", "AC-21 rotating History replaces the banner, no overflow", "AC-21 consent refused: no banner request on any screen", "AC-21 debug and test builds use only Google test ad units" | PASS |
| AC-22 | `test/ads_test.dart`: "AC-22 a failed banner leaves no gap", "AC-22 offline (ads never allowed) leaves no gap"; `test/edge_cases_test.dart`: "AC-22 a banner that later fails collapses with no gap", "AC-22 a banner that loads late appears without breaking", "AC-22 the real service offers no banner before consent", "AC-22 the Undo snackbar never sits over the History banner" | PASS (after fix, bugs 1 and 2) |
| AC-23 | `test/settings_test.dart`: "AC-23 Privacy options shows only when required"; `test/edge_cases_test.dart`: "AC-23 Privacy options appears and hides as consent changes" | PASS |
| AC-24 | `test/accessibility_test.dart`: "AC-24 labels on quick-add, delete and tabs", "AC-24 tappable controls are at least 48 by 48", "AC-24 text contrast meets the guideline on Today"; `test/edge_cases_test.dart`: "AC-24 tap targets on onboarding, History and every dialog", "AC-24 labels in fl oz and every tap target has a label", "AC-24 dark mode text contrast on every screen", "AC-24 dark mode contrast with Goal reached showing", "AC-24 light mode text contrast on History and Settings" | PASS (after fix, bug 3) |
| AC-25 | `test/accessibility_test.dart`: "AC-25 text scale 2.0 on 320x568: no overflow anywhere", "AC-25 dark mode renders every tab without errors"; `test/edge_cases_test.dart`: "AC-25 text 2.0 at 320x568: goal reached, snackbar, fl oz", "AC-25 text 2.0 rotated to 568x320: no overflow anywhere", "AC-25 text 2.0 at 320x568 in dark mode with a full week", "AC-25 large tablet screen renders every tab" | PASS |
| AC-26 | `test/onboarding_test.dart`: "AC-26 choosing fl oz shows 68 and the ounce range"; `test/edge_cases_test.dart`: "AC-26 ounce limits 17 and 202 are accepted, 203 is not" | PASS |
| AC-27 | `test/today_test.dart`: "AC-27 eight 8 fl oz drinks meet a 64 fl oz goal"; `test/edge_cases_test.dart`: "AC-27 full flow: onboard at 64 fl oz, tap 8 fl oz 8 times", "AC-27 three 6 fl oz drinks show 18 fl oz, not 17 or 19" | PASS |
| AC-28 | `test/today_test.dart`: "AC-28 after midnight Today starts at 0 and History keeps it"; `test/edge_cases_test.dart`: "AC-28 midnight passes while the app stays open", "AC-28 opening the app the next morning starts at 0" | PASS |
| AC-29 | `test/history_test.dart`: "AC-29 raising the goal does not rewrite past days"; `test/edge_cases_test.dart`: "AC-29 lowering the goal does not make past days met", "AC-29 the past goal survives a restart and midnight" | PASS |
| AC-30 | `test/settings_test.dart`: "AC-30 a goal of 200 ml shows the range and keeps the old" | PASS |

End-to-end tests in `app/integration_test/app_test.dart` (not run in this
session, no device): "AC-2 AC-4 AC-6 AC-8 AC-19 a full day on the device",
"AC-12 AC-17 AC-18 history, units and reset on the device", and the new
"AC-9 AC-11 AC-15 deleting the only drink empties both screens".

## Edge cases tried

- Empty input, 0, above the maximum, 25-digit numbers, the exact limits in ml
  and fl oz (onboarding, custom dialog, Settings goal dialog).
- Emoji and right-to-left text: not applicable. Every text field accepts digits
  only (`FilteringTextInputFormatter.digitsOnly`).
- Tapping twice quickly: Start tracking, quick add, custom Add, Undo, delete,
  Settings Save, Reset confirm.
- Restart mid-flow: during onboarding, with the custom dialog open, after
  reset, after a goal change and overnight.
- Midnight: while the app stays open (timer), on return from the background,
  and on a fresh launch the next morning.
- Large text (2.0) on 320x568 portrait and 568x320 landscape, light and dark;
  a 1280x800 tablet; rotation with the banner showing.
- Dark mode text contrast on onboarding, Today (with "Goal reached"), History
  and Settings; light mode contrast on Today with "Goal reached", History and
  Settings.
- Storage that cannot be read, malformed JSON, a bad drink entry, a full disk,
  and a slow first read (the loading state).
- Ads with the fake service: consent given, consent refused, consent arriving
  later, banner fails, banner fails after loading, banner loads late, no
  request at launch or on returning to the app, no ad on onboarding, Today,
  Settings, any dialog, the loading state or an empty History, one banner at a
  time and the old one disposed. Debug and test builds resolve to publisher
  `ca-app-pub-3940256099942544`, and no other ad unit id appears in `app/lib`.
  The app has no interstitial or rewarded ads, so there is no frequency cap to
  test.

Mutation check: I broke six behaviours one at a time in `app/lib` (ring not
capped, midnight timer not refreshing, no 0.5 ml tolerance, a goal change
rewriting past days, a banner that has not loaded still taking space, the
real ad service requesting before consent). In every case at least one new
test failed. All six files were restored afterwards.

## Bugs found and fixed

1. **The "Added ... / Undo" snackbar never went away (AC-8, AC-22).** In this
   Flutter version a `SnackBar` with an action defaults to `persist: true`.
   The snackbar stayed on screen indefinitely, covered bottom controls (at
   2.0 text it hid "Reset all data") and floated over the History ad banner.
   Undo also stayed live for drinks added long before.
   Reproduce: tap 250 ml, wait 10 seconds. The snackbar is still there.
   Fix: `persist: false` on that snackbar (`app/lib/screens/today_screen.dart`).
   Tests: "AC-8 the Undo snackbar goes away on its own", "AC-22 the Undo
   snackbar never sits over the History banner".
2. **The Undo snackbar covered the History ad banner (AC-22, ad policy).** For
   about 4 seconds after adding a drink, opening History put the floating
   snackbar, with its Undo button, on top of the banner. That invites
   accidental ad clicks.
   Reproduce: tap 250 ml, then tap the History tab at once.
   Fix: switching tabs removes the current snackbar
   (`app/lib/screens/home_shell.dart`).
   Test: "AC-22 the Undo snackbar never sits over the History banner".
3. **"Goal reached" text contrast was 3.37:1 in light mode (AC-24, spec
   section 10 requires 4.5:1).** It was white on aqua `#1F9AA6`.
   Reproduce: reach the goal in light mode and run the text contrast
   guideline.
   Fix: in light mode the chip's label and icon use the on-surface colour
   `#0F2233` (about 4.8:1). Dark mode is unchanged
   (`app/lib/screens/today_screen.dart`). Note for the designer:
   `brand/brand.json` pairs `secondary #1F9AA6` with `on_secondary #FFFFFF`,
   and that pair fails 4.5:1.
   Test: "AC-24 light mode text contrast on History and Settings" (it starts
   on Today with the goal reached).
4. **A quick double tap on a delete button deleted two drinks (AC-9).** The
   rows below slide up at once, so the second tap landed on the next drink's
   delete button. Delete has no Undo, so the drink was lost.
   Reproduce: log two drinks, double-tap the top delete button.
   Fix: a second delete within the double-tap timeout (300 ms) is ignored
   (`app/lib/screens/today_screen.dart`).
   Test: "AC-9 double tap on delete removes one entry only". It also checks
   that a deliberate second delete a moment later still works.
5. **A quick double tap on "Reset" skipped onboarding (AC-18).** Onboarding
   appears under the closing dialog, with "Start tracking" where "Reset" was.
   The second tap completed onboarding with the default goal.
   Reproduce: Settings, Reset all data, double-tap Reset.
   Fix: for 300 ms after a reset, onboarding ignores "Start tracking"
   (`AppState.justReset` in `app/lib/state/app_state.dart`, and the check in
   `app/lib/screens/onboarding_screen.dart`).
   Test: "AC-18 double tap on Reset does not skip onboarding".

## Observations (not changed)

- Past the goal, the percentage text keeps counting (for example "125%"),
  while the ring stays full. AC-10 says "the progress ring is full (100%,
  never above)". I read that as the ring, which is capped and tested. If the
  owner meant the number too, this is a bug.
- In onboarding, switching ml, then fl oz, then back to ml turns 2000 into
  2011 (68 fl oz converted back). The spec does not cover this.
- `app/lib/services/ads.dart` was changed by someone else during this session
  (adaptive-banner test ids `.../9214589741` and `.../2435281174`, and
  try/catch around the consent forms). I did not write those changes. The
  tests above ran against the changed file.
- `app/config/ads.release.json` still has empty ids. The owner fills them in.

## Commands run and their final output

```
$ cd app && flutter analyze --fatal-infos --fatal-warnings
Analyzing app...
No issues found! (ran in 2.6s)

$ cd app && dart format lib test integration_test
Formatted 27 files (0 changed) in 0.22 seconds.

$ cd app && flutter test --coverage --reporter compact
00:36 +103: All tests passed!

$ flutter devices
Linux (desktop) • linux • linux-x64 • Ubuntu 24.04.5 LTS 6.18.44-fc-v114
(no Android device or emulator: integration tests not run)
```

Line coverage of `app/lib` from `coverage/lcov.info`: **866 of 957 lines,
90.5%**. Every screen file is 98-100%. `lib/services/ads.dart` is 12%: the
real Google ad service talks to the native SDK and is replaced by a fake in
tests, by design.

Gate command:

```
$ FACTORY_SKIP_APK=1 python3 -c "from factory import gates; from pathlib import Path; print(gates.build(Path('.')) + gates.acceptance_coverage(Path('.')))"
[]
```
