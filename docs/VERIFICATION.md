# Verification status

What has actually been tested, and where. Update this file whenever something is verified on a new platform. Never mark something verified because it "should work".

| Label | Meaning |
|---|---|
| ✅ **TESTED IN WSL** | Built and tests run in WSL (Ubuntu 24.04, Swift 6.4, Node 22) |
| 📝 **SOURCE AUTHORED — MAC VALIDATION REQUIRED** | Source exists; never compiled against Apple SDKs, never run |
| 🍎 **MAC/XCODE VERIFIED** | Built/run with Xcode on macOS (record Xcode + iOS runtime versions) |
| ⏳ Not started | |

_Last updated: 2026-10-02 (first Mac session: MacinCloud, Xcode 26.3, iOS 18.5 / 18.6 / 26.3.1 Simulators)_

## iOS: domain (WantWiseCore)

| Item | Status | Evidence |
|---|---|---|
| Builds, zero warnings (Swift 6 language mode) | ✅ | `swift build` on Linux |
| 66 tests in 15 suites | ✅ | `swift test`: transitions, decision history, revisit dates (DST), countdown (shared fixture), money, sections, metrics, edits/soft delete, wait choices, reminder planning + diff, image file store, capture inbox + importer (incl. failure rollback), decision wording, screenshot inference |
| Same tests on macOS | 🍎 | `swift test` on macOS 15.7.7 / Xcode 26.3: 66 tests in 15 suites pass |

## iOS: project definition

| Item | Status | Evidence |
|---|---|---|
| `project.yml` generates an Xcode project | ✅ | XcodeGen 2.46.0 built from source on Linux; `xcodegen generate` succeeds. Inspected pbxproj: per-target bundle IDs/entitlements/plists, SDK-conditional signing, embedded extension, local package linked into app + extension only, test hosts, Release exclusion of `debug-sample-*` |
| Info.plists and entitlements are valid plists | ✅ | Python `plistlib` |
| Privacy manifest (D-031) in app + extension | ✅ / 📝 | ✅ `Config/PrivacyInfo.xcprivacy` valid (`plistlib`); XcodeGen in WSL puts it in both targets' Resources phase (not Sources); grep finds no required-reason APIs. 📝 not yet confirmed inside the built `.app` / `.appex` on a Mac |
| Asset catalog JSON valid; icon 1024², RGB (no alpha) | ✅ | `json.tool`, Pillow |
| Xcode builds the generated project | 🍎 | `xcodebuild` Debug Simulator build, Xcode 26.3 (17C529), iOS Simulator SDK 26.2; app + Share Extension + both test bundles |
| Simulator build with no team (D-026) | 🍎 | Builds with `DEVELOPMENT_TEAM` empty; the `CODE_SIGNING_ALLOWED=NO` fallback was **not** needed |
| `scripts/mac-bootstrap.sh`, `scripts/mac-build.sh` | 🍎 | Run on macOS 15.7.7 (no admin). `mac-build.sh` now boots the Simulator before building (otherwise xcodebuild listed no Simulator destinations) and prefers the iPhone SE for `screens` |

## iOS: app source (Apple frameworks)

All files pass `swiftc -parse` (syntax only) in WSL. Syntax-valid is **not** compiled: type errors, API mismatches and isolation errors are only found by Xcode.

An independent pre-Mac review (2026-10-02) checked every file against iOS 17 APIs and the WantWiseCore API. It reproduced language and isolation questions with the Linux Swift compiler in Swift 5 mode. It found and we fixed 4 likely compile errors and 7 runtime/test issues: preview isolation, an inaccessible `PlannedReminder` init, a nested `#require`, a `CFMutableData` bridge, UI-test element queries, the notification cold-launch route, the double launch work, a write during render, the unit-test host store, and the relationship-before-insert order. That lowers the risk; it doesn't replace compiling.

| Area | Files | Status |
|---|---|---|
| SwiftData schema V1 + container | `Persistence/*` | 🍎 compiled; unit tests + on-disk relaunch UI tests |
| WantStore (single write path) | `Store/WantStore.swift` | 🍎 compiled; unit tests |
| Image encoding (ImageIO) + image cache | `Shared/ImageEncoding.swift`, `DesignSystem/WantArtwork.swift` | 🍎 compiled; unit tests (downsampling, replace, unreadable); sample screenshots render |
| Local reminders + tap routing | `Notifications/*` | 🍎 compiled; scheduling logic unit-tested against a fake centre. 📝 real delivery and tap routing |
| Screens: list, add/edit, finish adding, detail, reconsider, decided | `Features/**` | 🍎 compiled; list, add, detail, reconsider, decided exercised by UI tests. 📝 edit, finish adding (not driven) |
| Root, tabs, app environment, launch arguments | `App/*` | 🍎 |
| DEBUG sample data, previews, debug menu | `DebugSupport/*` | 🍎 sample data + "Make one ready" used by UI tests |
| Share Extension skeleton | `WantWiseShare/*` | 🍎 compiles and embeds; behaviour: see below |
| Unit tests (WantStore, SwiftData, images, reminders, relaunch, import) | `WantWiseTests/*` | 🍎 20 tests in 5 suites pass (iOS 18.5 and 26.3.1) |
| UI tests (add, relaunch, reconsider, full Milestone 1 loop) | `WantWiseUITests/*` | 🍎 4 tests pass (iOS 18.5 and 26.3.1) |
| SwiftUI previews | in each view file | 🍎 compile (`ENABLE_PREVIEWS`); 📝 not opened in the canvas |

## iOS: behaviour (Milestone 1 loop, CLOUD_MAC_SESSION.md §6)

| Step | Status |
|---|---|
| Launch, empty state | 🍎 UI tests launch from reset data and add from the empty state |
| Add Want (name, price, why, similar, wait) | 🍎 name/price/why + default wait via UI test; 📝 similar chips and other wait choices not tapped |
| Appears on list; survives relaunch | 🍎 UI tests on the on-disk store; also `simctl terminate`/`launch` without arguments |
| Picture from Photos becomes the primary image | 📝 PhotosPicker not driven (image storage is unit-tested) |
| Detail shows time remaining | 📝 detail opened only for a decided Want |
| Reconsider: still want / wait longer / don't need it | 🍎 wait longer → still want via UI test, with history on detail + Timeline surviving relaunch; "don't need it" unit-tested only |
| Reminder delivered; tap opens Want | 📝 needs a human in the Simulator (§6 check 11) |
| Layout on iPhone SE / standard / Pro Max | 🍎 home screen, `docs/ios-screens/`. SE overlap fixed (Follow-up 1): *Add a Want* is a bottom bar (`safeAreaInset`), so card content scrolls clear of it; at rest the first card's *Think about it* sits under the bar, and one swipe up exposes it and it taps through to the decision screen (throwaway XCUITest on iPhone SE / iOS 18.6) |
| Share Extension: Photos → Share → WantWise | 🍎 iOS 18.5, unsigned: WantWise appears in the share sheet, capture screen shows the screenshot, *Add to WantWise* saves, and the app imports it with the image on next activation (`docs/ios-screens/share-*.png`, driven by a throwaway XCUITest). App Group works through Xcode's simulated entitlements (`group.tech.wantwise.app`). Nav title and placeholders now readable on dark (`overrideUserInterfaceStyle = .dark`, Follow-up 1; capture screen re-checked on iPhone 16 / iOS 18.5) |
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

### 2026-10-02 — MacinCloud (Stage 2, Claude Code)

- **Environment:** macOS 15.7.7 (arm64), Xcode 26.3 (17C529), iOS Simulator SDK 26.2, Simulator runtimes iOS 18.5 (22F77), 18.6 (22G86), 26.3.1 (23D8133). XcodeGen 2.46.0. No admin, no signing.
- **Devices:** iPhone 16 / iOS 18.5 (main loop), iPhone 17 / iOS 26.3.1 (full test run), iPhone SE (3rd gen) / iOS 18.6 (created for small layout), iPhone 16 Pro Max / iOS 18.5.
- **Result:** build green; no Swift compiler warnings (the only warnings are appintentsmetadataprocessor "Metadata extraction skipped"); WantWiseCore 66/66, unit 20/20, UI 4/4 on iOS 18.5 and 26.3.1.
- **Fixed:**
  - Environment: xcodebuild listed no Simulator destinations until CoreSimulator had booted a device; `mac-build.sh` now boots first.
  - Compile: `CaptureImporter.Report` needed a public init (the only compile error).
  - Runtime: the poster artwork's blurred `scaledToFill` layer sized the view, so the ready card's image overflowed its frame and covered *Think about it* (taps never reached it). Caught by `testReconsiderReadySampleWant`.
  - iOS 26: the keyboard toolbar covered the price field after the title had focus; the form now scrolls the focused field to the centre.
- **Added:** `testMilestone1AcceptanceLoop` (§6 checks 4, 6, 8, 9, 10 automated).
- **Share Extension:** works end to end in the Simulator without signing (see table). Not a blocker; real-device App Group needs signing (Stage 3).
- **Still 📝:** PhotosPicker, real notification delivery + tap, edit/finish-adding screens, Dynamic Type.
- **Known layout issues (fixed in Follow-up 1 below):** on the iPhone SE the floating *Add a Want* button covers the ready card's *Think about it* until you scroll; Share Extension nav title is invisible (black on dark).

### 2026-10-02 — MacinCloud, Follow-up 1 (same machine and versions)

- **Built:** commit 1426dea (fixes drafted in WSL) compiled without changes. `mac-build.sh uitest`: WantWiseCore 66/66, unit 20/20, UI 4/4 on iPhone 16 / iOS 18.5. `screens` green on SE / 16 / 16 Pro Max.
- **SE home:** *Add a Want* bar no longer overlays tappable content. A throwaway XCUITest swiped up, checked the *Think about it* and *Add* frames no longer overlap, and tapped through to the decision screen. New `docs/ios-screens/small-home.png` (at rest, the first card's button is still under the bar; scrolling is needed, as intended).
- **Share Extension:** Photos → Share → WantWise via a throwaway XCUITest. The nav title is white and the placeholders are readable (`docs/ios-screens/share-extension.png`). Save/import wasn't re-run this time (verified in the previous session; the change only touches appearance).
