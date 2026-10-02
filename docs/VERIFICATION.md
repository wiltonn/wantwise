# Verification status

What has actually been tested, and where. Update this file whenever something is verified on a new platform. Never mark something verified because it "should work".

| Label | Meaning |
|---|---|
| ✅ **TESTED IN WSL** | Built and tests run in WSL (Ubuntu 24.04, Swift 6.4, Node 22) |
| 📝 **SOURCE AUTHORED — MAC VALIDATION REQUIRED** | Source exists; never compiled against Apple SDKs, never run |
| 🍎 **MAC/XCODE VERIFIED** | Built/run with Xcode on macOS (record Xcode + iOS runtime versions) |
| ⏳ Not started | |

_Last updated: 2026-10-02 (before any Mac session)_

## iOS: domain (WantWiseCore)

| Item | Status | Evidence |
|---|---|---|
| Builds, zero warnings (Swift 6 language mode) | ✅ | `swift build` on Linux |
| 66 tests in 15 suites | ✅ | `swift test`: transitions, decision history, revisit dates (DST), countdown (shared fixture), money, sections, metrics, edits/soft delete, wait choices, reminder planning + diff, image file store, capture inbox + importer (incl. failure rollback), decision wording, screenshot inference |
| Same tests on macOS | 📝 | Expected to pass (Foundation only) |

## iOS: project definition

| Item | Status | Evidence |
|---|---|---|
| `project.yml` generates an Xcode project | ✅ | XcodeGen 2.46.0 built from source on Linux; `xcodegen generate` succeeds. Inspected pbxproj: per-target bundle IDs/entitlements/plists, SDK-conditional signing, embedded extension, local package linked into app + extension only, test hosts, Release exclusion of `debug-sample-*` |
| Info.plists and entitlements are valid plists | ✅ | Python `plistlib` |
| Asset catalog JSON valid; icon 1024², RGB (no alpha) | ✅ | `json.tool`, Pillow |
| Xcode opens/builds the generated project | 📝 | |
| Simulator build with no team (D-026) | 📝 | Fallback documented: `CODE_SIGNING_ALLOWED=NO` |
| `scripts/mac-bootstrap.sh`, `scripts/mac-build.sh` | 📝 | `bash -n` and shellcheck (warning level) clean in WSL; never run on macOS |

## iOS: app source (Apple frameworks)

All files pass `swiftc -parse` (syntax only) in WSL. Syntax-valid is **not** compiled: type errors, API mismatches and isolation errors are only found by Xcode.

An independent pre-Mac review (2026-10-02) checked every file against iOS 17 APIs and the WantWiseCore API. It reproduced language and isolation questions with the Linux Swift compiler in Swift 5 mode. It found and we fixed 4 likely compile errors and 7 runtime/test issues: preview isolation, an inaccessible `PlannedReminder` init, a nested `#require`, a `CFMutableData` bridge, UI-test element queries, the notification cold-launch route, the double launch work, a write during render, the unit-test host store, and the relationship-before-insert order. That lowers the risk; it doesn't replace compiling.

| Area | Files | Status |
|---|---|---|
| SwiftData schema V1 + container | `Persistence/*` | 📝 |
| WantStore (single write path) | `Store/WantStore.swift` | 📝 |
| Image encoding (ImageIO) + image cache | `Shared/ImageEncoding.swift`, `DesignSystem/WantArtwork.swift` | 📝 |
| Local reminders + tap routing | `Notifications/*` | 📝 |
| Screens: list, add/edit, finish adding, detail, reconsider, decided | `Features/**` | 📝 |
| Root, tabs, app environment, launch arguments | `App/*` | 📝 |
| DEBUG sample data, previews, debug menu | `DebugSupport/*` | 📝 |
| Share Extension skeleton | `WantWiseShare/*` | 📝 |
| Unit tests (WantStore, SwiftData, images, reminders, relaunch, import) | `WantWiseTests/*` | 📝 written, never run |
| UI tests (add, relaunch, reconsider) | `WantWiseUITests/*` | 📝 written, never run |
| SwiftUI previews | in each view file | 📝 |

## iOS: behaviour (Milestone 1 loop, CLOUD_MAC_SESSION.md §7)

| Step | Status |
|---|---|
| Launch, empty state | 📝 |
| Add Want (name, price, why, similar, wait) | 📝 |
| Appears on list; survives relaunch | 📝 |
| Picture from Photos becomes the primary image | 📝 |
| Detail shows time remaining | 📝 |
| Reconsider: still want / wait longer / don't need it | 📝 |
| Reminder delivered; tap opens Want | 📝 |
| Layout on iPhone SE / standard / Pro Max | 📝 |
| Share Extension: Photos → Share → WantWise | 📝 (optional in first session) |
| Device install / TestFlight | ⏳ Stage 3 |

## Display

| Item | Status | Evidence |
|---|---|---|
| Unit tests (Vitest): 21 | ✅ | Shared countdown fixture, DST revisit dates, ordering, price formatting, privacy filter |
| Typecheck, production build (Next.js 16.3) | ✅ | |
| Renders at 1920×1080, 3840×2160, 1366×768 | ✅ | Headless Chrome screenshots in `docs/display-screens/` |
| Rotation, cross-fade, polling, wake lock, drift, 6 h reload | 📝 | Implemented; checked by eye only |
| Readability from ~3 m on the real screen | ⏳ | |

## Shared contract

| Item | Status |
|---|---|
| `docs/fixtures/countdown-cases.json` passes in Swift and TypeScript | ✅ |

## Mac session log

_(Add one entry per session: date, provider, macOS, Xcode, iOS runtimes, what was verified, what was fixed.)_
