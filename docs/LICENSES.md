# Licences

## Bundled assets

| Asset | Source | Licence |
|---|---|---|
| Plus Jakarta Sans (Regular, Medium, SemiBold, Bold), `app/assets/fonts/` | github.com/tokotype/PlusJakartaSans, static weights cut from the variable font with fontTools | SIL Open Font License 1.1, full text in `app/assets/fonts/OFL.txt` |
| App icon and illustrations (`brand/*.svg`, drawn in code in `lib/widgets/art.dart`) | Made for this app | Owned by the app owner |
| Material Icons (from the Flutter SDK) | Google | Apache-2.0 |

No images, sounds or other fonts are bundled.

## Packages (direct dependencies)

| Package | Version | Licence |
|---|---|---|
| cupertino_icons | 1.0.9 | MIT |
| excel | 4.0.6 | MIT |
| file_picker | 13.1.0 | MIT |
| google_mobile_ads | 9.1.0 | Apache-2.0 |
| http | 1.6.0 | BSD-3-Clause |
| in_app_purchase | 3.3.1 | BSD-3-Clause |
| in_app_purchase_android | 0.5.3 | BSD-3-Clause |
| in_app_purchase_storekit | 0.4.13+1 | BSD-3-Clause |
| intl | 0.20.3 | BSD-3-Clause |
| path | 1.9.1 | BSD-3-Clause |
| path_provider | 2.1.6 | BSD-3-Clause |
| pdf | 3.12.0 | Apache-2.0 |
| share_plus | 13.3.1 | BSD-3-Clause |
| sqflite | 2.4.4+1 | BSD-2-Clause |
| url_launcher | 6.3.3 | BSD-3-Clause |

Versions are the ones resolved in `app/pubspec.lock`. Licences were read
from each package's LICENSE file in the pub cache.

## Services

- Exchange rates: Frankfurter (api.frankfurter.dev), free and keyless; data
  from the European Central Bank.
- Google AdMob and the UMP consent SDK (free plan only).
