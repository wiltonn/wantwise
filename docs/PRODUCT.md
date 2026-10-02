# Product

## Purpose

WantWise helps a child (about 10 years old) learn to separate:

- wanting something
- buying it immediately
- waiting
- reconsidering
- deciding whether it is genuinely worth buying

It is **not** a tool for shaming wants. Wanting things is normal. The product celebrates *thoughtful decisions* — "I waited and still want it" is as good an outcome as "I waited and don't need it anymore".

Core loop: **See → Capture → Explain → Wait → Reconsider → Decide → Reflect**

## Users (V1)

One family: one **parent**, one **child**.

- The parent owns the account (Milestone 3+).
- The child has a **profile**, not an independent login.
- The parent is **not** an approval gate for each Want. The point is the child's own judgement.

## Experiences

### Capture (child, iPhone)

Capturing must take seconds and must not require retyping product details. Priority order of capture methods:

1. **Screenshot → Share → WantWise** (highest priority after the basic loop)
2. **Share URL → WantWise** from Safari or any app
3. **Photo → WantWise** for things seen in real life
4. **Manual** Add Want form

Details in [CAPTURE.md](CAPTURE.md).

### Explain (child)

Minimum questions, all skippable except the title/image:

- "What makes you want this?"
- "Do you already have something similar?"
- "Think about it for: 3 days · 7 days · 30 days · Custom"

Confirmation: **"Let's think about this again on Friday, Oct 9."**

### Reconsider (child)

When the revisit date arrives (local notification: *"Still thinking about this? You added this 7 days ago. Take another look."*):

> **You wanted this 7 days ago. What do you think now?**
>
> [original screenshot / photo, large]
>
> **Still want it** · **Wait longer** · **I don't need it anymore**

Later: **Purchased**. Wants are never deleted by a decision; every decision is kept as history.

### Parent view (iPhone, later milestone)

- Active Wants, Wants ready to reconsider, history
- Purchases and items decided against
- Total value of items not purchased
- Average waiting period
- Share of Wants let go after waiting

Presented as reflection, not a score.

### WantWise Display (household screen)

A full-screen browser display on a TV or monitor that turns the Want list into a beautiful, calm visual menu: large imagery, the child's own reason, and how long is left to think. See [DISPLAY.md](DISPLAY.md).

### Things I Love (later)

A counterweight list: possessions, experiences, pets, people, activities. Modelled now, built later. Never a prerequisite for buying.

## Language and tone

| Do | Don't |
|---|---|
| "Let's think about this again on Friday." | "You're not allowed to buy this yet." |
| "Nice — you thought it through." (any decision) | "Great job not buying it!" |
| "Still thinking about this?" | "Did you resist?" |
| "Things you decided" | "Wins" / "Fails" |

## UI principles

- Simple navigation, large touch targets, visual status, low cognitive load, minimal forms.
- Not babyish, not cartoonish.
- No streaks, points, badges, leaderboards, or rewards for accumulating Wants or for not buying.
- The Display shares the visual identity but is more cinematic and glanceable.

## Privacy

The Display may be seen by visitors. It never shows email addresses, account details, auth state, or parent settings. Individual Wants can be hidden from the Display (`isVisibleOnDisplay`).

## Out of scope for V1

- AI/LLM features of any kind (OCR, auto-categorisation, pattern detection) — possible later.
- Remote push notifications (local notifications only).
- Widgets (possible later: "waiting", "next reconsideration", "Things I Love").
- Multi-family SaaS features (but nothing should make it impossible).
