# AppStorm: rules for every agent

This repository turns one app idea into a store-ready Flutter app. A Python
orchestrator (`factory/`) runs each stage, gives the work to one agent, runs
the deterministic checks in `factory/gates.py` itself, and then asks a
supervisor agent to approve the stage. Work that fails either one comes back
to you with the exact failing output.

## Where things live

| Path | What |
|------|------|
| `docs/IDEA.md` | The owner's idea. The only input. |
| `docs/SPEC.md`, `docs/app.json` | What to build, with numbered acceptance criteria (AC-1, AC-2, ...) |
| `docs/DESIGN.md`, `brand/` | Screens, states, colors, type, the icon as SVG |
| `app/` | The Flutter app (Android and iPhone) |
| `docs/TEST_REPORT.md` | Which test proves which AC |
| `docs/REVIEW.json` | Findings from the independent review |
| `store/` | Listing text, privacy policy, icons, screenshots, feature graphic |
| `docs/STATUS.json` | Where the pipeline is. Written by the orchestrator only. |
| `factory/` | The factory itself. Never edit it while building an app. |

## Rules

- Do your own stage only. Read the earlier stages' files; do not rewrite them
  unless your task says so.
- The owner will not test the app. Nothing reaches them that you have not
  proven with a test, a check, or a screenshot you looked at. If you could not
  verify something, write "not verified" and why.
- Never weaken, skip, or delete a test, lint rule, or check to make it pass.
  Fix the code.
- Report only commands you actually ran and their real output.
- Apps work fully offline with data stored on the device, unless the idea
  cannot work without a server. No accounts, sign-in, backend, analytics,
  crash reporting, or paid services unless `docs/SPEC.md` lists them with a
  reason. Every extra service is something the owner must set up and a store
  reviewer must check.
- Use only packages from pub.dev that are well maintained and support Android
  and iOS. Pin them with `flutter pub add`. Record the licence of every font,
  image, sound, or package-bundled asset in `docs/LICENSES.md`.
- Do not copy text, images, fonts, or code you have no right to use. Draw
  icons and illustrations as code or SVG.
- No placeholder text, "coming soon" screens, dead buttons, or features the
  spec does not describe. Store reviewers reject them.
- Never do these. They belong to the owner:
  - publish or upload to Google Play or the App Store
  - create, read, or commit signing keys, keystores, certificates, or store credentials
  - commit secrets or API keys
  - sign up for accounts or spend money
  - load or tap a real ad (see Ads)

## Ads

When `docs/app.json` has `"ads": true`, the app shows Google AdMob ads with
the `google_mobile_ads` plugin.

- Code and tests use only Google's published test ad unit IDs (publisher
  `ca-app-pub-3940256099942544`), taken from Google's "Enable test ads" page.
  Never guess an ID.
- Real ad unit IDs are read from `app/config/ads.release.json` by release
  builds only. Leave its values empty; the owner fills them in.
- Ask for consent with the UMP SDK at launch and request ads only once
  `canRequestAds()` is true. Settings has a "Privacy options" entry when the
  SDK says one is required.
- Ads appear only on screens with real content: never on splash, consent,
  loading, empty, error, settings, or purchase screens. Interstitials only at a
  natural break, never at launch, on exit, or mid-task, and never two in a row.
  Rewarded ads only when the user chooses them, with the reward stated first.
- A failed or offline ad leaves no blank gap and never blocks the app.
- Content for children, religion, or other sensitive topics: `docs/SPEC.md`
  lists the ad categories to block and the maximum ad content rating.

## Definition of done

The orchestrator checks all of these before it writes the hand-off:

- every gate in `factory/gates.py` passes, run by the orchestrator, not by you
- every AC is named in a passing test, or is MANUAL in `docs/TEST_REPORT.md` with a reason
- `docs/REVIEW.json` has no open critical or major finding
- `store/` passes `python -m factory validate-store`
- the supervisor approved every stage, including the screenshots it looked at

A passing pipeline means these checks passed. It does not prove the app has
no mistakes. Never write that it does.
