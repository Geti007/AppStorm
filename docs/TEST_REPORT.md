# Trippi test report

Every acceptance criterion in `docs/SPEC.md` is named in at least one
automated test. There are no MANUAL criteria. 142 unit and widget tests run with
`flutter test`; 3 end-to-end tests in `integration_test/app_test.dart` run on
the Android emulator in the "Check an app" workflow (results in
`docs/CHECK_REPORT.md`).

The store, the ads SDK, the exchange-rate service and the share sheet are
replaced by fakes in tests, so these tests prove the app's behaviour around
them, not Google's or Apple's SDKs themselves. See "Not verified" below.

## Acceptance criteria

| AC | Tests | Result |
|----|-------|--------|
| AC-1 | `test/trips_test.dart`: AC-1 no trips shows the empty state and its button opens the form | PASS |
| AC-2 | `test/edge_cases_test.dart`: AC-2 tapping Save twice fast creates one trip<br>`test/trips_test.dart`: AC-2 Save stays disabled until a name and 2 people; the trip appears at the top<br>`integration_test/app_test.dart`: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart | PASS |
| AC-3 | `test/trips_test.dart`: AC-3 participant names must be unique and non-empty | PASS |
| AC-4 | `test/review_fixes_test.dart`: AC-4 the trip currency can't be changed after the trip is created<br>`test/trips_test.dart`: AC-4 editing a trip; a person in an expense cannot be removed | PASS |
| AC-5 | `test/trips_test.dart`: AC-5 deleting a trip asks first, then removes it with its expenses | PASS |
| AC-6 | `test/trips_test.dart`: AC-6 a 4th trip on the free plan opens Premium instead of the form<br>`test/trips_test.dart`: AC-6 Premium users can create any number of trips | PASS |
| AC-7 | `test/trips_test.dart`: AC-7 a 7th participant on the free plan opens Premium<br>`test/trips_test.dart`: AC-7 Premium users can add more than 6 participants | PASS |
| AC-8 | `test/trips_test.dart`: AC-8 trips are newest first and cards show name, dates, total and people<br>`test/trips_test.dart`: AC-8 a trip card opens the trip dashboard | PASS |
| AC-9 | `test/edge_cases_test.dart`: AC-9 tapping Save twice fast creates one expense<br>`test/expenses_test.dart`: AC-9 Save stays disabled until title, valid amount, payer and split are set<br>`test/expenses_test.dart`: AC-9 AC-17 a zero-decimal currency rejects decimals<br>`test/money_test.dart`: AC-9 AC-17 amounts allow no more decimals than the currency has<br>`integration_test/app_test.dart`: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart | PASS |
| AC-10 | `test/expenses_test.dart`: AC-10 equal split shows each share and saves exact shares<br>`test/money_test.dart`: AC-10 equal split gives leftover cents to the first people | PASS |
| AC-11 | `test/expenses_test.dart`: AC-11 percentages must add up to 100 before Save<br>`test/money_test.dart`: AC-11 percentage split rounds to minor units and adds up exactly<br>`test/money_test.dart`: AC-11 percentages parse with up to 2 decimals<br>`test/review_fixes_test.dart`: AC-11 AC-18 huge percent splits and absurd rates stay safe | PASS |
| AC-12 | `test/expenses_test.dart`: AC-12 custom amounts must add up to the expense amount<br>`test/money_test.dart`: AC-12 custom amounts are used exactly | PASS |
| AC-13 | `test/expenses_test.dart`: AC-13 every built-in category is offered and shown with its icon | PASS |
| AC-14 | `test/expenses_test.dart`: AC-14 expenses are grouped by day, newest first, with base amounts | PASS |
| AC-15 | `test/expenses_test.dart`: AC-15 editing an expense updates totals and balances at once<br>`test/expenses_test.dart`: AC-15 deleting an expense asks first and can be undone for 4 seconds<br>`test/review_fixes_test.dart`: AC-15 a failed delete keeps the expense and says so | PASS |
| AC-16 | `test/expenses_test.dart`: AC-16 search filters by title as you type; clearing shows all | PASS |
| AC-17 | `test/expenses_test.dart`: AC-9 AC-17 a zero-decimal currency rejects decimals<br>`test/expenses_test.dart`: AC-17 the currency picker searches by code and name<br>`test/money_test.dart`: AC-17 minor units come from the bundled ISO 4217 list<br>`test/money_test.dart`: AC-9 AC-17 amounts allow no more decimals than the currency has<br>`test/money_test.dart`: AC-17 totals convert to the base currency rounded to its unit | PASS |
| AC-18 | `test/edge_cases_test.dart`: AC-18 with no network and no cached rate the app still opens<br>`test/expenses_test.dart`: AC-18 a different currency fills in the latest rate and its date; it can be overwritten<br>`test/expenses_test.dart`: AC-18 offline, the cached rate is used<br>`test/review_fixes_test.dart`: AC-11 AC-18 huge percent splits and absurd rates stay safe<br>`test/storage_test.dart`: AC-18 the latest rates are cached for offline use | PASS |
| AC-19 | `test/expenses_test.dart`: AC-19 with no rate available the form asks for one and blocks Save<br>`test/review_fixes_test.dart`: AC-19 when fetching a published rate fails, the form says so and Try again fetches it | PASS |
| AC-20 | `test/expenses_test.dart`: AC-20 later rate changes never change a saved expense<br>`test/money_test.dart`: AC-20 an expense keeps the rate stored with it | PASS |
| AC-21 | `test/expenses_test.dart`: AC-21 free users see the historical rate locked; it opens Premium<br>`test/expenses_test.dart`: AC-21 Premium fetches the rate on the expense date<br>`test/expenses_test.dart`: AC-21 a Premium Pass also unlocks the historical rate | PASS |
| AC-22 | `test/balances_stats_test.dart`: AC-22 AC-23 balances show signs and words, and the fewest payments<br>`test/money_test.dart`: AC-22 balance = paid − shares + payments made − payments received<br>`test/money_test.dart`: AC-22 balances add up to 0 with mixed currencies and splits<br>`test/review_fixes_test.dart`: AC-22 letter currency symbols are separated from the amount<br>`test/review_fixes_test.dart`: AC-22 shares of very large amounts never overflow<br>`integration_test/app_test.dart`: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart | PASS |
| AC-23 | `test/balances_stats_test.dart`: AC-22 AC-23 balances show signs and words, and the fewest payments<br>`test/money_test.dart`: AC-23 simplified payments: at most people − 1, and they settle everyone<br>`test/money_test.dart`: AC-23 the largest debtor pays the largest creditor first | PASS |
| AC-24 | `test/balances_stats_test.dart`: AC-24 Settle opens the payment prefilled; saving updates balances<br>`test/balances_stats_test.dart`: AC-24 a payment needs two different people and an amount above 0<br>`integration_test/app_test.dart`: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart | PASS |
| AC-25 | `test/balances_stats_test.dart`: AC-25 payment history lists payments and one can be deleted after confirming | PASS |
| AC-26 | `test/balances_stats_test.dart`: AC-26 when everyone is even the tab shows All settled up<br>`test/balances_stats_test.dart`: AC-26 balances with no expenses show the empty state<br>`test/money_test.dart`: AC-26 settled means every balance is within one minor unit<br>`integration_test/app_test.dart`: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart | PASS |
| AC-27 | `test/balances_stats_test.dart`: AC-27 the header shows total, number of expenses and average per person<br>`test/balances_stats_test.dart`: AC-27 with no expenses the header shows zeros | PASS |
| AC-28 | `test/balances_stats_test.dart`: AC-28 the Stats tab shows spending by category with amounts and percentages | PASS |
| AC-29 | `test/balances_stats_test.dart`: AC-29 free users see the advanced stats locked behind Unlock with Premium<br>`test/balances_stats_test.dart`: AC-29 Premium shows daily spending, who paid, and the top 5 expenses<br>`test/balances_stats_test.dart`: AC-29 a Premium Pass unlocks the advanced stats too | PASS |
| AC-30 | `test/balances_stats_test.dart`: AC-30 with no expenses Stats shows an empty state | PASS |
| AC-31 | `test/balances_stats_test.dart`: AC-31 Share summary sends the text summary to the share sheet<br>`test/storage_test.dart`: AC-31 the text summary lists total, balances and payments | PASS |
| AC-32 | `test/balances_stats_test.dart`: AC-32 AC-33 PDF and Excel are locked for free users<br>`test/balances_stats_test.dart`: AC-32 AC-33 Premium exports a PDF and an Excel file to the share sheet<br>`test/balances_stats_test.dart`: AC-32 a failed export shows an error and keeps the sheet open<br>`test/storage_test.dart`: AC-32 the PDF export is a PDF document | PASS |
| AC-33 | `test/balances_stats_test.dart`: AC-32 AC-33 PDF and Excel are locked for free users<br>`test/balances_stats_test.dart`: AC-32 AC-33 Premium exports a PDF and an Excel file to the share sheet<br>`test/storage_test.dart`: AC-33 the Excel export has Expenses, Balances and Payments sheets | PASS |
| AC-34 | `test/premium_test.dart`: AC-34 the paywall lists the benefits, the store price and the trial when eligible | PASS |
| AC-34a | `test/premium_test.dart`: AC-34a no trial is offered when the store says the user is not eligible | PASS |
| AC-34b | `test/premium_test.dart`: AC-34b terms open from the paywall; the Apple EULA link is iOS only<br>`test/premium_test.dart`: AC-34b on iOS the paywall and terms link to the Apple EULA<br>`test/premium_test.dart`: AC-34b the privacy policy opens from the paywall<br>`test/settings_test.dart`: AC-34b Terms open from Settings; the Apple EULA link only on iOS<br>`test/settings_test.dart`: AC-34b on iOS the terms screen links the Apple EULA | PASS |
| AC-35 | `test/premium_test.dart`: AC-35 when the store has no product the paywall says so and offers retry | PASS |
| AC-36 | `test/ads_test.dart`: AC-36 ads disappear as soon as Premium starts<br>`test/premium_test.dart`: AC-36 a purchase turns Premium on at once and survives a restart<br>`test/premium_test.dart`: AC-36 restore turns Premium on; nothing to restore says so<br>`test/premium_test.dart`: AC-36 a failed purchase keeps the user on the free plan<br>`test/premium_test.dart`: AC-36 AC-40a Premium is re-checked with the store at launch<br>`test/review_fixes_test.dart`: AC-36 AC-42 after "Try again" on a load error, launch checks still run<br>`integration_test/app_test.dart`: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads | PASS |
| AC-37 | `test/settings_test.dart`: AC-37 Manage subscription opens the store subscription page<br>`test/settings_test.dart`: AC-37 free users see Get Premium instead of Manage subscription | PASS |
| AC-38 | `test/settings_test.dart`: AC-38 free users see the accent themes locked<br>`test/settings_test.dart`: AC-38 Premium users can pick an accent theme that recolours the app<br>`test/settings_test.dart`: AC-38 a Premium Pass also unlocks the accent themes | PASS |
| AC-39 | `test/review_fixes_test.dart`: AC-39 tapping Save twice creates one category<br>`test/settings_test.dart`: AC-39 categories are Premium; free users get the paywall<br>`test/settings_test.dart`: AC-39 create, rename and delete a custom category<br>`test/settings_test.dart`: AC-39 a name is required and must be unique<br>`test/settings_test.dart`: AC-39 a category used by an expense cannot be deleted | PASS |
| AC-40 | `test/review_fixes_test.dart`: AC-40 a backup naming people who are not in the trip is rejected<br>`test/review_fixes_test.dart`: AC-40 backups with impossible data are rejected<br>`test/settings_test.dart`: AC-40 Back up writes one file with all trips to the share sheet<br>`test/settings_test.dart`: AC-40 Restore previews the file and replaces data after confirming<br>`test/settings_test.dart`: AC-40 an invalid file shows an error and changes nothing<br>`test/settings_test.dart`: AC-40 backup and restore are Premium for free users<br>`test/storage_test.dart`: AC-40 a backup file round-trips every trip<br>`test/storage_test.dart`: AC-40 an invalid file is rejected | PASS |
| AC-40a | `test/premium_test.dart`: AC-36 AC-40a Premium is re-checked with the store at launch<br>`test/premium_test.dart`: AC-40a Premium is re-checked when the app returns to the foreground<br>`test/premium_test.dart`: AC-40a after Premium lapses, data stays editable and only new items over the limits are blocked<br>`test/review_fixes_test.dart`: AC-40a AC-42 when Premium lapses on resume, consent and ads start | PASS |
| AC-41 | `test/expenses_test.dart`: AC-41 AC-44 the expense form shows no upgrade prompt and no ad<br>`test/settings_test.dart`: AC-41 after a settled trip the upgrade card shows; dismissing hides it for 7 days<br>`test/settings_test.dart`: AC-41 no upgrade card while a trip is unsettled or for Premium users<br>`test/settings_test.dart`: AC-41 See Premium on the card opens the paywall without a video offer | PASS |
| AC-42 | `test/ads_test.dart`: AC-42 at launch the consent flow runs for free users before any ad<br>`test/ads_test.dart`: AC-42 Settings shows Privacy options only when the consent SDK requires it<br>`test/review_fixes_test.dart`: AC-36 AC-42 after "Try again" on a load error, launch checks still run<br>`test/review_fixes_test.dart`: AC-40a AC-42 when Premium lapses on resume, consent and ads start | PASS |
| AC-43 | `test/ads_test.dart`: AC-43 a Sponsored native ad appears after the 2nd trip<br>`test/ads_test.dart`: AC-43 no ad with fewer than 2 trips<br>`test/ads_test.dart`: AC-43 an ad that fails to load leaves no gap<br>`test/ads_test.dart`: AC-43 the expense list shows an ad after every 10th expense, at most 2<br>`test/ads_test.dart`: AC-43 fewer than 10 expenses means no ad in the list<br>`test/review_fixes_test.dart`: AC-43 scrolling an ad away and back does not request a new ad | PASS |
| AC-44 | `test/ads_test.dart`: AC-44 forms, settle, settings and export show no ads<br>`test/ads_test.dart`: AC-44 empty states show no ads<br>`test/expenses_test.dart`: AC-41 AC-44 the expense form shows no upgrade prompt and no ad<br>`test/onboarding_test.dart`: AC-44 onboarding never shows an ad<br>`test/premium_test.dart`: AC-44 the paywall shows no native ad | PASS |
| AC-45 | `test/premium_test.dart`: AC-45 the rewarded offer states the reward and grants a 24-hour Pass only on reward<br>`test/premium_test.dart`: AC-45 at most 3 rewarded videos a day<br>`test/premium_test.dart`: AC-45 the Pass ends after 24 hours<br>`test/review_fixes_test.dart`: AC-45 a rewarded video closed early still counts toward the 3 a day | PASS |
| AC-45a | `test/premium_test.dart`: AC-45a no rewarded offer when opened from ${source.name} | PASS |
| AC-46 | `test/ads_test.dart`: AC-46 Premium users never load or request ads<br>`test/premium_test.dart`: AC-46 Premium users never get a rewarded offer or ad requests<br>`integration_test/app_test.dart`: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads | PASS |
| AC-47 | `test/edge_cases_test.dart`: AC-47 AC-49 the same screens in dark mode at 150% text<br>`test/settings_test.dart`: AC-47 theme follows the system by default and can be forced | PASS |
| AC-48 | `test/storage_test.dart`: AC-48 data is stored in a local database and survives a restart<br>`test/storage_test.dart`: AC-48 a database that cannot open shows a load error instead of crashing<br>`integration_test/app_test.dart`: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart<br>`integration_test/app_test.dart`: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart | PASS |
| AC-49 | `test/accessibility_test.dart`: AC-49 main screens at 200% text have no overflow, labelled 48dp targets ($plan)<br>`test/accessibility_test.dart`: AC-49 onboarding at 200% text<br>`test/accessibility_test.dart`: AC-49 empty trips and the trip form at 200% text<br>`test/edge_cases_test.dart`: AC-49 a 320x568 phone with long names, emoji, right-to-left text and huge amounts<br>`test/edge_cases_test.dart`: AC-47 AC-49 the same screens in dark mode at 150% text<br>`test/edge_cases_test.dart`: AC-49 a landscape phone shows the trip without overflow | PASS |
| AC-50 | `test/onboarding_test.dart`: AC-50 onboarding shows on first launch and Get started ends it<br>`test/onboarding_test.dart`: AC-50 onboarding can be skipped<br>`integration_test/app_test.dart`: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart | PASS |

## Edge cases tried

- Small phone (320 x 568 dp), 200 % text, 150 % text in dark mode, and
  landscape: no overflow on trips, expenses, the expense form, balances,
  stats, export, settings, premium, categories, onboarding and the trip form
  (`test/accessibility_test.dart`, `test/edge_cases_test.dart`). Tap targets
  meet Android's 48 dp and iOS's 44 pt guidelines and every tappable item
  has a label.
- Long names, emoji, Hebrew and Arabic names, and an amount of €1,234,567.89.
- Tapping Save twice fast on a trip, an expense and a category saves one.
- No network and no cached rate: the app opens; a published currency whose
  rate fetch fails shows "Couldn't get the rate…" with Try again.
- Restart mid-flow: data survives on the real SQLite database (emulator
  tests).
- The first database load fails: the error screen's Try again recovers and
  the launch checks (Premium, consent, ads, rates) still run.
- Storage write failures on delete and save show a message and keep data.
- Very large amounts (Rp 50,000,000, 1e15 minor units) and absurd rates.
- Corrupt or hand-edited backup files are rejected and change nothing.

## Bugs found and fixed while testing

1. Trip card: participant count overflowed at 200 % text (made flexible).
2. Stats: category rows overflowed at 200 % text and with very large amounts
   (amounts scale down; names keep most of the width).
3. Export sheet: the "Premium" badge overflowed at 200 % text (moved to the
   title line; the sheet scrolls).
4. Trip header title was dark on the dark teal header (now white).
5. Trip covers: the darkening scrim was painted over the title text, making
   it grey (scrim moved under the text).
6. Settings "Restore purchases" gave no feedback (now shows the outcome).
7. From the supervisor and the independent review: editing a trip could
   change its currency and corrupt balances (now locked); 64-bit overflow
   in splits of large amounts (BigInt); restore accepted impossible data;
   launch checks skipped after a load retry or when Premium lapsed; the
   rewarded cap ignored ads closed early; failed writes went unreported.

## Not verified

- The real Google UMP consent form, real AdMob ads and the real store
  purchase and trial flows: they need the owner's AdMob and store accounts.
  The app's handling of every outcome is tested with fakes.
- The iOS build: this factory has no Mac. Nothing iOS-specific was run.
- Number and date formats use English patterns (for example "€1,234.50",
  "11 Oct 2026") regardless of the phone's region. All app text is English,
  so this is consistent, but it is a known limit of version 1.0.

## Commands run

```
cd app
dart format lib test integration_test
flutter analyze --fatal-infos --fatal-warnings   -> No issues found!
flutter test                                     -> 00:41 +148: All tests passed!
cd .. && FACTORY_SKIP_APK=1 python -c "from factory import gates; from pathlib import Path; print(gates.build(Path('.')))"  -> []
```

The emulator run (`flutter test integration_test/app_test.dart` on an
Android emulator), the debug APK build and the screenshots are run by the
"Check an app" workflow; see `docs/CHECK_REPORT.md`.
