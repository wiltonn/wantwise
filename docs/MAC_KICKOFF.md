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
