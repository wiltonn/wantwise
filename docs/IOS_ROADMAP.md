# Roadmap — Milestones 1–4

Each milestone is usable on its own. Milestone 1 has **no** dependency on Supabase.

Legend: **[WSL]** can be authored/checked in WSL · **[MAC REQUIRED]** needs Xcode on the cloud Mac

---

## Milestone 1 — Local Want loop (iPhone, SwiftData)

**Goal**: the vertical slice from the brief, on the child's iPhone.

1. Launch WantWise → see existing Wants
2. Add Want: name, price, why, similar item (yes/no/not sure), think-about-it duration
3. Save → "Let's think about this again on [date]"
4. Want appears on the list; survives relaunch
5. Open it → see time remaining
6. When ready (or early), record Still want it / Wait longer / I don't need it anymore
7. Local notification on the revisit date

| Step | Work | Where |
|---|---|---|
| 1.1 | `WantWiseCore` package: enums, `WantSnapshot`, `WantDecision`, transitions, `revisitDate(for:from:calendar:)`, countdown text, metrics | [WSL] |
| 1.2 | `WantWiseCore` unit tests + `docs/fixtures/countdown-cases.json` | [WSL] (runs with Swift on Linux) |
| 1.3 | `project.yml` (XcodeGen), Info.plist, entitlements (App Group added now so M2 doesn't need re-signing changes), `.xcconfig` | [WSL] |
| 1.4 | SwiftData models (`Want`, `WantDecision`, `ChildProfile`, `Family`), `WantStore`, `ReminderScheduler`, first-launch seeding | [WSL] authored, [MAC REQUIRED] compiled |
| 1.5 | Views: `WantsView`, `WantCard`, `AddWantView`, `WantDetailView`, `ReconsiderView`, shared visual tokens | [WSL] authored, [MAC REQUIRED] compiled |
| 1.6 | First Mac session: generate project, build, fix compile errors, run in Simulator, persistence tests, archive → TestFlight | [MAC REQUIRED] |
| 1.7 | Install on child's iPhone via TestFlight, use it for real for a week | iPhone |

**Done when**: the child can add and reconsider Wants on their own phone, and data survives relaunch and app updates.

**Status (2026-10-02):** 1.1–1.5 authored in WSL. WantWiseCore verified on Linux; the Xcode project generates in WSL; all app Swift passes a syntax-only parse. 1.6 is now split into **Stage 2** (rented Mac, Simulator only: [CLOUD_MAC_SESSION.md](CLOUD_MAC_SESSION.md)) and **Stage 3** (signing partner, TestFlight: [APPLE_HANDOFF.md](APPLE_HANDOFF.md)). See [VERIFICATION.md](VERIFICATION.md).

## Milestone 2 — Screenshot & Share capture

**Goal**: Screenshot → Share → WantWise in under 10 seconds. Plus photo capture.

| Step | Work | Where |
|---|---|---|
| 2.1 | `CapturedWant` (Codable inbox format), inbox import logic, text→URL extraction, title fallback — with tests | Done (text→URL extraction added on the Mac, Follow-up 4; Linux `swift test` still to run) |
| 2.2 | `WantWiseShare` target in `project.yml`, activation rules, entitlements | Done; 🍎 builds and embeds |
| 2.3 | Extension: item loading, ImageIO downsampling, "Want this?" SwiftUI UI, atomic inbox write, best-effort notification | 🍎 image and URL shares verified in the Simulator (iOS 18.5, 26.3.1). The extension doesn't schedule reminders (D-030). Reason-less shares → *Finish adding* (D-032): Follow-up 5 |
| 2.4 | App: import inbox on foreground, `ImageStore`, images on cards/detail, PhotosPicker + camera, `LPMetadataProvider` for shared URLs, "Finish thinking about this" flow for `captured` | 🍎 import, images, link previews (real fetch in the Simulator). Camera built, 📝 needs a physical iPhone. Finish adding: 📝 not driven by a UI test |
| 2.5 | Device testing: Photos app, screenshot markup, Safari (incl. Full Page PDF), Amazon app, YouTube, a game | ⏳ Stage 3 (TestFlight → iPhone). Not built yet: Safari Full Page PDF, JavaScript preprocessing, share-sheet pinning onboarding |

**Done when**: the child habitually captures Wants via screenshots, and those Wants show their screenshots in the app.

## Milestone 3 — Supabase sync & parent auth

| Step | Work | Where |
|---|---|---|
| 3.1 | `supabase/migrations`: `families`, `family_members`, `child_profiles`, `wants`, `want_decisions`, `loved_things`; `server_updated_at` triggers; RLS policies; `display_wants` view; Storage bucket + policies | [WSL] (Supabase CLI + local Docker) |
| 3.2 | RLS tests (SQL/pgTAP or a small script hitting local Supabase with two users) | [WSL] |
| 3.3 | iOS: `supabase-swift` SPM dependency, parent sign-in screen, `SyncEngine` (push dirty → pull since cursor), image upload/download | [WSL] authored, [MAC REQUIRED] compiled |
| 3.4 | Parent view on iPhone: history, decisions, reflection metrics | [WSL] authored, [MAC REQUIRED] compiled |
| 3.5 | Migrate existing local data on first sign-in (it's already UUID-keyed — just mark everything dirty) | [MAC REQUIRED] to test |

**Done when**: the child's Wants (with images) are in Supabase and survive phone replacement.

## Milestone 4 — WantWise Display on synchronized data

The Display UI is **built against fixtures in parallel with Milestones 1–3** (it's pure WSL work). Milestone 4 just connects it.

| Step | Work | Where |
|---|---|---|
| 4.0 *(anytime)* | Next.js app, fixture data source, Featured + rail layout, countdown, rotation, wake lock, reload/poll | [WSL] |
| 4.1 | Supabase data source, `/login`, `/setup` (choose child), signed image URLs | [WSL] |
| 4.2 | Deploy (Vercel or household PC), kiosk setup on the TV machine | [WSL] + TV PC |
| 4.3 | Hide-from-display toggle in the iPhone app | [WSL] authored, [MAC REQUIRED] compiled |
| 4.4 | Additional scenes: Ready to Reconsider, Recent Decisions, Reflection | [WSL] |

**Done when**: a Want screenshotted on the iPhone appears on the TV within about a minute.

---

## Later (not scheduled)

- Things I Love (app + Display scene)
- WidgetKit: waiting Wants / next reconsideration / Things I Love
- `purchased` flow, parent marking purchases
- Read-only display device token / role
- CI: GitHub Actions macOS runner for build + TestFlight upload (fewer cloud Mac rentals)
- AI: screenshot product extraction, categorisation (explicitly not V1)
