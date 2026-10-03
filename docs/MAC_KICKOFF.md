# Mac kickoff (first message for Claude Code on the rented Mac)

Typed prompt on the Mac: `Read docs/MAC_KICKOFF.md and do it.` (Remote-desktop clipboard may not work, so the full prompt lives here.)

---

Read CLAUDE.md and docs/CLOUD_MAC_SESSION.md. We're on the rented Mac (Stage 2). Read apps/ios/build-logs/bootstrap-summary.md, summary.md and errors.txt from the bootstrap.

Work autonomously:

1. Fix compile errors with `apps/ios/scripts/mac-build.sh fast` until the build succeeds. Commit and push each fix to main (`git pull --rebase` first). Smallest correct change; no speculative architecture changes, no signing, no sudo, don't delete tests or functionality to get green.
2. Get `mac-build.sh test` and `mac-build.sh uitest` green. If a test looks wrong, work out why before changing it; don't change WantWiseCore behaviour that passes on Linux.
3. Run `mac-build.sh screens` and review the screenshots (small / standard / Pro Max) for clipping or unusable controls. Fix serious problems only.
4. Run the Milestone 1 acceptance flow from docs/CLOUD_MAC_SESSION.md §6 as far as you can from the terminal: `mac-build.sh run`, `xcrun simctl terminate` / `launch` relaunches, `xcrun simctl io booted screenshot` to check state. Cover: create a Want → appears in list → persists across relaunch → reconsider → decide → decision history → persists across relaunch. Check notification request scheduling/rescheduling/removal through the unit tests.
5. Update docs/VERIFICATION.md: Mac session log entry (date, MacinCloud, macOS, Xcode, iOS runtime versions), move what was actually built and run to 🍎 MAC/XCODE VERIFIED, keep the rest 📝. Commit useful screenshots to docs/ios-screens/. Push.
6. Only then, try the Share Extension (§7). Problems there must not block Milestone 1; document them.

Finish with a report: versions, build result, test results, Simulator devices, acceptance result, Apple-specific bugs fixed, commits, verification status, Share Extension status, what still needs a human tapping in the Simulator, and what needs a physical iPhone.

---

## Follow-up 1 (typed prompt: `Do Follow-up 1 in docs/MAC_KICKOFF.md.`)

`git pull --rebase`. Two fixes were drafted in WSL without a compiler (commit "fix(ios): keep Think about it clear of the Add button; dark Share Extension"):

1. Home: the *Add a Want* button moved from an overlay to a bottom bar (`safeAreaInset`) so it can't cover the ready card's *Think about it* on the iPhone SE.
2. Share Extension: `overrideUserInterfaceStyle = .dark` so the nav title and placeholders aren't black on dark.

Build with `mac-build.sh uitest` (fix compile errors minimally), then `mac-build.sh screens`, and look at `small-home.png`: *Think about it* must not be covered (scrolling to reach it is fine). Re-run the Share Extension flow and screenshot the capture screen to confirm the title and placeholders are readable; replace `docs/ios-screens/small-home.png` and `share-extension.png`. Update the two 📝 entries in docs/VERIFICATION.md to 🍎 only if they pass. Commit, push, and report.

## Follow-up 2 (typed prompt: `Do Follow-up 2 in docs/MAC_KICKOFF.md.`)

`git pull --rebase`. A privacy manifest was added in WSL (`apps/ios/Config/PrivacyInfo.xcprivacy`, D-031, wired into both targets in `project.yml`). Run `mac-build.sh test`, then confirm `find apps/ios/build/DerivedData/Build/Products -name PrivacyInfo.xcprivacy` lists one in `WantWise.app` and one in `WantWise.app/PlugIns/WantWiseShare.appex`. If both are there, change the 📝 part of the "Privacy manifest" row in docs/VERIFICATION.md to 🍎 with the Xcode version, and the matching 📝 note in docs/APP_STORE_COMPLIANCE.md. Then run the `app-store-reviewer` agent and include its report. Commit, push, and report.

## Follow-up 3 (typed prompt: `Do Follow-up 3 in docs/MAC_KICKOFF.md.`)

`git pull --rebase`. Check that a **Release** build ships no debug code or sample images (D-027), unsigned, for the Simulator:

```bash
cd apps/ios && xcodegen generate && xcodebuild -project WantWise.xcodeproj -scheme WantWise -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build
```

Then in `build/DerivedDataRelease/Build/Products/Release-iphonesimulator/WantWise.app`: no `debug-sample-*` files (also inside `Assets.car`: `xcrun assetutil --info`), `strings` on the app binary finds no `WantWiseSampleData` / `WantWiseResetData`, and `PrivacyInfo.xcprivacy` is present in the app and the `.appex`. Install and launch it in a Simulator: no ladybug menu. Record the result in docs/VERIFICATION.md and turn the "Debug code" row in docs/APP_STORE_COMPLIANCE.md to 🍎 only if it passes. Fix minimally if it doesn't. Commit, push, report.

## Follow-up 4 — finish Milestone 2 (typed prompt: `Do Follow-up 4 in docs/MAC_KICKOFF.md.`)

Start this in a **fresh** Claude session (`/clear`, or quit and rerun `claude`) so the `app-store-reviewer` agent is loaded. `git pull --rebase` first.

Read docs/CAPTURE.md, docs/IOS_ROADMAP.md (Milestone 2), docs/DATA_MODEL.md and D-008, D-019, D-028, D-030, D-031 in docs/DECISIONS.md. Milestone 2 is mostly built: the Share Extension saves screenshots, links and text to the App Group inbox, and the app imports them. Finish the parts below. Same rules as before: smallest correct change, keep the existing design, iOS 17 APIs only (D-028), no signing, no sudo, no Milestone 3. Commit and push each part separately once it builds and its tests pass.

**1. Links inside shared text** (CAPTURE.md → Shared text)
When text is shared and it contains an `http`/`https` link, store the first link as the Want's `productURL` (the text stays in `details`). Put the logic in `WantWiseCore` (e.g. `CapturedWant.draft`) with unit tests in `WantWiseCore/Tests`. It must stay Foundation-only and pass `swift test` on **Linux**, so don't use `NSDataDetector` there (not implemented in swift-corelibs-foundation); a whitespace/punctuation token scan + `URL(string:)` with a scheme check is enough. Cover: link mid-sentence, trailing punctuation (`.`, `)`, `,`), several links (first wins), no link, non-http schemes ignored, and an explicit `productURL` winning over text.

**2. Link previews on import** (CAPTURE.md → Shared URL; the extension must not fetch, the app does)
After the app imports a `sharedURL` Want, or a shared-text Want that now has a `productURL`, and only if the Want has **no image**, fetch a preview with `LPMetadataProvider`:
- If the title is still the bare host (or empty), replace it with the page title. Never overwrite a title the child typed.
- If an image is available (`imageProvider`, falling back to `iconProvider` only if nothing else), downsample with the existing `ImageEncoding` path (2048 px, JPEG) and save it as the Want's image through `WantStore`'s normal image path.
- Best effort: background, with a timeout (~15 s); failures leave the Want unchanged; never block import or the UI; don't refetch on every launch (mark it attempted, or only fetch Wants that still have no image and a host-only title, whichever fits the existing model with no schema change; if a schema change seems necessary, stop and explain instead).
- Put the fetch behind a small protocol so unit tests use a fake (no network in tests). Test: title replaced only when host-only, image saved and downsampled, failure/timeout leaves the Want unchanged.
- Verify for real in the Simulator: share a URL (e.g. from Safari in the Simulator, or write a test `CapturedWant` into the inbox) and screenshot the card before/after.

**3. "Take photo" in Add Want** (CAPTURE.md → Photo)
Add a camera option next to the existing PhotosPicker, as a thin `UIImagePickerController` wrapper (`sourceType = .camera`), shown only when `UIImagePickerController.isSourceTypeAvailable(.camera)` is true (so it's hidden in the Simulator). The photo goes through the same downsample + image storage as library picks, with `sourceType` `photo`. Add `NSCameraUsageDescription` to `Config/WantWise-Info.plist` in plain words a child and parent understand (e.g. "WantWise uses the camera so you can take a picture of something you want."). Camera permission is requested by the system only when the child taps Take photo. This can only be built in the Simulator; mark it 📝 for a physical iPhone.

**Not in this follow-up:** Safari "Full Page" PDF capture, Safari JavaScript preprocessing, onboarding for pinning WantWise in the share sheet, and the extension scheduling its own reminder. Leave them as they are in CAPTURE.md.

**Open product question, don't change it:** the extension always has a wait choice selected, so a capture saved without a reason becomes `waiting`, never `captured` ("Finish adding"). CAPTURE.md and DATA_MODEL.md describe `captured` for a quick save without the reflection. Report what the code does and leave it; Nate will decide.

**4. Checks and docs**
- `mac-build.sh uitest` green on iPhone 16 / iOS 18.5 and on iOS 26.3.1; re-run the Share Extension flow for an image **and** a URL (a throwaway UI test is fine; don't commit flaky ones).
- docs/APP_STORE_COMPLIANCE.md: the app now makes network requests (link previews to the shared site, no data sent to us), and requests camera permission with a purpose string. Update the rows; the privacy manifest's collected-data stays empty unless something is sent to a server we control, and `LinkPresentation` adds no required-reason API, but check. Then run the `app-store-reviewer` agent and include its report.
- docs/VERIFICATION.md: rows for each part with 🍎 only for what actually ran; camera 📝 (device). Mac session log entry.
- docs/IOS_ROADMAP.md Milestone 2 status, and docs/CAPTURE.md if behaviour differs from what it says.

Finish with a report: what was built, tests (core/unit/UI counts), what was verified in the Simulator with screenshots, compliance-review result, the captured-vs-waiting finding, and what still needs a physical iPhone.
