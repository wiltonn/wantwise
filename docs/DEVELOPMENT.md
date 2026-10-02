# Development

## The constraint

Primary environment: **Windows → WSL (Ubuntu 24.04) → Claude Code**. No Mac owned. A cloud Mac is rented only when Xcode is genuinely required.

```
WSL: edit ─▶ test what can be tested ─▶ commit ─▶ push
                                                   │
Cloud Mac: pull ─▶ xcodegen generate ─▶ build/test ─▶ fix ─▶ commit ─▶ push
                                                   │
                                     archive ─▶ TestFlight ─▶ child's iPhone
```

**Rule: nothing important lives only in Xcode.** The Xcode project is *generated* from `apps/ios/project.yml` (XcodeGen) and is git-ignored. Signing team, bundle IDs, capabilities, entitlements and Info.plists are all files in the repo.

## What can be done where

### WSL-capable

- All documentation
- `WantWiseCore` Swift package — **build and test on Linux** with the open-source Swift toolchain (Foundation only, no Apple frameworks)
- Authoring all SwiftUI / SwiftData / Share Extension source (not compiling it)
- `project.yml`, Info.plists, entitlements, `.xcconfig`
- WantWise Display (Next.js): build, run, test, view at 1920×1080 in a Windows browser
- Supabase: migrations, RLS policies, local stack (`supabase start` via Docker Desktop/WSL), RLS tests
- Git, scripts, CI config

### [MAC REQUIRED]

- Compiling anything that imports SwiftUI, SwiftData, UIKit, PhotosUI, UserNotifications, LinkPresentation
- Generating the `.xcodeproj` (XcodeGen runs on macOS)
- iOS Simulator, SwiftUI previews, UI tests, app-target tests
- Share Extension behaviour (activation, memory limit, host-app quirks)
- Code signing, App ID / App Group registration, capabilities
- Archiving, uploading to App Store Connect / TestFlight

**Important**: a cloud Mac can't be plugged into the iPhone, so "Run on device" from Xcode isn't practical. **TestFlight is the delivery path** to the child's phone. That needs a paid Apple Developer Program membership (US$99/yr). Free personal-team signing also expires apps after 7 days, which doesn't work when the Mac is only rented occasionally.

## WSL setup

```bash
# Node (already present: v22 via nvm)
node -v

# Swift toolchain for WantWiseCore tests (optional but recommended)
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
tar zxf swiftly-$(uname -m).tar.gz && ./swiftly init
swift --version

# Supabase CLI (Milestone 3)
npm i -g supabase   # or: brew / scoop — any is fine
```

Commands:

```bash
# Core domain tests
cd apps/ios/WantWiseCore && swift test

# Display
cd apps/display && npm install && npm run dev     # http://localhost:3000/display
npm test
```

## Before the first Cloud Mac session (do these first — they cost no Mac time)

- [ ] Enrol in the **Apple Developer Program** (can take 24–48 h to approve). Note your **Team ID**.
- [ ] Decide bundle ID prefix, e.g. `com.<yourname>.wantwise`. Record it in `apps/ios/Config/Base.xcconfig`.
- [ ] Check the child's iPhone **iOS version** (Settings → General → About). Must be ≥ the deployment target (planned iOS 18.0).
- [ ] Push the repo to GitHub (remote already set: `wiltonn/wantwise`).
- [ ] In App Store Connect, create the app record "WantWise" (can be done from any browser).
- [ ] Have the child's Apple ID email ready to add as a TestFlight internal/external tester.

## First Cloud Mac session checklist [MAC REQUIRED]

Goal: Milestone 1 running in the Simulator and delivered to the iPhone via TestFlight. Budget ~3–4 hours.

```bash
# 1. Tooling
xcode-select -p                          # confirm Xcode is installed (latest stable)
xcodebuild -version
brew install xcodegen                    # if Homebrew present; else: mint install yonaskolb/XcodeGen

# 2. Repo
git clone https://github.com/wiltonn/wantwise.git && cd wantwise/apps/ios
git config user.name "Nate" && git config user.email "<your email>"

# 3. Core package tests (should already pass from WSL)
cd WantWiseCore && swift test && cd ..

# 4. Generate and open project
xcodegen generate
open WantWise.xcodeproj
```

5. **Xcode → Settings → Accounts**: sign in with the Apple ID on the Developer Program team.
6. Select the `WantWise` target → Signing & Capabilities → confirm *Automatically manage signing* with your Team. (Team ID comes from `Config/Base.xcconfig`; if Xcode wants to change anything, change the xcconfig/project.yml instead and regenerate.)
7. Confirm the **App Group** `group.<bundle-prefix>.wantwise` is registered (Xcode does this with automatic signing; otherwise developer.apple.com → Identifiers → App Groups).
8. Build and run in Simulator:
   ```bash
   xcodebuild -scheme WantWise -destination 'platform=iOS Simulator,name=iPhone 16' build
   xcodebuild -scheme WantWise -destination 'platform=iOS Simulator,name=iPhone 16' test
   ```
   (Use `xcrun simctl list devices available` to pick a simulator name that exists.)
9. Fix compile errors. **Commit and push after each meaningful fix** — don't hoard changes on the rented Mac.
10. Walk through the Milestone 1 checklist in the Simulator (add, relaunch, reconsider, notification via changing a Want's date to 1 minute ahead in a debug build).
11. Archive and upload:
    - Product → Archive (scheme `WantWise`, destination *Any iOS Device*)
    - Organizer → Distribute App → App Store Connect → Upload
12. App Store Connect → TestFlight: add yourself and the child's Apple ID as testers. Install **TestFlight** on the child's iPhone and accept.
13. `git status` clean, everything pushed. Write down anything surprising in `docs/DECISIONS.md`.

TestFlight builds expire after 90 days — plan a Mac session (or CI) at least that often.

## Testing strategy

| Layer | Tooling | Runs in |
|---|---|---|
| Domain / unit (`WantWiseCore`) — transitions, dates, countdown, metrics, inbox format/import | XCTest / Swift Testing | **WSL** + Mac |
| Persistence (SwiftData models, `WantStore`, relaunch survival using a file-backed store) | XCTest in `WantWiseTests` | Mac |
| SwiftUI | SwiftUI previews + 2–3 UI smoke tests (add Want, reconsider) | Mac |
| Share Extension | Manual device checklist in CAPTURE.md | iPhone via TestFlight |
| Display | Vitest for `lib/domain.ts`; manual visual check at 1080p/4K | **WSL** |
| Cross-platform consistency | `docs/fixtures/countdown-cases.json` run by both Swift and Vitest | **WSL** |
| Backend / RLS | SQL tests against local Supabase | **WSL** |
| Integration (iPhone → Supabase → Display) | Manual end-to-end check per release | All |

Keep it small. Push as much logic as possible into `WantWiseCore` and `lib/domain.ts`, where it's cheap to test.

## Display kiosk setup (Milestone 4)

On the TV/PC: Chrome or Edge, `--kiosk https://<display-url>/display`, disable OS sleep/screensaver, auto-start the browser on login.

## Conventions

- Commit small. Push before ending any Mac session.
- Architecture or product changes get a new dated entry in `docs/DECISIONS.md` — never silently edit an old one.
- Mark Apple-only instructions with **[MAC REQUIRED]**.
