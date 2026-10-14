# Glassful: hand-off

Glassful is a one-tap water tracker built live by the factory in a Claude
session (a demo run: the owner asked to watch the factory work and named no
idea). A separate read-only supervisor approved every stage, an independent
tester and reviewer checked the code, and the latest "Check an app" run
(`docs/CHECK_REPORT.md`, 2026-10-14 20:41 UTC) passed every step.

`python -m factory handoff` cannot write this file in session mode (it reads
`docs/STATUS.json`, which only the automatic pipeline creates), so it was
written by hand in the same layout.

## What was built

- Onboarding with a daily goal in ml or fl oz
- Today: progress ring, one-tap 150 / 250 / 500 ml (6 / 8 / 16 fl oz),
  custom amount, Undo, today's drinks with delete
- History: last 7 days chart with the goal line, daily totals, streak
- Settings: goal, units, Privacy options (when the consent SDK needs it),
  reset all data
- One AdMob banner on History only, after UMP consent; no ads anywhere else
- Offline, data on the phone only, light and dark mode

To try the debug build: download the `store-package` artifact from the latest
"Check an app" run, or build it with `flutter build apk --debug` in `app/`
and install the APK on an Android phone.

## What was checked automatically

- `flutter analyze` with no issues, `dart format`, 106 widget tests, and the
  end-to-end tests on an Android emulator (API 34)
- every acceptance criterion (AC-1 to AC-30) is named in a passing test, none
  is manual (`docs/TEST_REPORT.md`)
- an independent review: 3 minor findings, all fixed (`docs/REVIEW.json`)
- the tester found and fixed 5 bugs (see `docs/TEST_REPORT.md`)
- screenshots taken from the real app on the emulator and opened before
  hand-off; store images and texts checked against Play and App Store limits
- a release app bundle and APK built

A passing set of checks does not mean the app has no mistakes.

## Not verified

- the app on a real phone (it ran on an Android emulator only)
- the iPhone build: the factory has no Mac, so the iOS app was never compiled
- real ads and the real consent form; the app was tested with a fake ad
  service and Google's test ad units only
- dates and numbers outside English (version 1 is English only)
- whether a store reviewer accepts it

## Your steps to publish

1. AdMob: create the apps and the `glassful_history_banner` banner unit, put
   the real IDs in `app/config/ads.release.json`, AndroidManifest.xml and
   Info.plist, set max content rating PG and block Gambling, Dating, Alcohol,
   Weight loss and Get rich quick. Ads were tested with test IDs only.
2. Privacy policy: replace `{{CONTACT_EMAIL}}` in `store/privacy-policy.html`
   and host it at a public URL.
3. Google Play: sign the bundle with your upload key (see
   `docs/OWNER_TODO.md`), paste the texts from `store/listing.json`, upload
   `store/play/icon-512.png`, `store/play/feature-graphic.png` and
   `store/play/phone/`, and answer Data safety and the rating questionnaire
   from `store/listing.json`.
4. App Store: on a Mac, `flutter build ipa` in `app/` with bundle id
   `com.geti007.glassful`, upload `store/appstore/iphone-6.9/` and
   `store/appstore/icon-1024.png`, and fill the privacy labels.

Every value is listed in `docs/OWNER_TODO.md`.

## Listing at a glance

- Play: **Glassful: Water Tracker**: Log water in one tap, watch your daily
  goal fill up, and keep your streak.
- App Store: **Glassful: Water Tracker**: Drink Water, One Tap at a Time
