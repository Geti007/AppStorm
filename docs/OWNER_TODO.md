# What the owner must do before publishing Glassful

Nothing here can be done by the factory: each step needs your accounts.

## 1. AdMob (one app per platform, one ad unit each)

1. In your AdMob account, add the app "Glassful" for Android and for iOS.
2. In each app, create one ad unit:
   - Name: `glassful_history_banner`
   - Format: Banner (the app requests an anchored adaptive size)
3. Put the IDs in `app/config/ads.release.json`:
   - `android.app_id`, `android.history_banner`
   - `ios.app_id`, `ios.history_banner`
4. Replace Google's sample app IDs with your real app IDs in:
   - `app/android/app/src/main/AndroidManifest.xml`, the
     `com.google.android.gms.ads.APPLICATION_ID` meta-data
     (now `ca-app-pub-3940256099942544~3347511713`)
   - `app/ios/Runner/Info.plist`, `GADApplicationIdentifier`
     (now `ca-app-pub-3940256099942544~1458002511`)
5. Blocking controls for both apps: maximum ad content rating **PG**; block the
   sensitive categories Gambling, Dating, Alcohol, Weight loss and Get rich quick.
6. Privacy & messaging: create a GDPR consent message (and a US state
   regulations message if you want) for both apps, so the consent form shows.
7. Never tap your own ads. Release builds with empty IDs simply show no ads.

## 2. Privacy policy

Replace `{{CONTACT_EMAIL}}` in `store/privacy-policy.html` with your email,
host the page publicly, and paste its URL into both store listings.

## 3. Signing and upload

- Android: create an upload key and add the `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`
  repository secrets, then re-run the "Check an app" workflow to get a signed
  `app-release.aab`. Upload it in Google Play Console.
- iOS: needs a Mac with Xcode and your Apple Developer account to sign,
  archive and upload. The iOS build was not run by the factory.

## 4. Store forms

Fill in the Play Data safety form, Apple privacy labels and the rating
questionnaires using the answers in `store/listing.json` (`privacy` and the
`*_rating_notes` fields).
