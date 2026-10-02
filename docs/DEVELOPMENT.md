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

### Three stages

1. **WSL development**: everything above.
2. **Rented Mac, Simulator validation** ([CLOUD_MAC_SESSION.md](CLOUD_MAC_SESSION.md)): compile, test and run in the Simulator. **Needs no Apple account** (D-026).
3. **Signing partner** ([APPLE_HANDOFF.md](APPLE_HANDOFF.md)): device signing, provisioning, TestFlight.

Stage 2 never waits on Stage 3.

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

## Mac sessions

- **Stage 2 (rented Mac, Simulator):** follow [CLOUD_MAC_SESSION.md](CLOUD_MAC_SESSION.md). One command does most of it: `apps/ios/scripts/mac-build.sh`.
- **Stage 3 (signing partner, TestFlight):** [APPLE_HANDOFF.md](APPLE_HANDOFF.md). Before it: agree final identifiers (D-022) and have the testers' Apple ID emails ready.

### Validating the Xcode project from WSL

XcodeGen builds and runs on Linux, so `project.yml` can be checked without a Mac:

```bash
git clone --depth 1 https://github.com/yonaskolb/XcodeGen.git ~/src/XcodeGen
(cd ~/src/XcodeGen && swift build -c release --product xcodegen)
cd apps/ios && ~/src/XcodeGen/.build/release/xcodegen generate   # writes the git-ignored WantWise.xcodeproj
```

Syntax-only check of the app's Swift (no Apple SDK needed; catches typos, not type errors):

```bash
cd apps/ios && for f in $(find WantWise Shared WantWiseShare WantWiseTests WantWiseUITests -name '*.swift'); do swiftc -parse "$f"; done
```

## Testing strategy

| Layer | Tooling | Runs in |
|---|---|---|
| Domain / unit (`WantWiseCore`) — transitions, dates, countdown, metrics, inbox format/import | XCTest / Swift Testing | **WSL** + Mac |
| Persistence (SwiftData models, `WantStore`, relaunch survival using a file-backed store) | Swift Testing in `WantWiseTests` | Mac |
| SwiftUI | SwiftUI previews + 3 UI smoke tests (add Want, relaunch persistence, reconsider) | Mac |
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
