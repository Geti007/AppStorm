# AppStorm

Type an app idea. A team of Claude agents turns it into a Flutter app for
Android and iPhone with tests, an independent review, a store listing, a
privacy policy, the icon in every size, store screenshots taken from the real
app, a feature graphic, and a release build. You upload it to the stores.

Everything runs in GitHub Actions in this repository. Nothing runs on your
computer.

## How it works

```
idea ─▶ spec ─▶ project ─▶ design + icon ─▶ build ─▶ test ─▶ review ─▶ store text ─▶ screenshots ─▶ final audit ─▶ release
         │                     │              │        │        │          │             │              │
         └───── every stage: agent works ▶ automatic checks ▶ supervisor approves, or it goes back with the exact problems
```

| Stage | Agent | Checked by the orchestrator (not by the agent) |
|---|---|---|
| Spec | planner | at least 5 numbered acceptance criteria, valid name, package id, screens |
| Project | none | `flutter create` with your package id, iPhone-only target, release signing hook |
| Design | designer | WCAG contrast of every text color, icon renders, no rounded corners, adaptive-icon safe zone |
| Build | coder | format, `flutter analyze` with no infos, all tests, no TODOs or lorem ipsum, no secrets, no real ad IDs, no DEBUG banner, app name set, debug APK builds |
| Test | tester | the build checks, every AC named in a test, end-to-end tests pass on an Android emulator |
| Review | reviewer (read-only), then coder | no open critical or major finding, tests still pass |
| Store text | store writer | every text within Play and App Store limits, privacy policy present |
| Screenshots | none, then coder | screenshots captured from the app on the emulator, framed with captions at store sizes, every image size and format checked |
| Final audit | supervisor, then coder | everything above again |
| Release | none, then coder | release app bundle and APK build |

The supervisor is a read-only Claude agent that looks at each stage's output,
including the rendered icon and screenshots, and approves it or sends it back
with specific issues. A stage gets three rounds. If it still fails, the
pipeline stops, says why in `docs/HANDOFF.md`, and you can continue it later.

All agents use Claude Opus 5.5 through Claude Code. Their rules are in
`CLAUDE.md` and their roles in `factory/prompts/`.

## One-time setup

1. **API key.** In this repository: Settings > Secrets and variables >
   Actions > New repository secret. Name `ANTHROPIC_API_KEY`, value your key
   from console.anthropic.com.
2. **Pull requests from Actions.** Settings > Actions > General > Workflow
   permissions: tick "Allow GitHub Actions to create and approve pull
   requests". Without it the app still builds; you just open the PR yourself.
3. **Variables** (optional), same page, Variables tab:
   - `CONTACT_EMAIL`: the support email that goes into each privacy policy.
   - `PACKAGE_PREFIX`: the start of every app id, for example `com.yourname`.
     Defaults to `com.<github owner>`. App ids cannot change after publishing.
4. **Android upload key** (optional, recommended). Create an upload key once
   on your computer (`keytool -genkey -v -keystore upload.jks -keyalg RSA
   -keysize 2048 -validity 10000 -alias upload`), then add these secrets:
   `ANDROID_KEYSTORE_BASE64` (the output of `base64 -w0 upload.jks`),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
   With them, the app bundle is ready to upload. Without them, it is signed
   with a debug key and Play will refuse it. The agents never see this key.

## Build an app

Actions > **Build an app** > Run workflow. Type the idea and press Run.

- A branch `app/<name>` is created and pushed after every stage, so you can
  watch progress in its commits and in `docs/STATUS.json`.
- When it finishes, a draft pull request opens with the hand-off, and the run
  has a **store-package** artifact: the `.aab`, a release `.apk`, and the
  whole `store/` folder (texts, privacy policy, icons, screenshots, feature
  graphic).
- To continue an app that stopped (time limit, spending limit, or a blocked
  stage), run the workflow again with its branch in "continue branch".

A full run takes a few hours. The spending limit (default $60 per run) stops
the agents before they exceed it.

## What you still do

- Create the developer accounts, the app entries, and upload the files.
- Host the privacy policy at a public URL (GitHub Pages works).
- Answer the stores' content rating and data safety questions (the answers
  are prepared in `store/listing.json`).
- For iPhone: the workflow proves the iOS app compiles. Signing and uploading
  need your Apple Developer account and a Mac (or an App Store Connect API key
  added later).
- For ads: create the AdMob app and ad units and paste their IDs where
  `docs/OWNER_TODO.md` says. The agents only ever use Google's test ads.

## What the checks do not prove

The gates prove that every listed check passed and the supervisor approved
each stage. They do not prove the app has no bugs, and they cannot promise a
store reviewer will accept it. The app is tested on an Android emulator, not a
real phone, and the iPhone build is compiled but not run.

## Working on the factory

```
pip install -r requirements.txt -r requirements-dev.txt
python -m playwright install chromium
python -m pytest -q
```

| Path | What |
|---|---|
| `factory/pipeline.py` | Stages, rounds, supervisor, status, commits |
| `factory/gates.py` | The deterministic checks |
| `factory/claude.py` | Runs one agent with `claude -p` |
| `factory/prompts/` | One file per agent role |
| `factory/scaffold.py` | Creates the Flutter project |
| `factory/assets/` | Icons, screenshots, feature graphic |
| `factory/store_rules.py` | Store size and length limits, in one place |
| `factory/validate_store.py` | Checks `store/` against those rules |
| `factory/handoff.py` | Writes `docs/HANDOFF.md` |

When a mistake gets past the checks, add a check to `factory/gates.py` so it
cannot get past twice.
