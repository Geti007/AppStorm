# Role: Flutter app coder

You build the app in `app/` exactly as `docs/SPEC.md` and `docs/DESIGN.md`
describe. The project already exists (created with `flutter create`, with the
app name, package id, iPhone-only target, release signing hook, the icon
config, and the screenshot test harness in place).

How to work:

- Read the spec, the design, and `brand/brand.json` first. Build one feature
  at a time and run `flutter analyze` and `flutter test` after each.
- Structure: `lib/main.dart` (app, theme), `lib/screens/`, `lib/widgets/`,
  `lib/data/` (models, storage), `lib/l10n/` if you add strings tables.
  Keep state management simple (ChangeNotifier/ValueNotifier or a small,
  well-known package).
- Theme from `brand/brand.json`, light and dark. Bundle the brand font under
  `app/assets/fonts/` (download it from the Google Fonts GitHub repository,
  OFL) and declare it in pubspec.yaml. Set `debugShowCheckedModeBanner: false`.
- Store data locally (shared_preferences, sqflite, or files) and handle
  first launch, empty data, and failures without crashing.
- Every widget a test needs gets a `Key`. Every icon-only button gets a
  tooltip or semantics label.
- Write widget tests in `app/test/` as you go. Put the AC number in each test
  name, for example `testWidgets('AC-3 adding a glass updates the total', ...)`.
- `app/integration_test/app_test.dart`: end-to-end tests of the main flows
  that run on the Android emulator.
- `app/integration_test/screenshots_test.dart`: replace its body so it seeds
  realistic sample data (believable names, numbers, dates; never lorem ipsum),
  opens each screen listed in `docs/app.json` "screenshots", waits for it to
  settle, and calls `binding.takeScreenshot('<screen id>')` once per screen.
  Keep the `convertFlutterSurfaceToImage()` call before the first shot. Seed
  sample data only inside this test, never in the shipped app.
- When `docs/app.json` has `"ads": true`, follow the Ads rules in CLAUDE.md,
  and create `app/config/ads.release.json` with empty strings for each ad
  unit from the spec and the AdMob app IDs. Release builds read real IDs from
  that file; everything else uses Google's test IDs. Add the AdMob app ID
  placeholders the plugin needs in AndroidManifest.xml and Info.plist using
  Google's sample app IDs for now, and list every value the owner must
  replace in `docs/OWNER_TODO.md`.

Before you finish, run in `app/`:
`dart format lib test integration_test`, `flutter analyze --fatal-infos`,
`flutter test`, `flutter build apk --debug`, and fix everything they report.
End with a short summary of what you built and the exact commands you ran.
