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

**Important**: a cloud Mac can't be plugged into the iPhone, so "Run on device" from Xcode isn't practical. **TestFlight is the delivery path** to the child's phone. Signing and TestFlight are handled by a friend's Apple Developer account (DECISIONS.md D-018). Their instructions are in [APPLE_HANDOFF.md](APPLE_HANDOFF.md). The project owner's own enrolment is **not** required.

## WSL setup

```bash
# Node (already present: v22 via nvm)
node -v

# Swift toolchain for WantWiseCore tests (installed 2026-10-02: Swift 6.4.0 via swiftly)
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
tar zxf swiftly-$(uname -m).tar.gz && ./swiftly init
# swiftly prints the system packages the toolchain needs. On Ubuntu 24.04 (needs sudo, once):
sudo apt-get -y install zip gnupg2 libcurl4-openssl-dev libxml2-dev libncurses-dev libz3-dev pkg-config
source ~/.local/share/swiftly/env.sh   # swiftly adds this to your shell profile
swift --version

# Supabase CLI (Milestone 3)
npm i -g supabase   # or: brew / scoop — any is fine
```

Commands:

```bash
# Core domain tests
cd apps/ios/WantWiseCore && swift test

# Display
cd apps/display && npm install
npm run dev                # http://localhost:3000/display   (F = full screen, ←/→ = previous/next)
npm test                   # Vitest
npm run typecheck
npm run build && npm start # production mode, best for leaving on a screen
```

## Before the first signed build (no Mac time needed)

- [ ] Check the child's iPhone **iOS version** (Settings → General → About). This decides D-021 (iOS 17 vs 18 minimum).
- [ ] Agree final bundle IDs and App Group with the signing partner (D-022). Placeholders: `tech.wantwise.app`, `tech.wantwise.app.share`, `group.tech.wantwise.app`.
- [ ] Partner reads "Ownership implications" in [APPLE_HANDOFF.md](APPLE_HANDOFF.md).
- [ ] Have the child's and owner's Apple ID emails ready for TestFlight.

## First Mac session [MAC REQUIRED]

Two possible routes. Either works; the repo is the same.

**A. The signing partner does it all**: follow [APPLE_HANDOFF.md](APPLE_HANDOFF.md). Compile errors get reported back (or fixed and pushed).

**B. The owner rents a cloud Mac to get the build green first**, then the partner only signs and uploads. This is cheaper in the partner's time and is recommended for the very first build, because hand-written SwiftUI is likely to need fixes.

Route B checklist (no signing needed for the Simulator):

```bash
xcodebuild -version                      # latest stable Xcode
brew install xcodegen
git clone https://github.com/wiltonn/wantwise.git && cd wantwise/apps/ios

# 1. Core package (already verified on Linux; confirm on macOS)
(cd WantWiseCore && swift test)

# 2. Generate project (no Team ID needed for Simulator builds)
xcodegen generate

# 3. Build + test in Simulator
xcrun simctl list devices available | grep iPhone
xcodebuild -scheme WantWise -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme WantWise -destination 'platform=iOS Simulator,name=iPhone 16' test
```

4. Fix compile errors. **Commit and push after each fix**, not at the end.
5. Walk through the Milestone 1 checklist in the Simulator (`open WantWise.xcodeproj`, run): add, relaunch, reconsider, and a notification test using a debug revisit date 1 minute ahead.
6. If D-021 chose iOS 17: also run the test command against an iOS 17 Simulator runtime.
7. Update [VERIFICATION.md](VERIFICATION.md) with what was actually verified. Push.

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

What has actually been verified, and where, is tracked in [VERIFICATION.md](VERIFICATION.md).

## Display kiosk setup (Milestone 4)

On the TV/PC: Chrome or Edge, `--kiosk https://<display-url>/display`, disable OS sleep/screensaver, auto-start the browser on login.

## Conventions

- Commit small. Push before ending any Mac session.
- Architecture or product changes get a new dated entry in `docs/DECISIONS.md` — never silently edit an old one.
- Mark Apple-only instructions with **[MAC REQUIRED]**.
