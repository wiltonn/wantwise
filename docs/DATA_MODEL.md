# Data Model

Minimal model for V1, shaped so it can sync to Supabase later without a rewrite.

## Conventions (all entities)

| Rule | Why |
|---|---|
| `id: UUID`, generated on the device that creates the record | Stable identity offline; same id locally and in Postgres |
| `createdAt`, `updatedAt` (UTC instants) | Ordering and last-writer-wins sync |
| `deletedAt` (optional) — soft delete only | Deletions must sync; history is never lost |
| Money as **integer minor units** (`priceMinor: Int`, cents) + ISO 4217 `currency` | Exact in Swift, TypeScript and Postgres; no float rounding |
| Images referenced by **filename / storage path**, never stored as blobs in the database | Keeps the store small; maps directly to Supabase Storage |
| Enum values stored as **strings** | Readable in Postgres, safe to extend |

## Entities

```
Family ──< ChildProfile ──< Want ──< WantDecision
                       └──< LovedThing        (later)
Family ──< ParentUser                          (Milestone 3)
```

### Family

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| name | String | e.g. "Wilton household" — never shown on Display |
| createdAt / updatedAt | Date | |

In Milestone 1 a single Family and ChildProfile are created on first launch. No UI to manage them.

### ChildProfile

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| familyId | UUID | |
| displayName | String | First name only |
| defaultCurrency | String | e.g. `"CAD"` / `"USD"` |
| createdAt / updatedAt | Date | |

### Want

| Field | Type | Req | Notes |
|---|---|---|---|
| id | UUID | ✓ | |
| childId | UUID | ✓ | |
| title | String | ✓* | *May be empty for a screenshot capture; UI falls back to "Something I saw" |
| details | String? | | ("description" in the brief — renamed to avoid clashing with Swift's `description`) |
| productURL | String? | | |
| imageFilename | String? | | File in the app's images directory; later the Storage object path |
| sourceType | SourceType | ✓ | |
| priceMinor | Int? | | Cents |
| currency | String | ✓ | Defaults to child's currency |
| reason | String? | | "What makes you want this?" |
| similarItemAnswer | SimilarItemAnswer? | | see below |
| similarItemNote | String? | | Optional free text ("my old earbuds") |
| status | WantStatus | ✓ | |
| revisitAt | Date? | | Required once status is `waiting` |
| decidedAt | Date? | | Set when a terminal-ish decision is made |
| decisionReason | String? | | Latest decision's note (full history in WantDecision) |
| isVisibleOnDisplay | Bool | ✓ | Default `true`; child/parent can hide individual Wants |
| createdAt / updatedAt / deletedAt | Date | | |

`similarItemAnswer`: `yes`, `no`, `notSure`. A yes/no tap is faster than typing for a 10-year-old; the note is optional.

### WantDecision (append-only history)

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| wantId | UUID | |
| kind | DecisionKind | `stillWant`, `waitLonger`, `noLongerWant`, `purchased` |
| note | String? | |
| previousRevisitAt / newRevisitAt | Date? | For `waitLonger` |
| decidedAt | Date | |

Decisions are never edited or deleted. This makes sync trivial (insert-only, no conflicts) and gives the parent view its history.

### LovedThing (modelled, not built)

| Field | Type | Notes |
|---|---|---|
| id, childId | UUID | |
| title | String | |
| kind | String | `possession`, `experience`, `pet`, `person`, `activity` |
| note | String? | |
| imageFilename | String? | |
| isVisibleOnDisplay | Bool | |
| createdAt / updatedAt / deletedAt | Date | |

## Enums

**SourceType**: `manual`, `screenshot`, `photo`, `sharedURL`, `sharedText`

**WantStatus** (stored):

| Status | Meaning |
|---|---|
| `captured` | Saved quickly (e.g. from the Share Extension) but the child hasn't finished the reflection questions / chosen a wait. Shown as "Finish thinking about this". |
| `waiting` | Has a `revisitAt`. The normal "thinking about it" state. |
| `stillWant` | Reconsidered and still wants it. Outcome, not a failure. |
| `purchased` | Bought (later milestone; parent or child can mark). |
| `noLongerWant` | Reconsidered and let it go. |

**Derived, not stored** (computed from `status` + `revisitAt` + now):

| Brief's status | How it is represented |
|---|---|
| `considering` | Same as `captured` — not needed as a separate state |
| `readyToReconsider` | `status == waiting && revisitAt <= now` |
| `waitingLonger` | `status == waiting` with a `waitLonger` WantDecision in history |

Storing `readyToReconsider` would require a background job to flip it at the right moment; deriving it is always correct. See DECISIONS.md D-006.

## Transitions

```
captured ──(answer + choose wait)──▶ waiting
waiting  ──(ready) Still want it──▶ stillWant
waiting  ──(ready) Wait longer───▶ waiting (new revisitAt, decision logged)
waiting  ──(ready) Don't need it─▶ noLongerWant
stillWant ──(later) Purchased────▶ purchased
stillWant ──(later) Changed mind─▶ noLongerWant
```

Kept as plain functions in `WantWiseCore` (e.g. `Want.applying(_ decision:)`), not a state-machine framework. The child may also reconsider *early* — the UI allows it but doesn't push it.

## Revisit dates

- Choices: 3, 7, 30 days, or custom date. Default suggestion: **7 days**.
- `revisitAt` = chosen local calendar day at **4:00 pm local time** (after school; notification-friendly). One constant, easy to change.
- Countdown text uses **calendar-day** difference in the device's time zone:
  - `revisitAt` ≤ now → "Ready to think again"
  - same day → "Reconsider today"
  - 1 day → "Reconsider tomorrow"
  - n days → "n days left"
- "You wanted this N days ago" uses calendar days between `createdAt` and today.

The same rules are implemented in Swift (`WantWiseCore`) and TypeScript (Display). A shared fixture file (`docs/fixtures/countdown-cases.json`, added in Milestone 1) will hold test cases both test suites run against, so the two can't drift.

## Reflection metrics (parent view / Display)

| Metric | Definition |
|---|---|
| Wants considered this month | Wants with `createdAt` in current month |
| Average thinking time | mean(`decidedAt − createdAt`) over decided Wants |
| Wants reconsidered | count of Wants with ≥1 WantDecision |
| Money kept | sum(`priceMinor`) over `noLongerWant` Wants with a price |
| Share let go after waiting | `noLongerWant` ÷ all decided Wants |

## Postgres mapping (Milestone 3)

`snake_case` columns, same UUIDs, `timestamptz`, `bigint` for `price_minor`, `text` + `CHECK` constraints for enums. Every table carries `family_id` for Row Level Security. See ARCHITECTURE.md → Sync.
