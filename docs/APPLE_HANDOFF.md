# Apple Handoff — instructions for the build/signing partner

WantWise is a private family iPhone app. You've kindly agreed to sign it with your Apple Developer account and distribute it to one family over TestFlight. You don't need to understand the app's architecture to do this.

> **Status**: Draft. The Xcode project spec exists but hasn't been built on a Mac yet. Expect the first session to include fixing a few compile errors; the project owner can do that work with you or from a pushed branch.

## What you'll need

- A Mac with the latest stable Xcode
- Homebrew (or Mint) to install **XcodeGen**
- Your Apple Developer account (Team ID, App Store Connect access)
- About 1–2 hours for the first session; ~15 minutes for later builds

## One-time setup

### 1. Agree identifiers with the project owner (before registering anything)

The proposed identifiers are placeholders:

| Item | Proposed value |
|---|---|
| App bundle ID | `tech.wantwise.app` |
| Share Extension bundle ID | `tech.wantwise.app.share` |
| App Group | `group.tech.wantwise.app` |

If any are already taken, or you'd rather use your own namespace (e.g. `com.yourname.wantwise`), that's fine — choose them together. They're set in one file (step 3) and nothing in the code hard-codes them. **Please read "Ownership implications" below first.**

### 2. Clone and install tools

```bash
brew install xcodegen
git clone https://github.com/wiltonn/wantwise.git
cd wantwise/apps/ios
```

### 3. Create your local signing config (not committed)

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Edit `Config/Signing.local.xcconfig`:

```
WANTWISE_TEAM_ID = ABCDE12345            // your Team ID (developer.apple.com → Membership)
WANTWISE_BUNDLE_PREFIX = tech.wantwise   // only if you agreed different identifiers
```

This file is git-ignored. Your Team ID never enters the public repo.

### 4. Generate and open the project

```bash
xcodegen generate
open WantWise.xcodeproj
```

Don't edit project settings in Xcode — they're regenerated from `project.yml` each time. If something must change, tell the project owner (or change `project.yml` / the xcconfig and regenerate).

### 5. Register identifiers (Automatic signing does most of this)

1. Xcode → Settings → Accounts → make sure your team is signed in.
2. Select the **WantWise** target → Signing & Capabilities: *Automatically manage signing* should be on with your team. Xcode registers the App ID.
3. Do the same for the **WantWiseShare** target.
4. Confirm both targets show the **App Groups** capability with the agreed group ID ticked. If Xcode can't create it, register it at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → App Groups, then enable it on both App IDs.

### 6. Build and check in the Simulator

```bash
xcodebuild -scheme WantWise -destination 'platform=iOS Simulator,name=iPhone 16' test
```

(`xcrun simctl list devices available` shows valid simulator names.)

### 7. Create the App Store Connect record

App Store Connect → Apps → **+** → New App: platform iOS, name "WantWise" (or an available variant, e.g. "WantWise Family"), primary language English (Canada), the agreed app bundle ID, any SKU (e.g. `wantwise-001`).

### 8. Archive and upload

1. Destination: **Any iOS Device (arm64)**.
2. Product → Archive.
3. Organizer → Distribute App → **App Store Connect** → Upload.

Export compliance is pre-answered in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).

### 9. TestFlight

- **External testing** (recommended): create a group (e.g. "Family"), add the project owner's and the child's Apple ID emails. The first build of a version needs a short **Beta App Review** (usually under a day). Later builds of the same version usually don't.
- *Internal testing* would require adding them to your Developer team in App Store Connect — probably not what you want.
- Testers install the **TestFlight** app on their iPhone and accept the invite.

TestFlight builds expire after **90 days**. A new build is needed at least that often.

## Later builds

```bash
cd wantwise && git pull
cd apps/ios && xcodegen generate
# bump build number if asked to (CURRENT_PROJECT_VERSION in Config/Base.xcconfig is committed)
# Product → Archive → Distribute → Upload
```

## Ownership implications (read before registering identifiers)

Using your account has consequences that are hard to undo later. The project owner has accepted these knowingly (DECISIONS.md D-018); they're listed so everyone is clear.

1. **Your team owns the bundle IDs and the App Group.** Once registered and used in App Store Connect, assume those identifiers stay with your team permanently.
2. **A TestFlight-only app can't be transferred to another account.** Apple's app-transfer criteria require "at least one version that was released to the App Store" ([App transfer criteria](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria)). WantWise is TestFlight-only, so if the project owner later gets their own account, it will be a **new app with a new bundle ID**, not a transfer.
3. **To iOS, a new bundle ID is a different app, so on-device data doesn't carry over.** Moving accounts means installing a separate app. Mitigation already in the plan: from Milestone 3, data syncs to Supabase, so moving becomes "install the new app, sign in". Before Milestone 3, data lives only on the phone. The project keeps long-lived data out of the App Group container (D-019) so that the team-specific group ID doesn't strand it.
4. **TestFlight testers, builds and the App Store Connect record** belong to your account. The project owner can't manage testers themselves unless you add them to your team.
5. **Supabase, the Display and the GitHub repo are not tied to your account.** Only the iPhone app's signing and distribution are.
6. **If you stop being able to help**: existing TestFlight builds keep working until they expire (90 days). After that, someone else's account has to ship a new app (see point 2).
