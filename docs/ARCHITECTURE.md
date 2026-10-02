# Architecture

## System shape

```
                Milestones 1–2 (local only)                  Milestones 3–4
┌───────────────────────────────────────────┐
│ iPhone                                    │
│  ┌──────────────┐   App Group container   │
│  │ Share Ext.   │──▶ Inbox/  Images/      │
│  └──────────────┘        │                │        ┌──────────────────────┐
│  ┌──────────────────────▼──────────────┐  │  sync  │ Supabase             │
│  │ WantWise app                        │◀─┼───────▶│  Auth (parent)       │
│  │  SwiftUI ─ WantStore ─ SwiftData    │  │        │  Postgres + RLS      │
│  │  WantWiseCore (pure domain logic)   │  │        │  Storage (images)    │
│  └─────────────────────────────────────┘  │        └──────────┬───────────┘
└───────────────────────────────────────────┘                   │ read-only
                                                     ┌──────────▼───────────┐
                                                     │ WantWise Display     │
                                                     │ Next.js, TV browser  │
                                                     └──────────────────────┘
```

The iPhone is the **source of truth** in Milestones 1–2 and remains fully functional offline afterwards. Supabase is a sync target and the Display's data source. The Display never writes Wants.

## iOS

### Targets

| Target | Contents |
|---|---|
| `WantWiseCore` (local Swift package) | Domain value types, enums, status transitions, revisit/countdown calculations, metrics, `CapturedWant` inbox format, inbox import logic (against a file-system protocol). **Imports Foundation only** — no SwiftUI, SwiftData, UIKit. Builds and tests on Linux. |
| `WantWise` (app) | SwiftUI views, SwiftData `@Model` classes, `WantStore`, image storage, notifications, inbox importer wiring. |
| `WantWiseShare` (Share Extension) | Capture UI hosted in `UIHostingController`; writes to inbox. Depends on `WantWiseCore` only. |
| `WantWiseTests` | App-level tests: SwiftData persistence, image handling. |
| `WantWiseUITests` | A few smoke UI tests for the Milestone 1 loop. |

### Layering (deliberately thin)

```
SwiftUI views
   │  read via @Query (list screens) / call methods on
   ▼
WantStore            ← small @MainActor class; the only thing that mutates Wants
   │                    (create, applyDecision, update, hide-from-display)
   ├─▶ SwiftData ModelContext
   ├─▶ ImageStore     (files in App Group)
   └─▶ ReminderScheduler (UNUserNotificationCenter)
   │
   ▼ uses
WantWiseCore         ← pure functions: what the next status is, what revisitAt is,
                       what the countdown says, metrics
```

- Views use `@Query` for lists — idiomatic SwiftUI, no extra abstraction.
- All **writes** go through `WantStore`, so Milestone 3 can mark records dirty / enqueue sync in exactly one place.
- No repository-protocol-per-entity, no DI container, no coordinators. One protocol only where it pays for itself in tests (e.g. `ReminderScheduling`, `Clock`/`now` injection).
- SwiftData `@Model` classes mirror the DATA_MODEL fields and convert to/from `WantWiseCore` value types where logic is needed (`want.snapshot` → pure function → apply result).

### Navigation (Milestone 1)

```
WantsView (home)
 ├─ Section "Ready to think again"   (waiting && revisitAt <= now)
 ├─ Section "Finish thinking about"  (captured)
 ├─ Section "Thinking about"         (waiting)
 ├─ Section "Decided"                (collapsed; stillWant / purchased / noLongerWant)
 ├─ [+ Add Want] ──▶ AddWantView (sheet) ──▶ confirmation "Let's think again on …"
 └─ tap card ──▶ WantDetailView
                  ├─ image, reason, similar-item answer, countdown
                  └─ ReconsiderView (when ready, or "Think about it now" early)
                       Still want it · Wait longer · I don't need it anymore
```

### Notifications

Local only. One pending request per waiting Want, identifier = `want-<uuid>`, fired at `revisitAt`. On every launch/foreground the app **reconciles**: removes requests for Wants that are no longer waiting, adds missing ones. Idempotent, so it doesn't matter who scheduled first (app or extension).

### Minimum iOS version

**iOS 18.0** (SwiftData's iOS 17 release had rough edges fixed in 18). Lower only if the child's phone requires it — check the phone's iOS version before the first Mac session.

## Display

Next.js (App Router) + TypeScript, plain CSS. Details in [DISPLAY.md](DISPLAY.md).

## Sync design (Milestone 3)

Designed now so Milestone 1 doesn't paint us into a corner. **Not implemented until the local loop works.**

### Identity and timestamps

- UUIDs generated on device; the same UUID is the Postgres primary key. No server-assigned ids, no id remapping.
- `updatedAt` set by the device on every local change. Postgres keeps its own `server_updated_at` (trigger, `now()`) used as the **sync cursor** — device clocks can't be trusted for "what changed since".
- Local SwiftData models add two sync-only fields: `needsUpload: Bool` and `lastSyncedAt: Date?`.

### Sync loop (simple, pull-then-push)

1. **Push**: upload every record with `needsUpload == true` via upsert. On success clear the flag.
2. **Pull**: `select … where server_updated_at > lastCursor` for each table; apply locally; advance cursor.
3. Run on launch, on foreground, after local writes (debounced), and on a manual "Sync" pull-to-refresh. No background sync in V1.

### Conflicts

| Data | Strategy |
|---|---|
| `Want` | **Last writer wins per record** using device `updatedAt`, enforced in the upsert (`where excluded.updated_at > wants.updated_at`). Realistically one child edits Wants on one phone; conflicts are rare and low-stakes. |
| `WantDecision` | **Append-only**, insert-if-absent. Never conflicts. |
| Status | Re-derivable from decision history if ever needed — a safety net, not a routine path. |
| Deletes | Soft delete (`deletedAt`) syncs like any update. |

If a parent device starts editing Wants (e.g. marking `purchased`), revisit with per-field merge. Not before.

### Offline

The app never blocks on the network. Everything is written locally first; sync catches up. The Display shows the last synced state, with a subtle "last updated" time if data is older than a few hours.

### Image sync

- Images upload to a **private** Supabase Storage bucket: `wants/<familyId>/<wantId>.jpg`. Images are immutable per Want (replacing an image writes a new object name), so no image conflicts.
- Upload image **before** upserting the row that references it; the row stores `image_path`.
- Pulling: download images lazily when a Want is shown and its file is missing locally.
- Display gets short-lived **signed URLs** generated server-side.

### Auth and authorization

- **Parent** signs in with Supabase Auth (email magic link or Sign in with Apple).
- `family_members(family_id, user_id, role)` links auth users to a family. Roles: `parent` now; `child`/`display` later.
- **Child's iPhone**: the parent signs in once on the child's phone; the session belongs to the family. The child never sees credentials. (A separate child login is a later option, not V1.)
- **Display device**: the parent signs in on the TV browser. Later improvement: a read-only `display` role or device token so a session on a shared screen can't write anything.

### Row Level Security

Every table has `family_id`. Policies follow one pattern:

```sql
-- read/write only rows in families you belong to
create policy "family members" on wants
  for all using (
    family_id in (select family_id from family_members where user_id = auth.uid())
  );
```

Storage policies use the same rule against the first path segment (`<familyId>`). The Display reads from a `display_wants` **view** that only exposes display-safe columns and filters `is_visible_on_display = true and deleted_at is null`.
