# WantWise Display

A full-screen, read-only browser display for a household TV or monitor. **Not** a stretched phone UI. Target 1920×1080 first; scales to 4K and smaller laptops.

## Feel

Modern, high-contrast, premium, calm, glanceable, slightly cinematic — closer to a streaming service's home screen or a beautiful information display than a rewards chart.

Not childish, cartoonish, corporate, cluttered, or gamified. No points, streaks or scores.

## Layout options considered

| Option | Strength | Weakness |
|---|---|---|
| **A. Grid** of cards | Everything at a glance | Gets busy past ~6 items; small imagery from across a room |
| **B. Horizontal carousel** | Media-app feel | Most items off-screen; motion needed to see everything |
| **C. Featured + rail** (one large hero Want, a rail of the rest) | Big, desirable imagery *and* overview; works for 1 or 15 Wants | Slightly more layout logic |
| **D. Full-screen rotation** (one Want at a time) | Maximum drama | Can't see the list; waiting process less visible |

**V1 choice: C — Featured + rail**, with the featured Want slowly rotating (~20 s). It's the simplest layout that keeps imagery large while keeping every Want visible. See DECISIONS.md D-011.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ WANTWISE · Thinking About                                     Fri 4:12 PM    │
│                                                                              │
│ ┌──────────────────────────────────────┐                                     │
│ │                                      │   Wireless headphones               │
│ │                                      │   $49                               │
│ │        [ large screenshot ]          │                                     │
│ │                                      │   "Mine hurt my ears"               │
│ │                                      │                                     │
│ │                                      │   ━━━━━━━━━━━━━━━━░░░░░  5 days left │
│ └──────────────────────────────────────┘                                     │
│                                                                              │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│ │  [img]   │ │  [img]   │ │  [img]   │ │  [img]   │ │  [img]   │            │
│ │ NeeDoh   │ │ Art set  │ │ …        │ │ …        │ │ …        │            │
│ │ Tomorrow │ │ 12 days  │ │          │ │          │ │          │            │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└──────────────────────────────────────────────────────────────────────────────┘
```

- Hero: image on the left (~55% width), title / price / reason / time remaining on the right. Screenshots are tall — show them with `object-fit: contain` over a blurred, darkened copy of the same image as the backdrop (the streaming-poster look; works for any aspect ratio).
- Rail: up to ~6 cards; the currently featured card is highlighted. Beyond 6, the rail pages slowly.
- Time remaining is shown as text plus a thin progress bar (createdAt → revisitAt). "Ready to think again" uses the single accent colour.
- Empty state: calm, e.g. "Nothing on the list right now." — never a nudge to add more Wants.

## Scenes (later)

The display can rotate between scenes every few minutes. V1 ships **Thinking About** only; the structure supports adding:

1. **Thinking About** — waiting Wants (V1)
2. **Ready to Reconsider** — `revisitAt` passed
3. **Recent Decisions** — still want / purchased / let go, last 30 days, all framed neutrally ("Decided")
4. **Things I Love**
5. **Reflection** — Wants considered this month, average thinking time, Wants reconsidered, money kept. Plain facts, no score.

## Visual system

- **Dark background** (near-black, not pure black), off-white text, one restrained accent colour shared with the iPhone app. Subtle depth: soft shadows, slightly raised cards, gentle gradient.
- **Typography**: Inter Tight (display) + Inter (body), self-hosted via `next/font` (no requests to Google at runtime). At 1080p: hero title 76 px, reason 38 px, minimum anything ~22 px.
- **Scaling**: the whole Display is laid out on a fixed **1920×1080 stage** and scaled uniformly to the window (D-023). 4K renders at 2× and stays sharp; a 1366×768 laptop gets the identical composition at 0.71×. Non-16:9 screens get a letterbox with the ambient background.
- **Motion**: cross-fades and slow (≥600 ms) transitions only. Respect `prefers-reduced-motion`.
- **Readable from ~3 m**: test by standing back from the screen.

## Long-running display concerns

| Concern | Approach |
|---|---|
| Screen sleeping | Screen Wake Lock API (`navigator.wakeLock`) where supported; document OS power settings otherwise |
| Burn-in (OLED TVs) | Slow sub-pixel drift of the whole layout; content rotates anyway |
| Night | Optional dim mode between configurable hours |
| Memory leaks over days | Full page reload every ~6 hours |
| Stale data | Poll every 60 s; show "Updated 3 h ago" only when data is stale |
| Kiosk | Chrome/Edge `--kiosk <url>` or browser full-screen (F11) — documented in DEVELOPMENT.md |

## Privacy

- Never render email, account names, family name, auth state or settings on `/display`.
- Settings / sign-out live on a separate route (`/settings`) reached by a small, unobtrusive control — not on the display surface.
- Only Wants with `isVisibleOnDisplay = true` and not deleted are fetched (enforced server-side by the `display_wants` view, not just in the UI).
- Images served via short-lived signed URLs.

## Architecture

```
apps/display/
├── app/
│   ├── layout.tsx
│   ├── page.tsx              # redirect → /display or /login
│   ├── login/page.tsx        # Supabase auth (Milestone 4)
│   ├── setup/page.tsx        # choose child to display (Milestone 4)
│   ├── display/page.tsx      # server component: fetch DisplaySnapshot
│   │   └── DisplayClient.tsx # client: rotation, polling, wake lock
│   └── api/snapshot/route.ts # GET → DisplaySnapshot JSON (used for polling)
├── components/               # HeroWant, WantRail, WantCard, Countdown
├── lib/
│   ├── domain.ts             # Want types, countdown text, progress (mirrors WantWiseCore)
│   ├── data/source.ts        # interface DisplayDataSource { getSnapshot(childId) }
│   ├── data/fixtureSource.ts # reads fixtures/*.json + public/fixtures/*.jpg
│   └── data/supabaseSource.ts# Milestone 4
├── fixtures/                 # sample Wants for building the UI before Supabase exists
└── styles/
```

- **Data source interface**: `DisplayDataSource.getSnapshot(childId) → DisplaySnapshot { child: { displayName }, wants: DisplayWant[], generatedAt }`. `WANTWISE_DATA_SOURCE=fixture|supabase`. The fixture source lets the Display be designed and built in WSL **now**, independent of the iPhone app and backend.
- **Server-side data access**: Supabase is queried from server components / route handlers using the signed-in user's session cookie (`@supabase/ssr`). The browser never holds a service key.
- **Refresh**: client polls `/api/snapshot` every 60 s and swaps state. Supabase Realtime is a later option if 60 s feels slow (it won't for this use).
- **Dependencies**: `next`, `react`, `@supabase/ssr` + `@supabase/supabase-js` (Milestone 4), `vitest` (dev). No UI kit, no state library, no CSS framework.
- **Hosting**: either Vercel (free tier) or `next start` on the household PC itself. Decide at Milestone 4; nothing in the design depends on it.

## Prototype (2026-10-02)

Fixture-backed, running in WSL. Screenshots: `docs/display-screens/`.

- `?feature=N` starts on a given Want (design review / screenshots).
- **F** toggles full screen; **←/→** step through Wants; the cursor and the full-screen button hide after 3 s idle.
- Placeholder "screenshots" are generated SVGs (`npm run fixtures:images`) imitating phone screenshots of store pages, a photo and a link preview, so the layout is judged with realistic aspect ratios.
- Fixture dates are relative to *now*, so countdowns always look realistic. One fixture Want is hidden from the Display and one is soft-deleted; tests prove neither appears.

## Testing

- `vitest` unit tests for `lib/domain.ts` (countdown text, progress, ordering), sharing `docs/fixtures/countdown-cases.json` with the Swift tests.
- Manual visual check at 1920×1080 and 3840×2160 (browser dev tools device sizes) — screenshots committed to `docs/display-screens/` when the design settles.
- Playwright only if visual regressions become a real problem.
