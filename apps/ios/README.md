# WantWise for iPhone

Native SwiftUI + SwiftData, iOS 17+. The Xcode project is generated from `project.yml` (XcodeGen) and is not committed.

```
apps/ios/
├── project.yml                 XcodeGen spec (targets, schemes, signing rules)
├── Config/                     xcconfigs, Info.plists, entitlements (no Team ID; see Signing.local.xcconfig.example)
├── WantWiseCore/               Foundation-only Swift package: all domain logic. Builds + tests on Linux.
├── WantWise/                   App target
│   ├── App/                    @main, AppEnvironment, RootView (tabs), AppRouter
│   ├── Persistence/            SwiftData versioned schema (V1) + container
│   ├── Store/                  WantStore: the single write path
│   ├── Notifications/          Local reminder scheduling + tap handling
│   ├── DesignSystem/           Artwork (image-first), status chip, progress, formatting
│   ├── Features/               WantList, AddWant (+ FinishAdding), WantDetail, Reconsider, History
│   ├── DebugSupport/           DEBUG-only sample data, previews, ladybug menu, sample screenshots
│   └── Resources/              Asset catalog (app icon, accent colour)
├── Shared/                     Compiled into the app AND the extension: Theme, ImageIO encoding, AppGroup
├── WantWiseShare/              Share Extension (Milestone 2 skeleton): Screenshot → Share → WantWise
├── WantWiseTests/              Swift Testing: WantStore + SwiftData, images, reminders, persistence, capture import
├── WantWiseUITests/            Add → list, relaunch persistence, reconsider
├── Design/AppIcon.svg          Icon source
└── scripts/mac-build.sh        One-command Simulator build/test on a Mac
```

## Run

- **WSL**: `cd WantWiseCore && swift test`
- **Mac, Simulator** (no Apple account needed): `./scripts/mac-build.sh run`. Full runbook: [docs/CLOUD_MAC_SESSION.md](../../docs/CLOUD_MAC_SESSION.md)
- **Device / TestFlight**: [docs/APPLE_HANDOFF.md](../../docs/APPLE_HANDOFF.md)

What's actually been verified, and where: [docs/VERIFICATION.md](../../docs/VERIFICATION.md).

## Data flow

```
View ──(read)── @Query ── SwiftData (WantEntity, WantDecisionEntity)
  │                              ▲
  └─(write)─▶ WantStore ─────────┘   entity.snapshot → WantWiseCore rule → entity.apply(_)
                 ├─▶ ImageFileStore   (Application Support/WantWise/Images, immutable file per image)
                 ├─▶ ReminderScheduler (ReminderPlanner diff → UNUserNotificationCenter)
                 └─◀ CaptureImporter  (App Group Inbox/ from the Share Extension)
```
