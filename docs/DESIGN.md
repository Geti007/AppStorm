# Glassful: design

## Visual direction

Calm, clean and fresh, like a glass of cold water on a bright morning: deep
water blue, an aqua accent and lots of white space. References are modern
health apps that use one big progress visual and very few controls. It suits
people who want a two-second habit, not a dashboard.

## Foundations

- Font: Nunito (SIL Open Font License), bundled at `app/assets/fonts/`.
  Rounded letterforms feel friendly without being childish.
- Type scale (Material 3 roles): displaySmall 36/44 bold for the big total;
  headlineSmall 24/32 bold for the onboarding title;
  titleLarge 22/28 bold for screen titles; titleMedium 16/24 semibold;
  bodyLarge 16/24; bodyMedium 14/20; labelLarge 14/20 semibold for buttons.
- Spacing scale: 4, 8, 12, 16, 24, 32. Screen padding 16 (24 on onboarding).
- Corner radii: cards 20, buttons 16, dialogs 24, chips 12.
- Elevation: cards are flat (elevation 0) with a 1 dp outline in light mode
  (`#DCE6EE`) and a surface tone in dark mode. The bottom navigation bar uses
  the surface color.
- Colors: from `brand/brand.json`, light and dark. Primary for the progress
  ring and filled buttons; secondary (aqua) for the water fill and today's
  bar in the chart; muted for secondary text.

## Screens

### Bottom navigation (Today, History, Settings)
A Material 3 `NavigationBar` on the surface color with three destinations:
"Today" (icons water_drop_outlined / water_drop), "History" (bar_chart_outlined
/ bar_chart) and "Settings" (settings_outlined / settings). The indicator is
primary at 16% opacity; the selected icon and label use primary. Each
destination's label is its screen-reader label. Not shown on onboarding.

### Loading (launch)
A centred `CircularProgressIndicator` on the background color. No text, no ad.

### Error (saved data unreadable)
The app opens normally with empty data and shows a snackbar:
"Couldn't read saved data. Starting fresh."

### onboarding
Top to bottom, 24 padding, scrollable:
1. The app symbol: a glass drawn in code, 96 dp, primary color.
2. Title "Welcome to Glassful" (headlineSmall).
3. Body "Set a daily water goal. You can change it any time in Settings."
4. Segmented button: "ml" | "fl oz" (key `unit_toggle`).
5. Number field labelled "Daily goal", suffix "ml" or "fl oz", pre-filled
   2000 (or 68 in fl oz). Error text when out of range:
   "Enter a goal between 500 and 6000 ml" (or "Enter a goal between 17 and 202 fl oz").
6. Filled button full width "Start tracking" (key `start_button`).

### today (tab 1, title "Today")
1. App bar title "Today", with the date below in bodyMedium muted, for example
   "Tuesday, 14 October".
2. Progress card: a ring 200 dp wide, 16 dp stroke, primary on a 15% primary
   track. Inside: the percentage ("50%", displaySmall) and below it
   "1000 / 2000 ml" (bodyLarge). The percentage shows the real value, so it
   can go above 100% (for example "125%") while the ring stays full. With no
   drinks: "0%", "0 / 2000 ml" and an empty ring. When the goal is reached the ring is full and
   a chip under the card reads "Goal reached" with a check icon, secondary
   color. Semantics label: "1000 of 2000 millilitres, 50 percent".
3. Row "Add a drink" (titleMedium).
4. Four buttons in a 2 by 2 grid, each 64 dp tall, outlined tonal style with a
   glass icon and the amount: "150 ml", "250 ml", "500 ml", "Custom". Keys
   `add_150`, `add_250`, `add_500` (by ml value; 6, 8, 16 fl oz map to keys
   `add_177`, `add_237`, `add_473`) and `add_custom`.
5. "Today's drinks" (titleMedium), then a list of entries, newest first:
   leading glass icon, title amount ("250 ml"), subtitle time ("9:41 AM", the
   phone's 12 or 24 hour format), trailing delete icon button with tooltip
   "Delete 250 ml drink at 9:41 AM".
6. Empty state (no drinks today): in place of the list, muted body text
   "No drinks yet today. Tap a glass to start."
After any add, a snackbar "Added 250 ml" with action "Undo".

### custom_amount (dialog over Today)
Title "Custom amount". A number field, autofocused, labelled "Amount", suffix
unit, helper "1 to 2000 ml" (or "1 to 67 fl oz"). Actions: "Cancel" (text
button) and "Add" (filled, disabled until the amount is valid).

### history (tab 2, title "History")
1. Streak card (hidden in the empty state): flame-free water drop icon in secondary, "3-day streak"
   (titleLarge), muted "Days in a row you met your goal". When 0:
   "No streak yet" and "Meet your goal to start one".
2. Chart card titled "Last 7 days": 7 vertical bars, height relative to the
   larger of the goal and the highest day; a dashed horizontal line at the
   goal labelled "Goal". Day labels under the bars ("Mon", "Tue", ...), today
   last and in bold. Bars that met the goal use primary, others primary at 45%,
   today secondary.
   When today has met the goal its bar is still secondary, with a check icon
   above it.
3. List of the same 7 days, newest first: the date as "Tue, 14 Oct" (version 1
   is English only and always uses this day-month order), the total
   ("1750 ml"), and a check icon when the goal was met.
4. Banner ad anchored at the bottom, in its own reserved row below the
   scrolling content, only after an ad has loaded. If it fails, the row is
   removed (height 0).
Empty state: centred glass symbol and "Your week will show up here once you
log a drink." No chart, no ad.

### settings (tab 3, title "Settings")
A list:
- "Daily goal" with the current value as subtitle ("2000 ml"); tapping opens a
  dialog titled "Daily goal" with one number field labelled "Daily goal",
  suffix "ml" or "fl oz", pre-filled with the current goal, and the buttons
  "Cancel" (text) and "Save" (filled). An out-of-range value shows the same
  message as onboarding under the field, and the dialog stays open.
- "Units": segmented button "ml" | "fl oz" (key `settings_unit`).
- "Privacy options": only when the consent SDK requires it; opens the UMP
  privacy options form.
- "Reset all data" in the error color; opens a dialog "Reset all data?" with
  body "This deletes every drink and your goal. It can't be undone." and
  actions "Cancel" (text button) and "Reset" (text button in the error color,
  bold) so it reads as destructive.
- Footer: "Glassful 1.0.0" in muted bodySmall.
No ads on this screen.

## Motion

- Progress ring animates to its new value in 400 ms, easeOutCubic.
- Bars grow from zero in 300 ms when History opens.
- Tab changes use the default Material fade-through (no custom transition).
- Respect "reduce motion": when the platform disables animations, values jump.

## Dark mode

Supported and follows the system. Uses `dark_colors` from brand.json. Card
outlines are dropped; cards use the surface color.

## Accessibility

- Every icon button has a tooltip; quick-add buttons read "Add 250 ml".
- All tappable targets are at least 48 by 48 dp.
- Layouts scroll, so text at scale 2.0 never overflows; the quick-add grid
  becomes a single column when the screen is narrower than 360 dp or text
  scale is above 1.5.
- Text contrast meets 4.5:1 in both modes (checked by the factory).
