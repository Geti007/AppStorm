# Trippi: hand-off

Trippi was built in a Claude session rather than by `python -m factory run`. A
separate read-only supervisor approved every stage, and the latest "Check an
app" run (docs/CHECK_REPORT.md, 2026-10-11 20:04 UTC) passed every step. The
app is ready for the owner-only steps below.

`python -m factory handoff` could not write this file: it reads
`docs/STATUS.json`, which only the automatic pipeline creates. This file follows
the same layout and was written by hand.

## What was checked automatically

- `flutter analyze` with no issues, `dart format`, 158 unit and widget tests,
  and the end-to-end tests on an Android emulator
- every acceptance criterion in docs/SPEC.md is named in a passing test (see
  docs/TEST_REPORT.md)
- an independent review with no open critical or major finding (4 minor
  findings in the last round, all fixed, see docs/REVIEW.json)
- screenshots taken from the real app on the emulator, then opened and approved
  by the supervisor (assets stage, round 3)
- store images and text checked against Google Play and App Store size and
  length limits
- a release app bundle and APK built

## Not verified

- the app on a real phone (it ran on an Android emulator only)
- the iPhone build: the factory has no Mac, so the iOS app was never compiled
- real ads, the real UMP consent form and real subscriptions; tests used
  Google's test ads and a fake billing service
- number and date formats outside English
- whether a store reviewer accepts it; the checks follow the published rules,
  but review is a human decision

## Your steps to publish

### Google Play

1. Create the app in Play Console with the title from `store/listing.json`
   (play.title).
2. Sign and upload the release bundle. The bundle from the workflow is signed
   with the debug key, which Play rejects; see docs/OWNER_TODO.md section 4.
3. Store listing: paste the texts from `store/listing.json`, upload
   `store/play/icon-512.png`, `store/play/feature-graphic.png`, and the images in
   `store/play/phone/`.
4. Privacy policy: replace `{{CONTACT_EMAIL}}` in `store/privacy-policy.html`,
   publish it at a public URL and paste the URL.
5. Data safety and content rating: answer with `store/listing.json` privacy and
   play.content_rating_notes.

### App Store

1. Create the app in App Store Connect with bundle id `com.geti007.trippi` and
   the name from appstore.name.
2. Build and upload from a Mac with Xcode (`flutter build ipa` in `app/`).
3. Paste the texts from `store/listing.json` (appstore), upload the
   `store/appstore/iphone-6.9/` screenshots and `store/appstore/icon-1024.png`.
4. Use the same privacy policy URL, and answer the privacy labels from
   `store/listing.json` privacy.

### AdMob and the subscription

Ads were tested with Google's test IDs only. Before release, create the AdMob
apps and ad units, put the real IDs in `app/config/ads.release.json` and the
manifest and Info.plist, set up the consent message, and block the ad
categories the spec lists. Create the `trippi_premium_monthly` subscription
($1.99 a month, 7-day free trial) in both stores. docs/OWNER_TODO.md lists
every value.

## Listing at a glance

- Play: **Trippi: Group Travel Expenses**: Split trip costs in any currency and
  see who owes whom, even offline.
- App Store: **Trippi: Split Travel Costs**: Group Travel Expense Tracker
