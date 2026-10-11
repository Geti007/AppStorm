# Trippi: what only the owner can do

These need your own accounts, so the factory left them for you. Until the
AdMob values are filled in, release builds show no ads at all (debug builds
use Google's test ads).

## 1. AdMob (ads)

In AdMob, add two apps (Android and iOS), then create these ad units for
each app:

| Ad unit | Format | Goes in |
|---|---|---|
| Lists | Native advanced | `app/config/ads.release.json` → `native_lists` |
| Premium Pass | Rewarded | `app/config/ads.release.json` → `rewarded_pass` |

Then replace Google's sample app IDs with your real AdMob app IDs:

- Android: `app/android/app/src/main/AndroidManifest.xml`, the
  `com.google.android.gms.ads.APPLICATION_ID` value (now
  `ca-app-pub-3940256099942544~3347511713`).
- iOS: `app/ios/Runner/Info.plist`, `GADApplicationIdentifier` (now
  `ca-app-pub-3940256099942544~1458002511`).
- Also note both IDs in `app_id` in `ads.release.json` so they live in one place.

In AdMob, also:

- Create the GDPR consent message (Privacy & messaging → European
  regulations) and, for iOS, the IDFA explainer if you plan to ask for
  tracking (the app does not ask; iOS ad requests are non-personalised).
- Set the maximum ad content rating to **G**.
- Block these sensitive categories: Gambling, Dating, Alcohol, Politics,
  Religion, and Sensitive financial products (cash advances, debt services).
- Add the full list of SKAdNetwork IDs from Google's iOS quick-start page to
  `Info.plist` (only Google's own ID is there now).

## 2. Subscription

Create one auto-renewing subscription with product ID
`trippi_premium_monthly`:

- Google Play Console: subscription `trippi_premium_monthly`, base plan
  monthly, $1.99, plus an offer "7-day free trial" for new customers.
- App Store Connect: subscription group "Trippi Premium", product
  `trippi_premium_monthly`, 1 month, $1.99, introductory offer: free for
  1 week, new subscribers only.

The app reads the price and trial from the store, so nothing in code needs
changing.

## 3. Store listings

- Contact email: replace `{{CONTACT_EMAIL}}` in `store/privacy-policy.html`.
- Host `store/privacy-policy.html` somewhere public (for example GitHub
  Pages) and paste its URL into both store listings.
- Fill in Play's Data safety form and Apple's privacy labels exactly as
  `store/listing.json` describes.

## 4. Signing and release

- Android: create an upload key and add it as GitHub secrets
  (`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`), or sign the bundle yourself. Never commit it.
- iOS: needs your Apple Developer account and a Mac with Xcode to sign,
  archive and upload. The iOS build has not been run by the factory.
- Upload to Google Play and App Store Connect yourself.
