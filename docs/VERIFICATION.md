# Verification status

What has actually been tested, and where. Update this file when something is verified on a new platform. Never mark something verified because it "should work".

Legend:
- ✅ **Verified in WSL**: built and tests run in WSL (Ubuntu 24.04)
- 📝 **Written in WSL, needs Mac/Xcode**: source exists; not yet compiled against Apple SDKs
- 🍎 **[MAC REQUIRED]**: can only be done on macOS/Xcode or a device
- ⏳ **Not started**

_Last updated: 2026-10-02_

## iOS

| Item | Status | Evidence / notes |
|---|---|---|
| `WantWiseCore` builds (Swift 6.4, Linux) | ✅ | `swift build`, zero warnings |
| `WantWiseCore` tests: 40 tests, 8 suites | ✅ | `swift test`: transitions, decision history, revisit dates (incl. DST), countdown (shared fixture), money parsing, sections, metrics, capture inbox format |
| `WantWiseCore` builds/tests on macOS / iOS SDK | 🍎 | Expected to pass (Foundation only), but not yet run. Swift Testing requires Xcode 16+. |
| `project.yml`, Info.plists, entitlements, xcconfig | ⏳ | Next step |
| SwiftData models, `WantStore`, notifications | ⏳ | |
| Milestone 1 SwiftUI views | ⏳ | |
| Xcode project generation (XcodeGen) | 🍎 | |
| Simulator run, persistence across relaunch | 🍎 | |
| Signing, App Group registration, TestFlight | 🍎 | Signing partner; see APPLE_HANDOFF.md |
| Share Extension | ⏳ (Milestone 2) | |

## Display

| Item | Status | Evidence / notes |
|---|---|---|
| Unit tests (Vitest): 21 tests | ✅ | Shared countdown fixture, revisit dates across DST, ordering, price formatting, privacy filter |
| TypeScript typecheck | ✅ | `npm run typecheck` |
| Production build (Next.js 16.3) | ✅ | `npm run build` |
| Renders at 1920×1080, 3840×2160, 1366×768 | ✅ | Headless Chrome (Windows) screenshots in `docs/display-screens/` |
| Rotation, cross-fade, polling, wake lock, drift, 6 h reload | 📝 | Implemented; checked by eye in the browser, no automated test |
| Readability from ~3 m on the real monitor/TV | ⏳ | Needs a person standing back from the screen |
| Supabase data source | ⏳ (Milestone 4) | |

## Shared contract

| Item | Status |
|---|---|
| `docs/fixtures/countdown-cases.json` passes in Swift **and** TypeScript | ✅ |
