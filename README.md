# WantWise

A private family app that helps a child tell the difference between *wanting* something and *deciding* it is worth buying.

**See → Capture → Explain → Wait → Reconsider → Decide → Reflect**

WantWise has two interfaces:

| Interface | What it is | Tech |
|---|---|---|
| **WantWise iPhone app** | Capture, reflect, reconsider, manage | Native SwiftUI + SwiftData (local-first) |
| **WantWise Display** | Cinematic, glanceable household screen for a 1080p monitor/TV | Next.js + TypeScript (read-only) |

Shared data (Milestone 3+) lives in Supabase.

## Repository layout

```
wantwise/
├── apps/
│   ├── ios/                 # SwiftUI app, Share Extension, pure-Swift core package (see apps/ios/README.md)
│   │   ├── project.yml      # XcodeGen spec → generates WantWise.xcodeproj
│   │   ├── WantWiseCore/    # Swift package: domain logic, no Apple-only frameworks
│   │   ├── WantWise/        # App target sources
│   │   ├── WantWiseShare/   # Share Extension sources
│   │   ├── Config/          # Info.plists, entitlements, xcconfig (no Team ID)
│   │   └── scripts/         # mac-build.sh
│   └── display/             # Next.js household display
├── supabase/                # migrations, RLS policies, seed (Milestone 3; not created yet)
└── docs/
```

## Documentation

- [PRODUCT.md](docs/PRODUCT.md) — purpose, users, experience principles
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — system shape, iOS layering, future sync design
- [DATA_MODEL.md](docs/DATA_MODEL.md) — entities, fields, status rules
- [CAPTURE.md](docs/CAPTURE.md) — screenshot / URL / photo / manual capture, Share Extension constraints
- [DISPLAY.md](docs/DISPLAY.md) — household display design and architecture
- [IOS_ROADMAP.md](docs/IOS_ROADMAP.md) — Milestones 1–4
- [DEVELOPMENT.md](docs/DEVELOPMENT.md) — WSL vs. Mac workflow, Cloud Mac checklist, testing
- [DECISIONS.md](docs/DECISIONS.md) — dated decision log (append-only)
- [VERIFICATION.md](docs/VERIFICATION.md) — what has actually been tested, and where
- [CLOUD_MAC_SESSION.md](docs/CLOUD_MAC_SESSION.md) — rented-Mac runbook: clone → Simulator build → Milestone 1 check
- [APPLE_HANDOFF.md](docs/APPLE_HANDOFF.md) — instructions for the signing/TestFlight partner

## Development model

Day-to-day work happens in **Windows → WSL → Claude Code**. A rented cloud Mac is used only for steps that need Xcode (building against iOS SDKs, Simulator, signing, TestFlight). Everything that matters is in Git — nothing important lives only inside Xcode. See [DEVELOPMENT.md](docs/DEVELOPMENT.md).
