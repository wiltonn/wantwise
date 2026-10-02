# Cloud Mac session runbook (Stage 2: Simulator validation)

**Objective:** WantWise builds and runs in an iPhone Simulator, and the Milestone 1 loop works.

**Not needed, not attempted:** Apple Developer account, Team ID, signing certificate, physical iPhone, TestFlight (Stage 3: [APPLE_HANDOFF.md](APPLE_HANDOFF.md)), Homebrew, `sudo`.

The session is designed for **Claude Code on the Mac** working autonomously through build → inspect errors → edit → rebuild → test, pushing every fix to `main`.

---

## 1. Requirements

| | Recommended | Minimum |
|---|---|---|
| macOS | the version the current stable Xcode requires | macOS 14 |
| Xcode | current stable release, preinstalled | Xcode 16 (Swift Testing; iOS 17 deployment target) |
| iOS Simulator runtime | any iOS 17 or newer (usually bundled with a preinstalled Xcode) | one iOS runtime |
| CPU | Apple Silicon | Intel works, slower |
| Free disk | 20 GB | 8 GB if an iOS runtime is already installed |
| Access | normal user account with GUI (VNC/remote desktop) + Terminal | Terminal only works, but you can't watch the Simulator |
| Billing | hourly | avoid 24-hour-minimum hosts for a 3–4 hour job |

Disk breakdown: iOS Simulator runtime ~8–10 GB if it has to be downloaded; DerivedData ~2–3 GB; extra Simulator devices ~0.5 GB each; Claude Code ~0.3 GB; XcodeGen ~15 MB (~0.5 GB if built from source).

### Is admin/root needed?

**No**, on a typical rented Mac where Xcode is preinstalled and has been opened once. The bootstrap uses `DEVELOPER_DIR` instead of `sudo xcode-select`, installs XcodeGen and Claude Code into your home folder, and builds unsigned for the Simulator.

Admin is needed **only** if the bootstrap reports one of these (each is a one-time provider setup issue):

| Bootstrap blocker | One-time fix (admin) |
|---|---|
| Xcode license not accepted | `sudo xcodebuild -license accept` |
| First-launch components missing and `xcodebuild -runFirstLaunch` fails as a user | `sudo xcodebuild -runFirstLaunch` (or open Xcode.app once and accept) |
| No iOS runtime and the user-level download fails | Xcode → Settings → Components → iOS → Get |

If you have no admin rights and hit one, ask the provider or pick an image with Xcode ready to use.

## 2. Before the clock starts (free)

- [ ] **GitHub token** for pushing from the Mac: github.com → Settings → Developer settings → Fine-grained tokens → repository `wiltonn/wantwise`, permission **Contents: Read and write**, expiry 7 days. Keep it handy; you'll paste it once as the password.
- [ ] **Claude account** with Claude Code access (Pro/Max/Team/Enterprise or a Console API key). Have the login ready for the browser on the Mac (or an API key).
- [ ] **Provider** picked per §1, with remote-desktop (GUI) access.
- [ ] In WSL: `git status` clean and pushed (it is, as of this commit).

## 3. Bootstrap (paste into Terminal on the Mac)

```bash
git config --global user.name "Nate"
git config --global user.email "YOUR_EMAIL"
curl -fsSL https://raw.githubusercontent.com/wiltonn/wantwise/main/apps/ios/scripts/mac-bootstrap.sh -o /tmp/ww-bootstrap.sh && bash /tmp/ww-bootstrap.sh
```

It:
1. checks macOS, Xcode (selects it for your user if needed), the license/first-launch state, the iOS Simulator runtime (downloads one if missing), and Git;
2. clones `~/wantwise`;
3. installs **XcodeGen 2.46.0** (prebuilt zip into `~/.local/xcodegen`; builds from source if the binary won't run);
4. writes `~/.wantwise-env` (PATH, DEVELOPER_DIR) and loads it from `~/.zshrc`/`~/.bash_profile`;
5. runs `apps/ios/scripts/mac-build.sh test`: WantWiseCore tests → `xcodegen generate` → **unsigned Simulator build** → unit tests;
6. writes `apps/ios/build-logs/bootstrap-summary.md`, `summary.md` and `errors.txt`.

Expected result on the first run: **"NEEDS FIXES"** with compile errors listed. The app code has never been compiled; that's what the session is for. Blockers (missing Xcode, license, runtime) are listed separately.

Re-runnable at any time: `bash ~/wantwise/apps/ios/scripts/mac-bootstrap.sh`.

### If XcodeGen can't be installed

In order of preference:
1. The bootstrap already falls back to building from source with the Xcode toolchain (`~/.local/src/XcodeGen`, no admin).
2. Manually: download `xcodegen.zip` from https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0 in the browser, unzip, and put the `xcodegen` folder at `~/.local/xcodegen` (keep `bin/` and `share/` together). If macOS quarantines the browser download: `xattr -dr com.apple.quarantine ~/.local/xcodegen` (your own files; no admin).
3. Last resort: ask Claude in WSL to generate the project there (XcodeGen runs on Linux) and push it to a temporary branch `xcodeproj-snapshot`. Then on the Mac: `git fetch origin xcodeproj-snapshot && git checkout origin/xcodeproj-snapshot -- apps/ios/WantWise.xcodeproj`. Regenerate it whenever `project.yml` changes, and never merge that branch.

## 4. Start Claude Code (right after the bootstrap finishes)

Start it **as soon as the bootstrap prints its summary**, whether the result is GREEN or NEEDS FIXES. Resolve any **Blockers** first (§1); Claude can't fix a missing Xcode license.

```bash
# 1. Install (user-level: ~/.local/bin; no admin, no Node)
curl -fsSL https://claude.ai/install.sh | bash

# 2. New Terminal window (or: source ~/.zshrc), then check
claude --version

# 3. Let git remember your GitHub token so Claude's pushes don't stall on a password prompt
cd ~/wantwise && git push --dry-run origin main
#    Username: your GitHub username   Password: the fine-grained token (stored in the macOS keychain)

# 4. Start Claude Code in the repo, auto-accepting file edits
claude --permission-mode acceptEdits
```

First run opens a browser to log in (or, if `ANTHROPIC_API_KEY` is set, asks you to approve the key). The repo's `.claude/settings.json` pre-approves the build, test and git commands (and denies `sudo` and force-push), and `CLAUDE.md` gives Claude the session protocol.

**Paste this as the first message:**

> Read CLAUDE.md and docs/CLOUD_MAC_SESSION.md. We're on the rented Mac (Stage 2). Read apps/ios/build-logs/bootstrap-summary.md, summary.md and errors.txt from the bootstrap. Work autonomously: fix compile errors with `apps/ios/scripts/mac-build.sh fast` until the build succeeds, committing and pushing each fix to main. Then get `mac-build.sh test` and `mac-build.sh uitest` green, run `mac-build.sh screens` and review the three screenshots for layout problems. Don't make speculative architecture changes, don't add signing, and don't use sudo. When everything is green, update docs/VERIFICATION.md (add a Mac session log entry with macOS, Xcode and iOS runtime versions) and push. Then tell me which manual checks in §6 of the runbook I should do in the Simulator.

While it works you can watch the Simulator; `mac-build.sh run` launches the app with sample data.

## 5. The automated loop (what Claude runs)

| Command (from `~/wantwise`) | Does | Typical time |
|---|---|---|
| `apps/ios/scripts/mac-build.sh fast` | xcodegen + Debug Simulator build | 30–90 s incremental |
| `apps/ios/scripts/mac-build.sh` | + WantWiseCore tests | +20 s |
| `apps/ios/scripts/mac-build.sh test` | + unit tests (SwiftData, WantStore, images, reminders, relaunch, capture import) | 1–2 min |
| `apps/ios/scripts/mac-build.sh uitest` | + UI tests (add Want, relaunch persistence, reconsider) | 2–4 min |
| `apps/ios/scripts/mac-build.sh run` | adds sample screenshots to Photos, installs, launches with sample data | 30 s |
| `apps/ios/scripts/mac-build.sh screens` | launches on small / standard / Pro Max, saves `build-logs/screens/*.png` | 1–3 min |

Every run writes `apps/ios/build-logs/summary.md` (environment + per-step results) and `errors.txt` (deduplicated errors, paths relative to `apps/ios`). If a Simulator build ever demands a development team, the script retries with `CODE_SIGNING_ALLOWED=NO` automatically and notes it in the summary (D-026).

## 6. Milestone 1 validation (after the build is green)

Automated first (Claude): `test`, `uitest`, `screens`. Then by hand in the Simulator (≈20 minutes). Start with `apps/ios/scripts/mac-build.sh run`.

| # | Check | How | Pass when |
|---|---|---|---|
| 1 | **Launch** | `mac-build.sh run` | Home "Thinking about" appears; no crash |
| 2 | **Sample data** | (launched with `-WantWiseSampleData`) | Ready card (Kart racing game), "Finish adding" (star projector), grid with screenshots; Decided tab has 3 items |
| 3 | **Want list** | scroll | Screenshots crop sensibly; countdown chips; progress bars; no clipped text |
| 4 | **Add Want** | *+ Add a Want* → name, price `49`, reason, similar *Yes*, *7 days* → *Add to my list* | Confirmation "Let's think about this again on …"; card appears |
| 5 | **Image selection** | Add a Want → *Add a screenshot or photo* → pick a sample screenshot (added to Photos by the script) | Preview shows; saved Want shows the image on its card |
| 6 | **Persistence** | ⌘⇧H, then kill: `xcrun simctl terminate booted <bundle id>`; relaunch **without** arguments: `xcrun simctl launch booted <bundle id>` | Your Wants (and images) are still there |
| 7 | **Want detail** | tap a card | Picture, title, price, "N days left", progress, "Think again …", Why, History |
| 8 | **Reconsideration** | ladybug → *Make one ready to think again*; *Think about it* → *Wait longer* → 3 days; then reconsider again → *Still want it* (or *I don't need it anymore*) | Confirmation screens; Want moves to Decided |
| 9 | **Decision history** | open that Want; Decided tab → *Timeline* | "Chose to wait longer, until …", then the decision; timeline lists both |
| 10 | **Relaunch persistence** | relaunch again | Decisions and history still there |
| 11 | **Local notifications** | relaunch without `-WantWiseNoReminders`; add a waiting Want → **Allow** notifications; ladybug → *Send a reminder in 10 seconds* → ⌘⇧H | Banner appears; tapping opens the Want. (Local notifications work in the Simulator.) |
| 12 | **Small layout** | `screens` output `small-home.png`, plus run on the small device by hand | Nothing clipped or overlapping; bottom button clear of content |
| 13 | **Standard layout** | `standard-home.png` | as above |
| 14 | **Pro Max layout** | `promax-home.png` | as above |

Bundle id for `simctl` commands: shown in `build-logs/summary.md` runs, or `tech.wantwise.app` (placeholder, D-022).

Optional Dynamic Type check: Simulator → Settings → Accessibility → Display & Text Size → Larger Text.

## 7. Share Extension (only after §6 is green; must not block Milestone 1)

1. Simulator → **Photos** → open a sample screenshot → **Share** → scroll the app row (or **More**) → **WantWise**.
2. Type a reason, pick 3 days, **Add to WantWise**, and you should see "Saved".
3. Open WantWise; the Want appears with the screenshot.

If it says the App Group isn't configured, the unsigned Simulator build didn't get the App Group entitlement. Record that in VERIFICATION.md as a Milestone 2 item and move on. Don't add signing to work around it.

## 8. Resetting

| Need | Command |
|---|---|
| Fresh app data | launch with `-WantWiseResetData`, or delete the app in the Simulator |
| Reset notification permission | delete the app, reinstall (`mac-build.sh run`) |
| Wipe one Simulator | `xcrun simctl shutdown <udid>; xcrun simctl erase <udid>` |
| Wipe build products | `rm -rf ~/wantwise/apps/ios/build` |

## 9. Before you stop paying

- [ ] `cd ~/wantwise && git status` clean and `git log origin/main..HEAD` empty (everything pushed).
- [ ] `docs/VERIFICATION.md` has a Mac session log entry: date, provider, macOS, Xcode, iOS runtime(s), what moved to 🍎 MAC/XCODE VERIFIED, what's still 📝.
- [ ] Layout screenshots committed if useful (`docs/ios-screens/`).
- [ ] Revoke the GitHub token (or let it expire) and sign Claude Code out (`/logout`) if the machine is shared.
