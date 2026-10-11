# Trippi: specification (version 1.0)

## 1. Summary

Trippi is for friends, couples and groups who travel together and share costs.
It records who paid for what during a trip, in any currency, and tells everyone
exactly who owes whom with the fewest possible payments.

## 2. Decisions made for you

- **No accounts, no server in 1.0.** Everything is stored on the phone and works
  fully offline. One person (the organiser) records the trip on their phone.
  "Inviting" participants means adding them by name and sending them the trip
  summary through any messaging app. Real-time shared trips and
  cross-device sync need a server and sign-in; they are planned for a later
  version and are not mentioned in the store listing or the app.
- **Receipt scanning is left out of 1.0.** Doing it well needs on-device text
  recognition per store and more testing than this version allows. It is not
  advertised anywhere until it ships.
- **"Cloud backup" becomes backup to a file in 1.0** (Premium): the app writes
  one backup file that the user saves wherever they like (Files, Google Drive,
  iCloud Drive, email) through the system share sheet, and can restore it later.
- **Currencies:** a bundled offline ISO 4217 list (code, name, symbol, minor
  unit) of all current currencies. Amounts, rounding and the "settled" check use
  each currency's minor unit (0 decimals for JPY and KRW, 3 for KWD and BHD, 2
  for most). "Cent" below means one minor unit.
- **Exchange rates** come from the free Frankfurter API (European Central Bank
  reference rates, about 30 major currencies, no key; `api.frankfurter.dev/v1`,
  falling back to `api.frankfurter.app`). Currencies in that set are marked
  "auto rate"; every other currency needs a rate typed by hand. The last rates are cached
  for offline use. Any rate can be typed in by hand, which also covers
  currencies the ECB does not publish.
- **Free limits:** 3 trips and 6 participants per trip. Everything needed to
  split a trip fairly is free: all three split methods, multi-currency,
  balances, simplified debts, settle-up, payment history, the category
  dashboard, sharing a text summary, light and dark mode.
- **Rewarded ad reward:** a 24-hour Premium Pass that unlocks advanced
  analytics, exports, historical rates and themes (not ad removal, not limits).
  At most 3 rewarded ads per day.
- **Subscription:** one product, `trippi_premium_monthly`, monthly auto-renewing,
  $1.99 base price, 7-day free trial set up as an introductory offer in App Store
  Connect and Play Console by the owner. The app always shows the price and
  trial text the store returns (localised), never a hard-coded price.
- **Words the app never uses in 1.0.** The store listing, onboarding and paywall
  never say "invite", "sync", "cloud" or "scan receipts". The Premium benefit
  list is exactly what 1.0 ships: no ads, unlimited trips and participants,
  advanced stats, PDF and Excel export, historical rates, custom categories,
  backup to a file, themes.
- **Ads on iOS are always non-personalised in 1.0**, so the app does not track
  on iOS and needs no App Tracking Transparency prompt. On Android, ads are
  personalised only when the UMP consent allows it.
- **Terms of use** are a short in-app `terms` screen on both platforms (what
  the app does, that data stays on the device, how the subscription renews and
  is cancelled, no warranty for calculations or exchange rates). On iOS the
  screen and the paywall also link to Apple's Standard End User License
  Agreement (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/);
  on Android there is no Apple link. The privacy policy is shown inside the app and must also be
  published at a public URL by the owner for both store listings.
- **Package id** `com.geti007.trippi`. Display name "Trippi".
- **iPhone only** on iOS (runs on iPad in iPhone mode), Android phones and tablets.

## 3. Scope

In 1.0: everything in sections 5 and 6.
Left out (later versions): accounts, shared live trips, sync across devices,
receipt scanning, recurring expenses, itemised bill splitting.

## 4. Screens

| Id | Screen | How you get there |
|----|--------|-------------------|
| `onboarding` | Three-page welcome (split, currencies, settle), then "Get started" | First launch only |
| `trips` | Home: list of trips (cards with cover colour, dates, total, number of participants), "New trip" button | Launch after onboarding |
| `trip_form` | Create or edit a trip: name, dates (optional), base currency, cover style, participants | "New trip", or Edit on a trip |
| `trip_dashboard` | One trip: header with total spent, number of expenses, and the average per participant; tabs Expenses, Balances, Stats | Tap a trip |
| `expense_form` | Add or edit an expense: title, amount, currency, rate, category, date, paid by, split method and shares, note | "+" on the trip dashboard, or tap an expense |
| `balances` | Balances tab: each person's net balance, simplified "who pays whom" list with "Settle" buttons, payment history | Balances tab |
| `settle` | Record a payment: from, to, amount (prefilled), date | "Settle" on a suggested payment, or "Record payment" |
| `stats` | Stats tab: spending by category (donut chart, free); daily spending bar chart, spending by person (paid vs share), and the top 5 expenses (Premium or Premium Pass) | Stats tab |
| `export` | Choose: share text summary (free), PDF, Excel (Premium) | Share button on the trip dashboard |
| `premium` | Paywall: benefits, price and trial from the store, Subscribe, Restore, terms | Any locked feature, upgrade cards, Settings |
| `settings` | Theme mode (system/light/dark), premium theme, default currency, categories, backup and restore, privacy options (ads), manage subscription, restore purchases, privacy policy, terms, about | Gear icon on `trips` |
| `categories` | Manage custom categories (Premium) | Settings |
| `privacy` | Privacy policy text inside the app | Settings, paywall |
| `terms` | Terms of use text inside the app (plus Apple's Standard EULA link on iOS only) | Settings, paywall |

States every screen handles: first use (empty), loading, error (with retry
where it applies), and long text.

## 5. Features and acceptance criteria

### Trips

- AC-1: Given no trips, the `trips` screen shows an illustrated empty state with a "Create your first trip" button that opens `trip_form`.
- AC-2: Creating a trip requires a non-empty name (max 40 characters) and at least 2 participants; Save stays disabled until both hold, and the new trip appears at the top of `trips`.
- AC-3: Participant names must be unique within a trip (case-insensitive) and non-empty (max 24 characters); a duplicate shows "Name already in this trip".
- AC-4: Editing a trip changes its name, dates, cover and participants; a participant who is part of any expense or payment cannot be removed, and the app says why.
- AC-5: Deleting a trip asks for confirmation and then removes the trip with all its expenses and payments.
- AC-6: On the free plan, creating a 4th trip opens the `premium` screen instead of `trip_form`; Premium users can create any number of trips.
- AC-7: On the free plan, adding a 7th participant to a trip opens the `premium` screen; Premium users have no limit.
- AC-8: Trips are listed newest first and each card shows the trip name, dates (if set), total spent in the base currency, and number of participants.

### Expenses

- AC-9: An expense needs a title (max 60 characters), an amount greater than 0 with no more decimals than the currency's minor unit allows, a payer, and at least one person in the split; Save stays disabled otherwise.
- AC-10: Split equally divides the amount among the selected people; any remaining cent goes to the first selected people so the shares add up exactly to the amount.
- AC-11: Split by percentage requires the percentages to add up to 100 (the form shows the remaining percentage live and blocks Save otherwise); shares are rounded to the currency's minor unit, any leftover unit goes to the first selected people, and the shares add up exactly to the amount.
- AC-12: Split by custom amounts requires the amounts to add up exactly to the expense amount (the form shows the remaining amount live and blocks Save otherwise).
- AC-13: Every expense has one category from: Accommodation, Food & drink, Transport, Activities, Shopping, Groceries, Other, plus any custom categories; the category shows as an icon and colour in lists and charts.
- AC-14: Expenses are listed newest date first, grouped by day, each row showing title, category icon, payer, amount in the expense currency, and the base-currency amount when the currencies differ.
- AC-15: Editing an expense updates balances and totals immediately; deleting asks for confirmation and can be undone from a snackbar for 4 seconds.
- AC-16: Searching the expense list by title filters it as you type; clearing the search shows all expenses.

### Currencies

- AC-17: Each trip has a base currency; each expense can be in any currency from the bundled ISO 4217 list (searchable by code and name), and every total and balance is shown in the base currency, rounded to its minor unit.
- AC-18: When the expense currency differs from the base currency, the form fills in the latest rate (fetched online, or the cached rate when offline) and shows its date; the user can overwrite the rate by hand.
- AC-19: When no rate is available (offline and never fetched, or a currency the rate service does not publish), the form asks for the rate by hand and Save stays disabled until a rate greater than 0 is entered.
- AC-20: The rate used is stored with the expense, so later rate changes never change past expenses.
- AC-21: Premium (or Premium Pass): the form offers "Use the rate on the expense date" which fetches the historical rate for that date.

### Balances and settling

- AC-22: Each participant's balance = what they paid − their shares + payments they made − payments they received, in the base currency, and all balances add up to 0.
- AC-23: The "who pays whom" list is simplified: debtors and creditors are matched largest first, so there are at most (people − 1) payments, and doing all of them brings every balance to 0.
- AC-24: Tapping "Settle" on a suggested payment opens `settle` prefilled with the payer, receiver and amount; saving records the payment and the balances update.
- AC-25: Payment history lists every recorded payment (date, from, to, amount) and a payment can be deleted with confirmation.
- AC-26: When every balance is 0 (within one minor unit of the base currency), the Balances tab shows "All settled up" with a celebration animation.

### Dashboard and stats

- AC-27: The trip dashboard header shows total spent, number of expenses, and the average per participant, in the base currency.
- AC-28: The Stats tab shows a donut chart of spending by category with a legend of amounts and percentages (free).
- AC-29: Premium (or Premium Pass): the Stats tab also shows a daily spending bar chart, spending by person (paid vs share), and the top 5 expenses; free users see these sections blurred behind an "Unlock with Premium" card.
- AC-30: With no expenses, the Stats tab shows an empty state instead of empty charts.

### Sharing and exports

- AC-31: "Share summary" (free) opens the system share sheet with a plain-text summary: trip name, total, each balance, and the simplified payments.
- AC-32: Premium (or Premium Pass): "Export PDF" creates a PDF with the summary, balances, payments and the full expense list, and opens the share sheet.
- AC-33: Premium (or Premium Pass): "Export Excel" creates an .xlsx file with sheets Expenses, Balances and Payments, and opens the share sheet.

### Premium

- AC-34: The `premium` screen lists the Premium benefits and the monthly price as returned by the store. When the store reports the user is eligible for the 7-day introductory offer, it shows "Free for 7 days, then <store price>/month starting <date 7 days from today>" and a "Start free trial" button; otherwise it shows "<store price>/month" and a "Subscribe" button. It also shows "Restore purchases", and links to the privacy policy and terms of use. It states that the subscription renews automatically each month until cancelled and can be cancelled in the store's subscription settings.
- AC-34a: Trial eligibility comes from the store (on iOS, the introductory-offer eligibility check; on Android, whether the free-trial offer is returned for the user); the app never offers a trial the store would not grant.
- AC-35: When the store is unavailable or returns no product, the `premium` screen shows "Premium isn't available right now" with a retry button and no Subscribe button.
- AC-36: A successful purchase or restore turns Premium on immediately: ads disappear and every Premium feature unlocks; Premium status survives an app restart and is re-checked with the store at launch.
- AC-37: Settings has "Manage subscription", which opens the store's subscription management page.
- AC-38: Premium (or Premium Pass) themes: choosing one of 4 accent themes (Lagoon, Sunset, Forest, Midnight) recolours the app; free users without a Pass see them locked.
- AC-39: Custom categories (Premium): create, rename and delete categories with a name, icon and colour; a category in use cannot be deleted until its expenses move to another category.
- AC-40: Backup (Premium): "Back up" writes one file with all trips and opens the share sheet; "Restore" reads such a file, shows what it contains, and after confirmation replaces the current data; an invalid file shows an error and changes nothing.
- AC-40a: When Premium lapses or a Premium Pass ends: all existing trips, participants, expenses and payments stay fully viewable and editable; only creating new trips or participants beyond the free limits is blocked; expenses keep their custom categories, but categories can't be added or edited; the theme falls back to the default; locked stats and exports lock again. Premium status is re-checked with the store at launch and when the app returns to the foreground, and the cached status is used while offline.
- AC-41: Upgrade prompts appear only (a) when a free limit is reached, (b) when a locked feature is tapped, (c) as one dismissible card on the trips list after the user's first fully settled trip, never more than once per 7 days. No prompt ever appears while adding an expense, splitting or settling.

### Ads (free plan only)

- AC-42: At launch, consent information is requested with Google's UMP SDK and the consent form is shown when required; no ad is requested until `canRequestAds` is true. Settings shows "Privacy options" when the SDK says it is required.
- AC-43: A native ad card labelled "Sponsored" appears on the `trips` list after the 2nd trip (only when there are at least 2 trips) and in the expense list after every 10th expense (at most 2 per list), styled like the app's cards. When it fails to load or the phone is offline, no gap is left.
- AC-44: No ad appears on onboarding, `trip_form`, `expense_form`, `settle`, `premium`, `settings`, `export`, empty states or error states. The app shows no interstitial ads.
- AC-45: The rewarded ad is offered only on the `premium` screen when it was opened from a feature the Pass unlocks (advanced stats, PDF or Excel export, historical rate, premium themes), as "Watch a short video for a free 24-hour Premium Pass"; the reward is stated before the ad starts; at most 3 per day; the Pass is granted only on the ad SDK's reward callback, and after the reward the Pass is active for 24 hours and shown with its end time. When no rewarded ad is loaded (offline, no fill, or the daily cap is reached) the offer shows "No video available right now" and is disabled; a failed or closed ad never blocks the paywall or the feature.
- AC-45a: When the `premium` screen is opened from the trip limit, the participant limit, custom categories, backup, Settings or an upgrade card, it shows no rewarded-ad offer at all.
- AC-34b: The `terms` screen opens from Settings and the paywall on both platforms; the Apple Standard EULA link appears on iOS only.
- AC-46: Premium users never see, load or request ads; a Premium Pass does not remove ads.

### General

- AC-47: Light and dark mode follow the system by default and can be forced in Settings.
- AC-48: All data stays on the device in a local database and survives an app restart; nothing is sent anywhere except exchange-rate requests (currency codes and dates only) and, on the free plan, Google AdMob ad requests.
- AC-49: Every screen works with text scaled to 200% without overflow, every icon button has a screen-reader label, and touch targets are at least 48 dp.
- AC-50: Onboarding is shown on first launch only and can be skipped.

## 6. Data

Stored locally (SQLite): trips, participants, expenses (with their shares,
currency and rate), payments, custom categories, settings, cached exchange
rates, Premium status cache, Premium Pass end time, rewarded ad count per day.
Uninstalling the app deletes everything; a Premium backup file is the only way
to keep data across devices or reinstalls.

## 7. Privacy

- The app collects no personal data on a server. Names and amounts stay on the device.
- Exchange-rate requests to the Frankfurter API send only currency codes and dates.
- Free plan: Google AdMob may collect device identifiers, IP address and
  ad-interaction data for advertising, subject to the consent given in the UMP
  form. Premium users send nothing to AdMob.
- Purchases are handled by Apple and Google; the app never sees payment details.
- **Google Play Data safety** (follows Google's published disclosure list for
  the Mobile Ads SDK): Data collected: Location (Approximate location, from IP
  address), App activity (App interactions), App info and performance (Crash
  logs, Diagnostics), Device or other IDs. Collected by the Google Mobile
  Ads SDK, for Advertising or marketing and Fraud prevention. Data is encrypted
  in transit. Not shared beyond that SDK. Users can't request deletion from the
  app because the app holds no account data.
- **Apple privacy labels:** Data Not Linked to You (follows Google's published
  list for the Mobile Ads SDK): Location (Coarse Location), Identifiers (Device
  ID), Usage Data (Product Interaction, Advertising Data), Diagnostics (Crash
  Data, Performance Data, Other Diagnostic Data); purpose
  Third-Party Advertising. **Not used to track you** (iOS ads are always
  non-personalised and the app never requests the IDFA).
- The store writer checks both entries against Google's current Mobile Ads SDK
  disclosure pages and copies their data types, purposes (including Analytics
  where listed) and the "shared" answers exactly.

## 8. Ads

- `ads: true`. Placements: native ad (AC-43) and rewarded ad (AC-45). No banners, no interstitials.
- Frequency: native ads at most 2 per screen and refreshed at most once per minute; rewarded at most 3 per day, only on request.
- Quiet zones: everything in AC-44.
- Ad units for the owner to create in AdMob: `trippi_native_lists` (Native advanced), `trippi_rewarded_pass` (Rewarded), for Android and iOS.
- Audience: general adults; maximum ad content rating **G**. Block the categories Gambling, Dating, Alcohol, Politics, Religion, and Sensitive financial products (cash advances, debt services) to keep the finance context trustworthy.

## 9. Store

- Google Play category: Travel & Local. App Store: Travel (primary), Finance (secondary).
- Expected rating: Everyone / 4+. No user-generated content shared with others, no gambling, ads rated G.
- Subscription: auto-renewable `trippi_premium_monthly`, $1.99/month, 7-day free trial for new subscribers.

## 10. Accessibility

Dynamic text up to 200%, screen-reader labels on all icons and charts (each
chart has a text summary), 48 dp touch targets, 4.5:1 text contrast in both
themes, no information carried by colour alone (categories also have icons).
