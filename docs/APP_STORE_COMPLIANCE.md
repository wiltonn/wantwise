# App Store / TestFlight compliance checklist

WantWise ships to the family through **TestFlight external testing** ([APPLE_HANDOFF.md](APPLE_HANDOFF.md)), so every build goes through **Beta App Review**. Beta App Review is lighter than a public App Store review, but it applies most of the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), and Apple's upload checks (privacy manifest, Info.plist, icons) apply either way.

Run this before each TestFlight upload, and on any change that touches data, permissions, networking or dependencies. The `app-store-reviewer` agent (`.claude/agents/app-store-reviewer.md`) works through it.

Status key: ✅ satisfied in the repo · 🍎 confirmed in a Mac/Xcode build · ⚠️ check at upload time · 🔜 becomes relevant at a later milestone.

## Every build (TestFlight)

| | Check | Status / where |
|---|---|---|
| Privacy manifest | `PrivacyInfo.xcprivacy` in the app **and** the Share Extension; no tracking, no collected data, no required-reason APIs | ✅ `apps/ios/Config/PrivacyInfo.xcprivacy`, wired in `project.yml` (D-031). 🍎 Xcode 26.3: confirmed in the built `WantWise.app` and its embedded `WantWiseShare.appex` |
| Required-reason APIs | No `UserDefaults`/`@AppStorage`, file timestamps (`creationDate`, `contentModificationDate`, `attributesOfItem`), disk space, system uptime, active keyboards. If one is added, declare it with an approved reason code in the manifest | ✅ none in `WantWise/`, `WantWiseShare/`, `Shared/`, `WantWiseCore/Sources` (grep, 2026-10-02) |
| Third-party SDKs | None. Any new SDK must ship its own privacy manifest and signature | ✅ only Apple frameworks + WantWiseCore |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in the app's Info.plist | ✅ `Config/WantWise-Info.plist` |
| Permission strings | A purpose string for every permission the app requests. PhotosPicker needs none; notifications need none. Camera, full photo-library access, contacts, location etc. would | ✅ none required today |
| Permission timing | Ask in context, not at launch (Guideline 5.1.1) | ✅ notifications asked at the first waiting Want (D-029) |
| Debug code | Sample data, debug menu and sample images are DEBUG-only and excluded from Release | ✅ D-027; 🍎 Xcode 26.3, unsigned Release Simulator build: no `debug-sample-*` files or assets, no debug launch-argument strings in the binary, no ladybug menu. ⚠️ re-check the signed archive at Stage 3 |
| Completeness (2.1) | No crashes, no placeholder text, every visible button works | ⚠️ run the Milestone 1 checks (CLOUD_MAC_SESSION.md §6) on the build you upload |
| Notifications (4.5.4) | Reminders only, no marketing | ✅ |
| App icon | 1024×1024 App Store icon, no transparency | ✅ asset catalog icon is 1024², RGB, no alpha (VERIFICATION.md) |
| Test information | Beta App Description, feedback email, contact details, and a "what to test" note in App Store Connect → TestFlight | ⚠️ App Store Connect (signing partner) |
| Testers' ages | Apple's age rules for Apple IDs and TestFlight apply to the child's account | ⚠️ see APPLE_HANDOFF.md |

## Later milestones

| When | What it brings |
|---|---|
| 🔜 Milestone 3 (sync, accounts) | Data leaves the device: update the manifest's `NSPrivacyCollectedDataTypes`, fill in **App Privacy** details in App Store Connect, publish a **privacy policy** URL, handle children's data (COPPA in the US; GDPR-K elsewhere), and offer **in-app account deletion** if accounts can be created (5.1.1(v)). Third-party sign-in requires an equivalent privacy-preserving option such as Sign in with Apple (4.8) |
| 🔜 Any analytics or crash reporting | Declare collected data types; for a child user, avoid third-party analytics entirely |
| 🔜 Public App Store (not planned) | Full review; privacy policy required; if listed in the **Kids Category** (1.3): no third-party ads or analytics, and a parental gate before external links, purchases or settings |

## How to check

- **Repo scan** (any OS): ask Claude to run the `app-store-reviewer` agent, or grep for the APIs above.
- **Bundle contents** (Mac, after `mac-build.sh`): `find apps/ios/build/DerivedData/Build/Products -name PrivacyInfo.xcprivacy` should list one in `WantWise.app` and one in `WantWise.app/PlugIns/WantWiseShare.appex` (plus the standalone intermediate `WantWiseShare.appex` next to the app, which isn't shipped).
- **Privacy report** (Mac, signed archive, Stage 3): Xcode Organizer → right-click the archive → **Generate Privacy Report**.
