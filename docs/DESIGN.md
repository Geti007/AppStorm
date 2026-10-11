# Trippi: design

## 1. Direction

Calm, premium travel: deep lagoon teal, warm sand backgrounds and one coral
accent, like a well-made boarding pass or a boutique hotel's printed guide.
References are the restraint of good airline and banking apps: big confident
numbers, soft rounded cards, generous white space, no clutter. Groups use it
mid-trip, often tired and in a hurry, so money is always the largest thing on
screen and every action is one obvious tap away.

Material 3 components, themed with the colors below (`ColorScheme.fromSeed`
is not used; the scheme is built from brand.json so it never turns purple).

## 2. Foundations

### Colors (brand/brand.json)

| Role | Light | Dark |
|---|---|---|
| primary (buttons, active tab, links) | #0E6E74 | #5CC8C2 |
| on_primary | #FFFFFF | #00302F |
| secondary (accent: FAB, highlights) | #E8603F | #FF9A7E |
| on_secondary (text and icons on secondary) | #14232B | #2B1A14 |
| background | #F6F4EF | #0D171C |
| on_background | #14232B | #E6EEF0 |
| surface (cards, sheets) | #FFFFFF | #15232A |
| on_surface | #14232B | #E6EEF0 |
| error | #B3261E | #FFB4AB |

Derived: `onSurfaceVariant` light #4A5A61 / dark #A9B8BE (secondary text,
contrast 6.9:1 and 7.6:1). Outline light #D9D4CA / dark #2B3A41. Positive
balance ("gets back") light #1B7F4B / dark #6FD39B; negative balance ("owes")
uses `error`. Balances also carry a "+" or "−" sign and the words "gets back"
or "owes", so colour is never the only signal.

Category colours (icon on a 12% tint of the colour; every colour is at
least 3:1 against its theme's surface, as non-text graphics need). Each
built-in hue is distinct from the others and from primary:

| Category | Icon | Light | Dark |
|---|---|---|---|
| Accommodation | `bed` | #4F46E5 indigo | #A5B4FC |
| Food & drink | `restaurant` | #E8603F coral | #FF9A7E |
| Transport | `directions_bus` | #0284C7 sky blue | #7DD3FC |
| Activities | `local_activity` | #B7791F amber | #F6C453 |
| Shopping | `shopping_bag` | #B4237A magenta | #F49AC8 |
| Groceries | `local_grocery_store` | #4D7C0F lime green | #A3E635 |
| Other | `category` | #64748B slate | #CBD5E1 |

Custom categories pick from these 7 plus cyan #0891B2 / #67E8F9, violet
#7C3AED / #C4B5FD, red #DC2626 / #FCA5A5, brown #92400E / #E0B48A and
graphite #374151 / #9CA3AF (light / dark), and from 24 Material icons:
`bed`, `restaurant`, `local_cafe`, `local_bar`, `directions_bus`, `flight`,
`train`, `local_taxi`, `directions_car`, `local_gas_station`, `local_activity`,
`museum`, `beach_access`, `hiking`, `downhill_skiing`, `shopping_bag`,
`local_grocery_store`, `local_pharmacy`, `card_giftcard`, `wifi`,
`local_laundry_service`, `volunteer_activism`, `confirmation_number`,
`category`.

Trip cover styles (gradients for card headers): Lagoon #13898E→#0A4F57,
Sunset #F08A5D→#B83B5E, Forest #3C8D5A→#1E4D3A, Midnight #2E3A87→#141B3D,
Sand #E3C79A→#8A6238, Sky #5AB2E8→#2266A8. White text on all, checked ≥4.5:1
at the darker stop; a 35% black scrim at the bottom of the band keeps text
readable on the lighter stops (Lagoon top stop alone measures 4.2:1).

Premium accent themes (AC-38) replace primary and secondary only:
Lagoon (default brand colours), Sunset (#B83B5E / #F08A5D), Forest
(#2F6B47 / #D9A441), Midnight (#2E3A87 / #5CC8C2). Dark-mode primary /
secondary, with on_primary #0D171C: Lagoon #5CC8C2 / #FF9A7E, Sunset #F4A27F /
#F49AC8, Forest #7CC79A / #E6B95A, Midnight #9FA8F0 / #7FD6D0.

### Type

Font: **Plus Jakarta Sans** (SIL OFL), bundled: Regular 400, Medium 500,
SemiBold 600, Bold 700. Numbers use `FontFeature.tabularFigures()`.

| Style | Size/line | Weight | Use |
|---|---|---|---|
| displaySmall | 36/44 | 700 | Dashboard total, paywall price |
| headlineSmall | 24/32 | 700 | Screen titles (large app bar) |
| titleLarge | 20/28 | 600 | Card titles, section headers |
| titleMedium | 16/24 | 600 | List row titles, amounts |
| bodyLarge | 16/24 | 400 | Form fields, body |
| bodyMedium | 14/20 | 400 | Secondary lines |
| labelLarge | 14/20 | 600 | Buttons |
| labelSmall | 12/16 | 500 | Chips, "Sponsored", captions |

### Spacing, shape, elevation

- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 48. Screen padding 20 horizontal.
- Radii: cards 20, sheets 28 (top), buttons 14, chips and fields 12, avatars round.
- Elevation: cards use no shadow in dark mode and a soft shadow in light
  (0 4 16 rgba(20,35,43,0.06)); the FAB uses Material level 3.
- Avatars: 36 dp circle with the person's initials, colour picked from the
  category palette by name hash.

## 3. Navigation

`trips` is the root. Gear icon (top right, label "Settings") opens
`settings`. A trip opens `trip_dashboard` with three tabs (Expenses,
Balances, Stats) under a collapsing header. Forms (`trip_form`,
`expense_form`, `settle`) open as full-screen pages with a close icon
(label "Close") and a primary button pinned to the bottom. `export` is a
modal bottom sheet. `premium` is a full-screen page.

## 4. Screens

Plurals: every count uses singular and plural forms: "1 expense" / "<N>
expenses", "1 person" / "<N> people", "1 trip" / "<N> trips", "1 expense
uses this category" / "<N> expenses use this category".

All amounts are formatted with the device locale, the currency symbol and the
currency's minor unit. Long names wrap to two lines and then ellipsise.
Every list has a loading state (3 shimmering skeleton cards, 1.2 s loop)
while the database opens; the database is local so this is normally a flash.
Database errors show the shared error state: icon `error_outline`, title
"Something went wrong", body "Your data is safe on this phone. Please try
again.", button "Try again".

### onboarding

Three pages with a page indicator, "Skip" (top right) and a primary button.
Each page: an illustration drawn in code (simple shapes in brand colours),
title, one line.

1. Illustration: three overlapping avatars and a receipt. Title "Split costs
   with your travel crew". Body "Add who paid, choose how to split, done."
   Button "Next".
2. Illustration: two coins with currency symbols and a curved arrow. Title
   "Any currency, one total". Body "Spend in yen, euros or pesos. Trippi
   converts everything to your trip's currency." Button "Next".
3. Illustration: a checkmark inside a circle with confetti dots. Title
   "Settle up in fewer payments". Body "Trippi works out who pays whom with
   the fewest transfers." Button "Get started".

"Skip" and "Get started" both go to `trips` and never show onboarding again.
No ads.

### trips

- Large app bar: title "Trippi", subtitle line "Your trips", gear icon.
- List of trip cards, newest first (AC-8). Card: cover gradient band (88 dp
  high) with the trip name (titleLarge, white) and dates ("12 – 19 Aug 2026",
  or nothing if unset); below, on the surface: "Total" label with the amount
  in base currency (titleMedium), and a row of up to 4 avatars plus "+N" and
  "N people". Long-press or the overflow icon (label "Trip options") offers
  "Edit trip" and "Delete trip".
- Native ad card (AC-43) after the 2nd trip, same radius and padding as a
  trip card, with a "Sponsored" chip (labelSmall on secondary tint) top left.
  If no ad is loaded, nothing is inserted.
- Upgrade card (AC-41c), dismissible with a close icon (label "Dismiss"):
  title "Trip settled!", body "Go Premium for unlimited trips, PDF and Excel
  exports, and no ads.", button "See Premium".
- Extended FAB (secondary colour) "New trip" with icon `add`.
- Empty state (AC-1): illustration of a suitcase with a map pin; title "No
  trips yet"; body "Create a trip, add your travel crew, and start tracking
  shared costs."; button "Create your first trip". The FAB is hidden.
- Delete confirmation dialog: title "Delete this trip?", body "<Trip name>
  and all its expenses and payments will be deleted. This can't be undone.",
  buttons "Cancel" and "Delete" (error colour).

### trip_form

- App bar: close icon; title "New trip" or "Edit trip".
- Fields, top to bottom:
  - "Trip name" (helper "Up to 40 characters", counter shown).
  - "Dates (optional)": a field that opens the date range picker; clear icon
    (label "Clear dates") when set.
  - "Trip currency": tappable field showing "EUR · Euro" that opens the
    currency picker sheet; helper "All totals are shown in this currency."
  - "Cover": horizontal row of 6 cover swatches (48 dp circles, selected one
    with a check and a 2 dp ring), each labelled for screen readers by name.
  - "Travel crew" header with "N people". Each person is a row with avatar,
    name and a remove icon (label "Remove <name>"). A text field "Add a
    person" with an add button (label "Add person"); Enter also adds.
- Errors under the person field: "Name already in this trip" (AC-3),
  "Enter a name". When removal is blocked (AC-4) a snackbar says "<Name> is
  part of expenses or payments in this trip, so they can't be removed."
- Hint under the crew list when fewer than 2 people: "Add at least 2 people
  to split costs."
- Bottom button "Create trip" / "Save changes", disabled until valid (AC-2).
- Reaching the free participant limit (AC-7): tapping "Add person" with 6
  people opens `premium` (from: participant limit).

### Currency picker (sheet used by trip_form, expense_form, settings)

Search field "Search currencies" at the top, then "Recent" (up to 5) and "All
currencies" sections. Row: code (titleMedium), name, symbol at the end, and
a small "Auto rate" chip for currencies the rate service publishes. No
results: "No currency matches \"<query>\"".

### trip_dashboard

- Collapsing header with the cover gradient: back arrow, trip name, actions
  share (label "Share or export") and edit (label "Edit trip").
- Header stats (AC-27), white on the gradient: "Total spent" with the amount
  (displaySmall), then two inline stats: "<N> expenses" and "<amount> avg per
  person". With no expenses yet the header shows the total as 0.00 in the
  trip currency, "0 expenses" and "0.00 avg per person" (formatted in the
  currency).
- Tabs: "Expenses", "Balances", "Stats".
- FAB "+" (label "Add expense") on the Expenses and Balances tabs, opening
  `expense_form`.

#### Expenses tab

- Search field "Search expenses" (AC-16); clear icon (label "Clear search").
- Groups by day with a sticky header ("Today", "Yesterday", or "Mon, 12 Aug").
- Row: category icon in a tinted circle, title, "Paid by <name>", amount in
  expense currency (titleMedium) and, when it differs, "≈ <base amount>"
  beneath (bodyMedium, onSurfaceVariant).
- Native ad card after every 10th expense, at most 2 (AC-43).
- Swipe left to delete, or tap to edit. After deleting: snackbar "Expense
  deleted" with "Undo" for 4 seconds (AC-15).
- Empty state: illustration of a receipt; title "No expenses yet"; body "Add
  the first thing someone paid for, like a hotel, dinner or taxi."; button
  "Add expense".
- No search results: "No expenses match \"<query>\"".

### expense_form

- App bar: close icon; title "Add expense" or "Edit expense"; delete icon
  (label "Delete expense") when editing. Delete dialog: "Delete this
  expense?", "Cancel" / "Delete".
- Amount block on top: currency button ("EUR") opening the currency picker,
  and a large amount field (displaySmall) with numeric keyboard; error
  "Use up to <n> decimals for <CODE>" when too many decimals (AC-9).
- Rate row (only when currency ≠ trip currency): "1 USD = 0.9214 EUR · rate
  from 10 Oct 2026" with "Edit" (opens a numeric field "Exchange rate").
  While fetching: small progress indicator and "Getting today's rate…". No
  rate (AC-19): warning text "No rate available offline. Enter the rate."
  with the field open. Premium action (AC-21): text button "Use the rate on
  the expense date"; locked for free users with a lock icon, opening
  `premium` (from: historical rate). Fetch error: "Couldn't get the rate.
  Check your connection or enter it yourself." with "Try again".
- "What was it for?" title field (max 60).
- Category: horizontal chips with icon and name; selected chip filled.
- "Date": date field, defaults to today.
- "Paid by": single-select avatar chips.
- "Split" segmented button: "Equally", "By %", "By amount".
  - Equally: a checkbox row per person with their share shown live
    ("€12.34"); "Select all" toggle.
  - By %: a numeric field per person with "%" suffix and the share amount;
    a live line "Remaining: 15%" (error colour when not 0, AC-11).
  - By amount: a numeric field per person; live line "Remaining: €4.20"
    (AC-12).
- "Note (optional)" multi-line field.
- Bottom button "Save expense", disabled until valid; it never shows any
  upgrade prompt (AC-41).

#### Balances tab

- Section "Balances": a row per person with avatar, name, and the amount
  with sign and words: "+€42.10 gets back" (positive colour) or "−€18.00
  owes" (error colour) or "Settled" (onSurfaceVariant).
- Section "Suggested payments" (AC-23): rows "Ana → Ben" with amount and a
  tonal button "Settle" (label "Settle <amount> from Ana to Ben").
- Text button "Record payment" (opens empty `settle`).
- Section "Payment history" (AC-25): rows with date, "Ana paid Ben", amount;
  overflow "Delete payment" with dialog "Delete this payment?" / "Cancel" /
  "Delete".
- All settled (AC-26): the suggestions section is replaced by a card with a
  confetti burst (800 ms, plays once per visit), check icon, title "All
  settled up", body "Everyone is even. Nice trip!".
- Empty (no expenses): title "Nothing to settle yet", body "Balances appear
  once you add an expense."

### settle

- App bar: close icon; title "Record payment".
- "From" and "To" person dropdowns (cannot be the same person; error "Choose
  two different people").
- "Amount" in trip currency, prefilled from the suggestion. Errors: "Enter
  an amount greater than 0", and "Use up to <n> decimals for <CODE>" as in
  `expense_form`. A trip always has at least 2 people (AC-2), so both
  dropdowns always have choices.
- "Date" defaults to today.
- Bottom button "Save payment", disabled until valid. On save, return to
  Balances with snackbar "Payment recorded". If saving fails: snackbar
  "Couldn't save the payment. Please try again." and the form stays open.

#### Stats tab

- Card "Spending by category" (AC-28): donut chart (160 dp) with the total in
  the middle, legend rows below: icon, name, amount, percentage. Chart
  semantics label: "Spending by category: Food & drink 34%, …".
- Card "Daily spending" (bar chart), card "Who paid and who spent" (paired
  bars per person: Paid vs Share), card "Top 5 expenses" (list). For free
  users without a Pass these three are blurred (sigma 8) under one overlay
  card: lock icon, title "See where the money went", body "Daily spending,
  who paid what, and your biggest expenses.", button "Unlock with Premium"
  (opens `premium`, from: advanced stats).
- Empty (AC-30): title "No stats yet", body "Add expenses to see where the
  money goes."

### export (bottom sheet)

Title "Share or export". Three rows with icon, title and subtitle:
- "Share summary" / "Plain text for any chat app" (free).
- "Export PDF" / "Summary, balances and all expenses" with a "Premium" chip
  when locked.
- "Export Excel" / "Expenses, balances and payments sheets" with a
  "Premium" chip when locked.
Locked rows open `premium` (from: export). While a file is being made, the
row shows a progress indicator and "Preparing…". Failure: snackbar "Couldn't
create the file. Please try again."

Text summary format:
```
Trippi · <Trip name>
Total: <amount> (<N> expenses)

Balances
Ana: gets back €42.10
Ben: owes €18.00

To settle up
Ben pays Ana €18.00
```

### premium

- Close icon top left. Hero: the Trippi pin mark on a lagoon gradient with
  title "Trippi Premium" and subtitle "Travel together. Split smarter."
- Benefits list with check icons: "No ads", "Unlimited trips and people",
  "Advanced stats", "PDF and Excel export", "Historical exchange rates",
  "Custom categories", "Back up to a file", "Premium themes".
- Price block (AC-34): when eligible for the trial, "Free for 7 days" (titleLarge)
  and "then <price>/month starting <date>"; button "Start free trial".
  Otherwise "<price>/month"; button "Subscribe".
- Small text: "Renews automatically each month until cancelled. Cancel
  anytime in your <App Store / Google Play> subscription settings."
- Text button "Restore purchases". Links row: "Privacy policy" · "Terms of
  use" (+ "Apple EULA" on iOS only).
- Rewarded offer (AC-45) only when opened from a Pass feature: an outlined
  card with play icon: "Watch a short video for a free 24-hour Premium Pass"
  and button "Watch video". Disabled state text "No video available right
  now". Active Pass: "Premium Pass active until <time, day>".
- Loading: skeleton for the price block and "Loading prices…".
- Store unavailable (AC-35): "Premium isn't available right now" with button
  "Try again"; no Subscribe button.
- Purchase pending: button shows a spinner and is disabled. Cancelled:
  nothing changes. Error: snackbar "Purchase didn't go through. You weren't
  charged." Success: page closes with snackbar "Welcome to Premium!".
- Restore with nothing to restore: snackbar "No previous purchase found."

### settings

Grouped list sections:
- "Appearance": "Theme" (System / Light / Dark segmented button); "Accent
  theme" with 4 swatches (Lagoon, Sunset, Forest, Midnight), locked ones show
  a lock and open `premium` (from: themes).
- "Trips": "Default currency" (opens currency picker); "Categories" (opens
  `categories`, Premium; locked opens `premium` from: categories).
- "Your data": "Back up" ("Save all trips to a file") and "Restore"
  ("Replace data from a backup file"); Premium-locked rows open `premium`
  (from: backup). Restore preview dialog: title "Restore this backup?", body
  "This file has <N> trips and <M> expenses, saved <date>. It will replace
  everything on this phone.", buttons "Cancel" / "Restore". Invalid file:
  dialog "This isn't a Trippi backup" / "OK".
  Back up: the row shows a progress indicator and "Preparing backup…", then
  the share sheet opens with the file `trippi-backup-<yyyy-mm-dd>.json`; if
  the file can't be made, snackbar "Couldn't create the backup. Please try
  again." Restore: after "Restore", snackbar "Backup restored" and the trips
  list reloads; if reading or writing fails, dialog "Couldn't restore this
  backup. Nothing was changed." / "OK". Cancelling the file picker does
  nothing.
- "Premium": when free, "Get Premium" row; when Premium, "Premium active"
  plus "Manage subscription" (AC-37). Always "Restore purchases".
- "Privacy": "Privacy options" (only when UMP requires it, AC-42); "Privacy
  policy"; "Terms of use".
- "About": "Version <x.y.z>", "Made for travel crews".
No ads.

### categories

- App bar title "Categories", FAB "New category".
- Section "Built-in": the 7 built-in categories with icon and colour, no
  edit or delete controls. Section "Your categories": custom ones with edit
  (label "Edit <name>") and delete (label "Delete <name>") icons.
- Editor sheet: title "New category" or "Edit category"; "Name" field (max 24
  characters), icon grid, colour row; button "Save", disabled until valid.
  Errors: "Enter a name"; "A category with this name already exists"
  (case-insensitive, including built-in names).
- Delete of an unused custom category: dialog "Delete <name>?" / "Cancel" /
  "Delete".
- Delete blocked (AC-39): dialog "Category in use" / "<N> expenses use this
  category. Move them to another category first." / "OK".
- Empty custom list: "Create categories like \"Ski pass\" or \"Tips\"."

### privacy and terms

Scrollable text pages with headings (titleMedium) and paragraphs, padding 20.
Terms page on iOS ends with a link "Apple Standard End User License
Agreement". The privacy text matches `store/privacy-policy.html`.

## 5. Motion

- Page transitions: Material shared-axis (horizontal) 300 ms; forms slide up
  250 ms.
- Header collapse follows scroll. Tab change 200 ms.
- Balance numbers animate (count) over 400 ms when they change.
- Settled confetti 800 ms once. Skeleton shimmer 1.2 s loop.
- All motion is skipped when the system "reduce motion" setting is on.

## 6. Dark mode

Supported, following the system by default (AC-47), with the dark colours in
brand.json. Cover gradients stay the same; cards lose shadows and gain a 1 dp
outline.

## 7. Accessibility

- Every icon button has a label as listed above; charts expose a text
  summary; avatars read the full name.
- Touch targets at least 48 × 48 dp, including swatches and chips.
- Text scales to 200%: the dashboard header stats wrap to two lines, amount
  rows stack the base amount below, buttons grow in height, nothing clips.
- Text contrast ≥ 4.5:1 in both themes; balances use sign and words, not
  colour alone; categories use icon plus colour.
