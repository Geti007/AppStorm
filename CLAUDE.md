# AppStorm: rules for every agent

This repository turns one app idea into a store-ready Flutter app. Each stage
is done by one role (`factory/prompts/<role>.md`), checked by the deterministic
checks in `factory/gates.py`, and then approved by a separate supervisor. Work
that fails either one goes back with the exact failing output.

There are two ways to run it. The default is a Claude session in the owner's
project, using the owner's Claude plan (see "Building an app in a Claude
session" below). The other is `python -m factory run` in the "Build an app"
GitHub workflow, which needs an Anthropic API key.

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

## Building an app in a Claude session

This is how an app gets built when the owner gives an idea in the project.
The session plays each role in turn and keeps the same quality bar as the
automatic pipeline.

1. Branch: `git checkout -b app/<short-name> origin/main`. Write the idea to
   `docs/IDEA.md`. Every push to an `app/**` branch runs the "Check an app"
   workflow, which needs no API key: it runs `python -m factory check` on an
   Android emulator, commits `docs/CHECK_REPORT.md`, the icons and the store
   images back to the branch, uploads the store package, and keeps a draft
   pull request for the app. Subscribe to that pull request so check results
   wake you.
2. Local tools: install Flutter (stable) under `/home/claude/sdk` if it is
   missing, `pip install -r requirements.txt`, and use the preinstalled
   Chromium for Playwright. This machine has no Android SDK or emulator, so
   run local checks with `FACTORY_SKIP_APK=1`; the workflow does the APK,
   the emulator tests, the screenshots and the release build.
3. Stages, in order: planner (spec), scaffold (`python -m factory check`
   creates the Flutter project once `docs/app.json` exists, or run the
   scaffold locally), designer, coder, tester, reviewer, store writer, then
   screenshots and release from the workflow. For each stage, read the role
   file and do exactly what it says.
4. After each stage: run the matching gate locally (`python -c "from factory
   import gates; from pathlib import Path; print(gates.<stage>(Path('.')))"`),
   fix everything it reports, commit, push.
5. Supervisor and reviewer must be independent of the work: run each one as a
   separate subagent with read-only tools, give it `factory/prompts/supervisor.md`
   (or `reviewer.md`), the stage's question from `factory/pipeline.py`, and the
   files to read, and act on its verdict. Three rounds per stage, as in the
   pipeline; after that, stop and tell the owner what is blocking.
6. Look at the screenshots and store images the workflow commits under
   `store/` (open the PNGs) before calling the app done.
7. Finish with `python -m factory handoff` once the check report shows every
   step passed, and give the owner the pull request and the store package.
