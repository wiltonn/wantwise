# WantWise — notes for Claude Code

Private family app: native SwiftUI iPhone app (`apps/ios`) + Next.js household Display (`apps/display`). Read `README.md`, then `docs/DECISIONS.md` (append-only, dated) before changing architecture.

## Ground rules

- **Truthful verification.** Track every component in `docs/VERIFICATION.md` as ✅ TESTED IN WSL, 📝 SOURCE AUTHORED — MAC VALIDATION REQUIRED, or 🍎 MAC/XCODE VERIFIED (with Xcode + iOS runtime versions). Never mark something verified that wasn't built and run.
- **No speculative architecture changes** while getting the iOS build green. Fix what the compiler/tests report, minimally, keeping the existing design (D-001…D-030). If a fix needs a real design change, write it as a new dated DECISIONS.md entry and say so.
- **The Xcode project is generated** from `apps/ios/project.yml` (XcodeGen). Never edit `WantWise.xcodeproj` or change settings in Xcode's UI; edit `project.yml` / `apps/ios/Config/*.xcconfig` and regenerate.
- **No Team ID, certificates or signing identities in the repo.** Simulator builds are unsigned (D-026). Device/TestFlight signing is Stage 3 (`docs/APPLE_HANDOFF.md`) and out of scope on the rented Mac.
- **Keep domain logic in `apps/ios/WantWiseCore`** (Foundation only; must still pass `swift test` on Linux). Don't import Apple-only frameworks there.
- **App Store compliance:** keep `apps/ios/Config/PrivacyInfo.xcprivacy` true to the code (D-031) and update `docs/APP_STORE_COMPLIANCE.md` with any change to data, permissions, networking or dependencies. Run the `app-store-reviewer` agent before a TestFlight upload.
- Commit messages end with the attribution lines the harness provides.

## Mac session protocol (rented Mac, Stage 2)

Goal: WantWise builds and runs in an iPhone Simulator and the Milestone 1 loop works. Runbook: `docs/CLOUD_MAC_SESSION.md`.

Loop until green:
1. `apps/ios/scripts/mac-build.sh fast` while fixing compile errors (xcodegen + build only); read `apps/ios/build-logs/summary.md` and `errors.txt`; full log in `build.log`.
2. Fix the reported errors (smallest correct change), rebuild.
3. **After every change that makes progress, commit and push to `main`** (`git pull --rebase` first if needed). The Mac must never hold the only copy of a fix.
4. When it builds: `mac-build.sh test`, then `mac-build.sh uitest`, then `mac-build.sh screens` (review `build-logs/screens/*.png` for layout problems on small/standard/Pro Max).
5. Update `docs/VERIFICATION.md` (Mac session log + status changes) and push.

Useful: `xcrun simctl list devices available`, `xcrun simctl io booted screenshot x.png`, launch args `-WantWiseSampleData -WantWiseResetData -WantWiseInMemory -WantWiseNoReminders` (DEBUG).

Don't: install Homebrew or use `sudo`; add an Apple account/Team ID; start Milestone 2 features; let the Share Extension block Milestone 1.

## Other commands

- Core (any OS): `cd apps/ios/WantWiseCore && swift test`
- Display: `cd apps/display && npm test && npm run typecheck && npm run build`
