# Cloud Mac session runbook (Stage 2: Simulator validation)

**Goal of the first session:** WantWise builds and runs in an iPhone Simulator, and the Milestone 1 loop works:
add → see it → relaunch → still there → see time left → reconsider (still want / wait longer / don't need it).

**Not goals for this session:** physical iPhone, signing, TestFlight. Those are Stage 3 (signing partner, [APPLE_HANDOFF.md](APPLE_HANDOFF.md)). **No Apple Developer account or Team ID is needed for anything in this runbook** (D-026).

Budget: one 3–4 hour block should cover it. Keep a timer running.

---

## 0. Before you rent (free, in WSL)

- [ ] `git status` clean and pushed in WSL. The Mac clones from GitHub, so unpushed work doesn't exist there.
- [ ] Pick a provider offering **hourly** billing, **macOS 15 or newer**, and **Xcode 16 or newer preinstalled** (Swift Testing needs Xcode 16+). Avoid providers with a 24-hour minimum (e.g. AWS EC2 Mac dedicated hosts) for a 3-hour job. Check current prices: they change.
- [ ] Decide how you'll fix compile errors (see §6). **Recommended:** install Claude Code on the Mac so it can edit, build and retry directly. That's much faster than copying errors back and forth.
- [ ] Have your GitHub credentials ready (a fine-grained personal access token with read/write to `wiltonn/wantwise`, or `gh auth login`).

## 1. First 10 minutes: check the machine

Open **Terminal**.

```bash
sw_vers                                  # macOS version
xcodebuild -version                      # want Xcode 16.0 or newer
xcode-select -p                          # should print /Applications/Xcode.app/Contents/Developer
xcrun simctl list runtimes | grep iOS    # need at least one iOS runtime (17.x or newer)
```

If `xcode-select -p` points at CommandLineTools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

If there's no iOS runtime: Xcode → Settings → Components (or Platforms) → iOS → Get. (Large download; this is the most common time sink on fresh machines.)

## 2. Install XcodeGen

```bash
brew --version || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
xcodegen --version        # validated with 2.46.0
```

No Homebrew and can't install it? Build from source (a couple of minutes):

```bash
git clone --depth 1 https://github.com/yonaskolb/XcodeGen.git /tmp/XcodeGen
(cd /tmp/XcodeGen && swift build -c release --product xcodegen)
sudo cp /tmp/XcodeGen/.build/release/xcodegen /usr/local/bin/
```

## 3. Clone

```bash
cd ~
git clone https://github.com/wiltonn/wantwise.git
cd wantwise
git config user.name "Nate"
git config user.email "<your email>"
git log --oneline | head -5        # confirm you have the latest commit from WSL
```

## 4. One command: generate, build, test

```bash
cd ~/wantwise/apps/ios
./scripts/mac-build.sh             # core tests → xcodegen → Simulator build
```

What it does: checks tools, runs `WantWiseCore` tests, runs `xcodegen generate`, picks an available iPhone Simulator, builds Debug. On failure it prints a deduplicated error list and saves it to `apps/ios/build-logs/errors.txt` (full logs alongside).

Then, once it builds:

```bash
./scripts/mac-build.sh test        # + unit tests (SwiftData, WantStore, images, reminders, capture import)
./scripts/mac-build.sh uitest      # + UI tests (add Want, relaunch persistence, reconsider)
./scripts/mac-build.sh run         # build, install, launch in the Simulator with sample Wants
```

Manual equivalents, if you prefer:

```bash
xcodegen generate
xcrun simctl list devices available | grep iPhone           # pick a name
xcodebuild -project WantWise.xcodeproj -scheme WantWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project WantWise.xcodeproj -scheme WantWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WantWiseTests test
```

## 5. Open in Xcode (for previews and running by hand)

```bash
open WantWise.xcodeproj
```

- Scheme: **WantWise**. Destination (top bar): any **iPhone Simulator** (e.g. iPhone 16), *not* "Any iOS Device".
- ⌘R to run. ⌘U to run tests.
- Previews: open e.g. `WantWise/Features/WantList/WantListView.swift`, then Editor → Canvas (⌥⌘↩). Previews use in-memory sample data.
- **Don't change project settings in Xcode.** They're regenerated from `project.yml`. If a setting must change, edit `project.yml` or `Config/*.xcconfig`, run `xcodegen generate`, and commit.

### Sample data and launch arguments (DEBUG builds)

Edit Scheme → Run → Arguments → *Arguments Passed On Launch*, or pass to `simctl launch`:

| Argument | Effect |
|---|---|
| `-WantWiseSampleData` | Loads 11 realistic sample Wants (with screenshots) if the store is empty |
| `-WantWiseResetData` | Deletes the on-disk store and images before launch |
| `-WantWiseInMemory` | Throwaway in-memory store |
| `-WantWiseNoReminders` | Never schedules reminders or asks for notification permission |

The **ladybug** button on the home screen (DEBUG only) can: load sample Wants, make one ready to reconsider now, send a reminder in 10 seconds, delete everything.

## 6. Fixing build errors (the expected part)

This code was written without a compiler for Apple frameworks, so expect a round of fixes. Two ways to work:

**A. Claude Code on the Mac (recommended, fastest)**

```bash
# needs Node 18+; Homebrew: brew install node
npm install -g @anthropic-ai/claude-code
cd ~/wantwise && claude
```

Then tell it: *"Read docs/CLOUD_MAC_SESSION.md. Run apps/ios/scripts/mac-build.sh, fix the errors, rebuild until it succeeds, then run the test and uitest modes. Commit each fix with a clear message and push to main."*

**B. Copy errors back to the WSL session**

```bash
cat apps/ios/build-logs/errors.txt      # paste this into Claude in WSL
```

Claude fixes and pushes from WSL; on the Mac: `git pull && ./scripts/mac-build.sh`. Slower, since each round trip costs Mac minutes.

Either way: **commit and push after each successful fix**, not at the end.

### Common signing messages (and why you can ignore signing today)

| Message | What to do |
|---|---|
| "Signing for 'WantWise' requires a development team" | You picked **Any iOS Device**. Pick an **iPhone Simulator** destination. Simulator builds sign "to run locally" with no team (D-026). |
| Same message even with a Simulator selected | Add `CODE_SIGNING_ALLOWED=NO` to the command line: `xcodebuild … CODE_SIGNING_ALLOWED=NO build`. Note it in DECISIONS.md and tell Claude, so the project can be adjusted. |
| "Provisioning profile … doesn't include the App Groups entitlement" | Device build: Stage 3, not today. |
| "No such module 'WantWiseCore'" | File → Packages → Reset Package Caches, then build again. In the CLI: delete `build/DerivedData` and rerun. |

## 7. The Milestone 1 behaviour check (in the Simulator)

Run with **no** launch arguments for the real flow (or `-WantWiseResetData` once to start clean).

1. **Launch** → empty state "Seen something you want?"
2. **Add a Want** → name "Test headphones", price `49`, reason "Mine hurt my ears", similar **Yes**, **7 days** → *Add to my list*.
   - Expect: confirmation "Let's think about this again on <day 7 days ahead>."
   - Expect: notification permission prompt (first waiting Want). Tap **Allow**.
3. **See it on the list**: a card with "7 days left" and a thin progress bar.
4. **Add one with a picture**: drag any image file onto the Simulator window to add it to Photos (or use a screenshot taken with ⌘S in the Simulator), then *Add a screenshot or photo* in the form. The card should show the picture.
5. **Relaunch**: stop with ⌘. in Xcode (or `xcrun simctl terminate booted <bundle id>`), run again. Both Wants still there, with pictures.
6. **Open a Want**: shows "N days left", "Think again <day>", history "Added to the list".
7. **Reconsider**: ladybug → *Make one ready to think again* (or "Think about it now" on the detail screen). Choose **Wait longer** → 3 days → confirmation. Reopen: history shows "Chose to wait longer, until <day>".
8. **Decide**: reconsider again → **Still want it** or **I don't need it anymore** → it moves to the **Decided** tab with "Thought about it for …".
9. **Notifications**: ladybug → *Send a reminder in 10 seconds* → immediately press ⌘⇧H (Home). The banner should appear. Tapping it opens the Want.
10. **Delete**: detail → ••• → Remove → gone from lists.

Record anything odd in `docs/VERIFICATION.md` (or tell Claude).

## 8. Device sizes

```bash
xcrun simctl list devices available | grep -E "iPhone (SE|1[5-9])"
```

Check at least: **iPhone SE (3rd generation)** (smallest), a standard **iPhone 16**, and a **Pro Max**. In Xcode, switch the destination and ⌘R; or build with `-destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'`. Look for clipped text, cramped cards, and the bottom "Add a Want" button overlapping content. Also check Dynamic Type: Settings app in the Simulator → Accessibility → Display & Text Size → Larger Text.

Screenshots: ⌘S in the Simulator saves to the Desktop. Commit a few to `docs/ios-screens/`.

## 9. Resetting the Simulator

| Need | Command |
|---|---|
| Fresh app data only | launch with `-WantWiseResetData`, or delete the app from the Simulator home screen |
| Reset notification permission | delete the app and reinstall (permission is per install) |
| Wipe a whole Simulator | `xcrun simctl erase <udid>` (shut it down first: `xcrun simctl shutdown all`) |
| Wipe everything | `xcrun simctl erase all` |

## 10. Optional if time remains: Share Extension smoke test

The extension skeleton is built and embedded already (Milestone 2 prep).

1. In the Simulator, open **Photos**, pick an image → Share → (scroll the app row; you may need **More**) → **WantWise**.
2. Enter a reason, pick 3 days, **Add to WantWise**.
3. Open WantWise: the Want appears with the image.

If step 2 says the App Group isn't configured, App Group entitlements weren't applied to the unsigned Simulator build. Note it in VERIFICATION.md. It doesn't block Milestone 1.

## 11. Before you stop paying

- [ ] All fixes committed and **pushed** (`git status` clean, `git log origin/main..HEAD` empty).
- [ ] `docs/VERIFICATION.md` updated: what was **MAC/XCODE VERIFIED** today (build, which test suites, which manual steps, which devices).
- [ ] Screenshots committed (optional).
- [ ] Note the exact Xcode and iOS runtime versions used in VERIFICATION.md.
- [ ] Sign out of GitHub on the Mac / revoke the token if it's shared hardware.
