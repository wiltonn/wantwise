# Verification status

What has actually been tested, and where. Update this file whenever something is verified on a new platform. Never mark something verified because it "should work".

| Label | Meaning |
|---|---|
| ✅ **TESTED IN WSL** | Built and tests run in WSL (Ubuntu 24.04, Swift 6.4, Node 22) |
| 📝 **SOURCE AUTHORED — MAC VALIDATION REQUIRED** | Source exists; never compiled against Apple SDKs, never run |
| 🍎 **MAC/XCODE VERIFIED** | Built/run with Xcode on macOS (record Xcode + iOS runtime versions) |
| ⏳ Not started | |

_Last updated: 2026-10-02 (Mac Follow-up 5, D-032: MacinCloud, Xcode 26.3, iOS 18.5 / 26.3.1 Simulators)_

## iOS: domain (WantWiseCore)

| Item | Status | Evidence |
|---|---|---|
| Builds, zero warnings (Swift 6 language mode) | ✅ | `swift build` on Linux |
| 66 tests in 15 suites | ✅ | `swift test`: transitions, decision history, revisit dates (DST), countdown (shared fixture), money, sections, metrics, edits/soft delete, wait choices, reminder planning + diff, image file store, capture inbox + importer (incl. failure rollback), decision wording, screenshot inference |
| Same tests on macOS | 🍎 | `swift test` on macOS 15.7.7 / Xcode 26.3: 66 tests in 15 suites pass |
| Milestone 2: links in shared text (`LinkExtraction`, `CapturedWant.draft`) and link-preview rules (`LinkPreviewRules`) | 🍎 / 📝 | 🍎 `swift test` on macOS: 82 tests in 17 suites pass (16 new: mid-sentence, trailing `.` `)` `,` `!?`, link parentheses kept, several links, no link, non-http schemes, explicit `productURL` wins, link-only text; placeholder titles, preview applied only to placeholder title / missing image). No `NSDataDetector`; Foundation only. 📝 not yet run on Linux: run `swift test` in WSL |

## iOS: project definition

| Item | Status | Evidence |
|---|---|---|
| `project.yml` generates an Xcode project | ✅ | XcodeGen 2.46.0 built from source on Linux; `xcodegen generate` succeeds. Inspected pbxproj: per-target bundle IDs/entitlements/plists, SDK-conditional signing, embedded extension, local package linked into app + extension only, test hosts, Release exclusion of `debug-sample-*` |
| Info.plists and entitlements are valid plists | ✅ | Python `plistlib` |
| Privacy manifest (D-031) in app + extension | ✅ / 🍎 | ✅ `Config/PrivacyInfo.xcprivacy` valid (`plistlib`); XcodeGen in WSL puts it in both targets' Resources phase (not Sources); grep finds no required-reason APIs. 🍎 Xcode 26.3 (17C529): present in the built `WantWise.app` and `WantWise.app/PlugIns/WantWiseShare.appex` (Debug, Simulator) |
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
| Screens: list, add/edit, finish adding, detail, reconsider, decided | `Features/**` | 🍎 compiled; list, add, detail, reconsider, decided exercised by UI tests; finish adding driven by a throwaway XCUITest (Follow-up 5). 📝 edit (not driven) |
| Root, tabs, app environment, launch arguments | `App/*` | 🍎 |
| DEBUG sample data, previews, debug menu | `DebugSupport/*` | 🍎 sample data + "Make one ready" used by UI tests |
| Share Extension skeleton | `WantWiseShare/*` | 🍎 compiles and embeds; behaviour: see below |
| Link previews on import | `LinkPreviews/LinkPreviewFetcher.swift`, `Store/WantStore.swift` | 🍎 compiled; 7 unit tests with a fake fetcher (host title replaced, typed title kept, image downsampled to 2048 px JPEG, shared-text link, Wants with a picture skipped, failure and timeout leave the Want unchanged). 🍎 real `LPMetadataProvider` fetch in the Simulator (see behaviour) |
| Take photo (camera) | `Features/AddWant/CameraPicker.swift`, `AddWantView.swift`, `NSCameraUsageDescription` | 🍎 compiles; purpose string present in the built Info.plist; button correctly hidden in the Simulator (no camera). 📝 camera, permission prompt and saved photo need a physical iPhone |
| Share without a reason → Finish adding (D-032) | `CapturedWant.makeWant`, `WantWiseShare/Capture*.swift` | 🍎 core tests (reason → waiting with its date; nil / empty / whitespace reason → captured with no revisit; past date with a reason → ready); app unit test: import puts the reason-less share in *Finish adding* with no reminder, finishing it schedules one. 📝 core change not yet run on Linux |
| Unit tests (WantStore, SwiftData, images, reminders, relaunch, import, link previews) | `WantWiseTests/*` | 🍎 28 tests in 6 suites pass (iOS 18.5 and 26.3.1) |
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
| Layout on iPhone SE / standard / Pro Max | 🍎 home screen, `docs/ios-screens/`. SE overlap fixed (Follow-up 1): *Add a Want* is a bottom bar (`safeAreaInset`), so card content scrolls clear of it; at rest the first card's *Think about it* sits under the (opaque) bar, and one swipe up exposes it and it taps through to the decision screen (throwaway XCUITest on iPhone SE / iOS 18.6) |
| Share Extension: Photos → Share → WantWise | 🍎 iOS 18.5, unsigned: WantWise appears in the share sheet, capture screen shows the screenshot, *Add to WantWise* saves, and the app imports it with the image on next activation (`docs/ios-screens/share-*.png`, driven by a throwaway XCUITest). App Group works through Xcode's simulated entitlements (`group.tech.wantwise.app`). Nav title and placeholders now readable on dark (`overrideUserInterfaceStyle = .dark`, Follow-up 1; capture screen re-checked on iPhone 16 / iOS 18.5) |
| Share Extension: Safari → Share → WantWise (URL) | 🍎 iOS 18.5 and 26.3.1, unsigned, throwaway XCUITest: capture screen shows the host (`www.apple.com`), *Add to WantWise* saves, the app imports it and the link preview replaces the title with the page title and adds the page image (`docs/ios-screens/share-url-capture.png`, `share-url-imported.png`). On iOS 26 Safari, Share is behind the ••• button |
| Share Extension: Photos → Share (image), re-run | 🍎 iOS 18.5 and 26.3.1: saved and imported with the screenshot (`docs/ios-screens/share-image-imported.png`) |
| Link preview, before/after | 🍎 iPhone 16 / iOS 18.5: a `sharedURL` capture written into the App Group inbox (`https://www.apple.com/airpods-pro/`, title `www.apple.com`) imports with the host title and placeholder art, then within seconds shows "AirPods Pro 3" with the page image (stored as a 1024×537 JPEG in `Images/`). `docs/ios-screens/link-preview-before.png`, `link-preview-after.png` |
| Share without a reason → Finish adding → finish → grid (D-032) | 🍎 iPhone 16 / iOS 18.5, throwaway XCUITest from Photos. With no reason, the extension says "Open WantWise to say why you want it." (`share-saved-no-reason.png`). The share shows under *Finish adding* (`share-no-reason-finish-adding.png`); adding a reason and saving moves it to the grid with "7 days left" (`share-no-reason-finished.png`). With a reason, the extension shows the revisit date and the share goes straight to the grid (`share-saved-with-reason.png`, `share-with-reason-grid.png`) |
| Link inside shared text | 🍎 unit tests only (core + app import). 📝 not shared from a real app (e.g. Notes) in the Simulator |
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

### 2026-10-02 — MacinCloud, Follow-up 3 (same machine and versions)

- **Release build (D-027):** `xcodebuild -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeded. Its only Swift warning is an expected "will never be executed" at `WantWiseApp.swift:66`, because `inMemory` is always false outside DEBUG.
- **Bundle:** `WantWise.app` has no `debug-sample-*` files. `Assets.car` holds only AccentColor, AppIcon and LaunchBackground (`xcrun assetutil --info`).
- **Binary:** `strings` finds no `WantWiseSampleData`, `WantWiseResetData`, `WantWiseInMemory`, `WantWiseNoReminders` or `DebugMenu` in the app or extension binary. As a control, the same search finds them in the Debug `WantWise.debug.dylib`.
- **Privacy manifest:** `PrivacyInfo.xcprivacy` is present in the app and in `PlugIns/WantWiseShare.appex`.
- **Simulator:** installed on iPhone 16 / iOS 18.5 and launched with `-WantWiseSampleData`. The flag was ignored (empty state, no sample Wants) and there's no ladybug menu.
- **Not covered:** a signed archive (Stage 3).

### 2026-10-02 — MacinCloud, Follow-up 4: Milestone 2 capture (same machine and versions)

- **Built:** links in shared text (6a59762), link previews on import (2c1dc48), Take photo (7a2534e). No schema change, no inbox format change.
- **Tests:** WantWiseCore 82/82 (macOS; Linux run still to do), unit 27/27, UI 4/4. `mac-build.sh uitest` green on iPhone 16 / iOS 18.5; `xcodebuild test` green on iPhone 17 / iOS 26.3.1.
- **Simulator:** real link preview fetch verified twice: an inbox capture written by hand, and a real Safari → Share → WantWise share on both runtimes. Image share from Photos re-run on both runtimes. Throwaway XCUITests were not committed.
- **Link previews:** one attempt per import. If it fails (offline, timeout, the site blocks it), the Want keeps its host title and placeholder art and isn't retried on later launches; the child can still add a picture by editing. No ATS exception, so plain-`http` links are fetched only as far as ATS allows (not tested).
- **Captured vs waiting (Follow-up 4's open question):** the extension always has a wait choice selected and always writes `revisitAt`, so every share imported as `waiting`, never `captured`. Nate since decided D-032 (no reason → *Finish adding*); that is Follow-up 5, not done here.
- **Compliance review** (app-store-reviewer, run as a general-purpose agent with its instructions because the agent type wasn't loaded): no blockers. It flagged an untested claim about `http` previews (reworded) and a misleading Milestone 3 line (fixed). Recommendation: mention link-preview traffic in the TestFlight review notes.
- **Still 📝:** camera (physical iPhone), Linux `swift test` for the new core code, shared text from a real app, `http` link previews under ATS.

### 2026-10-02 — MacinCloud, Follow-up 5: D-032 (same machine and versions)

- **Built:** a share imports as `waiting` only when it has a reason (whitespace counts as blank). Otherwise it is `captured` with no `revisitAt` / `waitStartedAt` and shows under *Finish adding*. The extension's "Saved" copy changes when there's no reason. The inbox format stays at v1 (8dd7f2c).
- **Tests:** WantWiseCore 84/84 (macOS), unit 28/28, UI 4/4 on iPhone 16 / iOS 18.5 and iPhone 17 / iOS 26.3.1. `ReminderPlanner` plans only `waiting` Wants; the new unit test confirms a reason-less import gets no reminder and that finishing it schedules one.
- **Simulator:** both flows (no reason → finish → grid; with reason → grid) via a throwaway XCUITest on iOS 18.5 (not committed). Screenshots in `docs/ios-screens/share-*reason*.png`.
- **Fixed:** in *Finish adding*, the keyboard covered *Save*, and return only adds a new line in the multi-line reason field. Neither scrolling nor tapping elsewhere dismissed the keyboard, so a child couldn't save without guessing. Added the same keyboard *Done* button as Add Want, plus `scrollDismissesKeyboard(.interactively)`. Found by driving this screen for the first time.
- **Still 📝:** Linux `swift test` for the core change; this flow on iOS 26.3.1 (only the regular test suite ran there).
