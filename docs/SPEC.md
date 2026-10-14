# Glassful: specification

## 1. Summary

Glassful is for anyone who wants to drink enough water each day without
thinking about it. It does one job: log a drink in one tap and show how close
you are to today's goal.

## 2. Decisions made for you

- Name "Glassful": a web search found no well-known water app with this name.
- Default goal 2000 ml (68 fl oz); allowed range 500 to 6000 ml (17 to 203 fl oz).
- Quick-add sizes are fixed per unit: 150, 250, 500 ml or 6, 8, 16 fl oz.
- A custom amount may be 1 to 2000 ml (or 1 to 68 fl oz).
- Amounts are stored in millilitres; ounces are shown rounded to whole numbers
  (1 US fl oz = 29.5735 ml).
- A day runs from local midnight to midnight.
- No reminders or notifications in version 1 (they need a permission prompt
  and are easy to get wrong on both platforms).
- One ad placement only: a banner on the History screen. The Today screen has
  no ads so logging a drink is never interrupted.
- Light and dark mode follow the phone's setting.

## 3. Scope

Version 1: goal, quick add, custom add, undo, today's log with delete, 7-day
history with streak, unit setting, reset all data, ads with consent.

Left out on purpose: reminders, health-app sync, other drinks, accounts,
cloud backup, widgets, premium tier. The app is offline-first and stores
everything on the device.

## 4. Screens

| id | Screen | How you get there |
|---|---|---|
| `onboarding` | Welcome and goal setup | First launch only |
| `today` | Today's progress, quick add, today's log | Home tab (default after onboarding) |
| `custom_amount` | Dialog to type any amount | "Custom" button on Today |
| `history` | Last 7 days chart, streak, daily totals | History tab |
| `settings` | Goal, unit, privacy options, reset | Settings tab |

Bottom navigation: Today, History, Settings.

States:
- Loading: while saved data is read at launch, a centred progress indicator.
- Error: if saved data cannot be read, the app starts with empty data and shows
  a snackbar "Couldn't read saved data. Starting fresh."
- Today empty: the progress ring at 0% and the text "No drinks yet today. Tap
  a glass to start."
- History empty (no drink ever logged): "Your week will show up here once you
  log a drink." No chart, no ad.

## 5. Features and acceptance criteria

### Onboarding
- AC-1: Given a first launch, when the app opens, then the onboarding screen
  shows with the goal field pre-filled with 2000 and the unit set to ml.
- AC-2: Given onboarding, when the user taps "Start tracking", then the Today
  screen shows and onboarding is not shown again after a restart.
- AC-3: Given onboarding, when the goal entered is outside 500 to 6000 ml,
  then "Start tracking" shows the error "Enter a goal between 500 and 6000 ml"
  and stays on onboarding.

### Logging drinks (Today)
- AC-4: Given the Today screen in ml, when the user taps the 250 ml button,
  then today's total increases by 250 ml and a new entry appears in today's log.
- AC-5: Given a total of 1000 ml and a goal of 2000 ml, then the screen shows
  "1000 / 2000 ml" and "50%".
- AC-6: Given the user taps "Custom", enters 330 and taps "Add", then today's
  total increases by 330 ml.
- AC-7: Given the custom dialog, when the amount is empty, 0, or above the
  maximum, then "Add" is disabled and the dialog shows the allowed range.
- AC-8: Given a drink was just added, when the user taps "Undo" on the
  snackbar, then the drink is removed and the total goes back.
- AC-9: Given an entry in today's log, when the user taps its delete button,
  then the entry is removed and the total updates.
- AC-10: Given today's total reaches or passes the goal, then the screen shows
  "Goal reached" and the progress ring is full (100%, never above).
- AC-11: Given no drinks today, then the Today screen shows "No drinks yet
  today. Tap a glass to start."

### History
- AC-12: Given drinks on several days, when the History tab opens, then it
  shows 7 bars for the last 7 days (today last) and each day's total in the
  list.
- AC-13: Given the goal was met today, yesterday and the day before, but not
  the day before that, then the streak shows "3-day streak".
- AC-14: Given the goal is not met today yet but was met yesterday, then the
  streak still counts yesterday (today does not break the streak until it ends).
- AC-15: Given no drinks have ever been logged, then History shows "Your week
  will show up here once you log a drink." and no ad.

### Settings
- AC-16: Given Settings, when the user changes the daily goal to 2500 and
  saves, then Today shows "/ 2500 ml".
- AC-17: Given Settings, when the user switches the unit to fl oz, then Today
  shows amounts in fl oz and the quick-add buttons read 6, 8 and 16 fl oz.
- AC-18: Given Settings, when the user taps "Reset all data" and confirms,
  then every drink is deleted and onboarding shows again; tapping "Cancel"
  deletes nothing.

### Data
- AC-19: Given drinks were logged and the goal changed, when the app restarts,
  then the drinks, goal and unit are the same as before.
- AC-20: Given saved data that cannot be parsed, when the app starts, then it
  does not crash, starts with empty data, and shows "Couldn't read saved
  data. Starting fresh."

### Ads
- AC-21: Given ads may be requested and a banner has loaded, then the History
  screen shows one banner anchored below the content, and the Today, Settings
  and onboarding screens show no ad.
- AC-22: Given the banner fails to load or the phone is offline, then History
  shows no blank space where the banner would be.
- AC-23: Given the consent SDK says privacy options are required, then
  Settings shows a "Privacy options" entry; otherwise the entry is hidden.

### Accessibility
- AC-24: Every quick-add button, delete button and tab has a screen-reader
  label, and every tappable control is at least 48 by 48 dp.
- AC-25: Given text scale 2.0 on a 320 by 568 screen, then Today, History and
  Settings render without overflow errors.

## 6. Data

Stored with shared_preferences on the device: the list of drinks (time and
amount in ml), the daily goal in ml, the unit, and whether onboarding is done.
Uninstalling the app deletes all of it. "Reset all data" deletes it too.

## 7. Privacy

The app itself collects and shares nothing. Google AdMob, which shows the
banner, may collect the device advertising ID, approximate location from the
IP address, and ad interaction data, as described in Google's policy. Consent
is asked with Google's UMP SDK where the law requires it. On iOS ads are
non-personalised, so no tracking permission is requested.

## 8. Ads

Ads: yes.

| Placement | Format | Screen | Ad unit name |
|---|---|---|---|
| History banner | Anchored adaptive banner | History, only when it has data | `glassful_history_banner` |

- Frequency: one banner, refreshed by AdMob's default timer. No
  interstitials, no rewarded ads.
- Quiet zones: onboarding, Today, the custom amount dialog, Settings, the
  loading and error states, and History when it is empty.
- Consent: UMP at every launch; ads are requested only after
  `canRequestAds()` is true.
- Audience: general adults. Maximum ad content rating: PG. Categories to
  block in AdMob: Gambling, Dating, Alcohol (contradicts a health habit app),
  Weight loss, Get rich quick.

## 9. Store

- Google Play: Health & Fitness. Expected rating: Everyone.
- App Store: Health & Fitness. Expected rating: 4+.
- Why: a hydration log with no user-generated content; ads are limited to PG.

## 10. Accessibility

- Text uses the theme's type scale and follows the system text size.
- Icon-only buttons have tooltips; the progress ring has a label such as
  "1000 of 2000 millilitres, 50 percent".
- Touch targets at least 48 dp.
- Text contrast at least 4.5:1 in light and dark mode.
