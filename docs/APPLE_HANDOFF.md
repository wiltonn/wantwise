# Apple handoff (Stage 3: signing, provisioning, TestFlight)

For the friend who signs and distributes WantWise with their Apple Developer account.

> **Not needed yet.** Stage 2 ([CLOUD_MAC_SESSION.md](CLOUD_MAC_SESSION.md)) must succeed first: WantWise builds, tests and runs in the iPhone Simulator without any Apple account. This document starts where that one ends.

WantWise is a private family iPhone app (one parent, one child). You don't need to understand its architecture. Everything you need is in this file, and nothing team-specific lives in the public repository.

---

## What we're asking you to do

1. Register two App IDs and one App Group under your team (identifiers agreed with Nate first).
2. Build and sign WantWise on a Mac with your team.
3. Upload it to App Store Connect and distribute it via **TestFlight** to Nate's and his child's Apple IDs.
4. Repeat steps 2–3 when there's a new version (about 15 minutes), and at least every 90 days (TestFlight builds expire).

No App Store release, no payments, no in-app purchases, no push notifications.

## What we need from you

| Item | Why |
|---|---|
| Your **Team ID** (10 characters; developer.apple.com → Membership details) | Goes in a local, git-ignored file on the Mac that builds. Never committed. |
| Agreement on the **identifiers** below (or your preferred namespace) | They're registered to your team and hard to change later. |
| An **App Store Connect app record** for WantWise | TestFlight lives there. |
| Inviting Nate and his child as **external TestFlight testers** | Installs on their iPhones. |

## What you do NOT need to share or grant

- No access to your Apple ID password, certificates or private keys for anyone else. Signing happens on a Mac you control.
- No need to add Nate to your Developer team or App Store Connect (external testers don't need it).
- No access to the GitHub repo beyond public read (it's public). You don't need to push anything.
- No Supabase, server or household-display access. Those aren't tied to your account.
- No App Store review of a public listing (only TestFlight's Beta App Review for external testers).

## Identifiers

Placeholders in the repo today (`apps/ios/Config/Base.xcconfig`, D-022):

| Purpose | Build setting | Placeholder |
|---|---|---|
| App bundle ID | `WANTWISE_APP_BUNDLE_ID` | `tech.wantwise.app` |
| Share Extension bundle ID | `WANTWISE_SHARE_BUNDLE_ID` | `tech.wantwise.app.share` (must be prefixed by the app's ID) |
| App Group | `WANTWISE_APP_GROUP` | `group.tech.wantwise.app` |

All three derive from one value, `WANTWISE_BUNDLE_PREFIX = tech.wantwise`. If those are taken, or you'd prefer `com.<you>.wantwise`, override the prefix in your local `Signing.local.xcconfig` (below). Then tell Nate the final values so they're recorded in DECISIONS.md.

## Capabilities

| Target | Capability | Notes |
|---|---|---|
| WantWise (app) | **App Groups** → the agreed group | Only used for the Share Extension handoff folder |
| WantWiseShare (extension) | **App Groups** → same group | |

Not used: Push Notifications (reminders are *local* notifications, which need no capability), iCloud, Sign in with Apple, In-App Purchase. Entitlements files are in the repo (`apps/ios/Config/*.entitlements`) and take the group ID from the build setting.

## One-time setup on your Mac

```bash
brew install xcodegen
git clone https://github.com/wiltonn/wantwise.git
cd wantwise/apps/ios
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Edit `Config/Signing.local.xcconfig` (git-ignored):

```
WANTWISE_TEAM_ID = ABCDE12345
// only if you changed the namespace:
// WANTWISE_BUNDLE_PREFIX = com.yourname.wantwise
```

Then:

```bash
xcodegen generate
open WantWise.xcodeproj
```

### Register identifiers and provisioning

Easiest: **automatic signing** (already configured for device builds).

1. Xcode → Settings → Accounts: your team is signed in.
2. Select a **real device or "Any iOS Device (arm64)"** as destination. Simulator builds deliberately don't use your team.
3. Target **WantWise** → Signing & Capabilities: Team should show your team (from `WANTWISE_TEAM_ID`), "Automatically manage signing" on. Xcode registers the App ID and creates profiles.
4. Same for **WantWiseShare**.
5. If App Groups shows an error, register the group at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **App Groups** (+), then enable App Groups on both App IDs with that group, and click "Try Again" in Xcode.

Please **don't change settings in Xcode's UI**: the project is regenerated from `project.yml`. If something has to change, tell Nate, or change `project.yml`/xcconfig, regenerate, and send the diff.

## App Store Connect record

App Store Connect → Apps → **+** → New App:
- Platform: iOS
- Name: "WantWise" (if taken: "WantWise Family")
- Primary language: English (Canada)
- Bundle ID: the agreed app ID
- SKU: anything, e.g. `wantwise-001`
- User access: Full access (default)

## Archive and upload

1. Destination: **Any iOS Device (arm64)**. Scheme **WantWise**.
2. Bump the build number if this version was uploaded before: edit `CURRENT_PROJECT_VERSION` in `apps/ios/Config/Base.xcconfig` (and commit/send the change), then `xcodegen generate`.
3. Product → **Archive**.
4. Organizer → Distribute App → **TestFlight & App Store** (or "App Store Connect") → Upload. Defaults are fine.
5. Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption = NO`).

CLI alternative:

```bash
xcodebuild -project WantWise.xcodeproj -scheme WantWise -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/WantWise.xcarchive archive
```

(then upload from Organizer, or `xcodebuild -exportArchive` with an ExportOptions.plist using method `app-store-connect`).

## TestFlight and testers

1. App Store Connect → WantWise → TestFlight. Wait for processing (5–30 minutes).
2. Fill **Test Information** (a sentence: "Private family app for a child to think before buying things"), a contact email, and **Beta App Review** details.
3. Create an **External** group, e.g. "Family".
4. Add testers by email: Nate's Apple ID and the child's Apple ID (or a family member's, if the child's account can't use TestFlight; Apple's age rules apply).
5. Add the build to the group → submit for **Beta App Review** (first build of a version; usually under a day).
6. Testers install **TestFlight** from the App Store, accept the email invite, install WantWise.

Alternative: a **public link** limited to a few testers, sent to Nate.

## What account ownership means

- **Your team owns** the App IDs, the App Group, the signing certificates and profiles, the App Store Connect record, the builds and the tester list.
- **Nate owns** the source code, the design, the Supabase backend and the household Display. None of that is tied to your account.
- **Expiry:** each TestFlight build lasts 90 days. If you stop building, the installed app stops launching after that.
- **Your membership** must stay active for TestFlight builds to work.

## Future migration (if Nate gets his own Developer account)

- **A TestFlight-only app can't be transferred** between accounts. Apple's [app transfer criteria](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria) require "at least one version that was released to the App Store". WantWise isn't going on the App Store.
- So moving means a **new bundle ID under Nate's team**, which iOS treats as a different app. Data on the phone does **not** carry over between the two apps.
- **Mitigation in the plan:** from Milestone 3, data syncs to Supabase, so a migration becomes "install the new app and sign in". Before Milestone 3, on-device data would be lost (or exported manually).
- The App Group ID changes too; WantWise keeps only a temporary handoff folder there (D-019), so nothing durable is stranded.
- After a migration, you can delete the old App Store Connect record and identifiers at your convenience.

## Checklist for each release

- [ ] `git pull` (latest `main`)
- [ ] `CURRENT_PROJECT_VERSION` bumped (and committed by Nate)
- [ ] `xcodegen generate`
- [ ] Archive → Upload
- [ ] Add build to the "Family" TestFlight group
