---
id: OPR.99.0.2.1
slice: 01-apple-requirements-skill
mission: m0
status: placeholder
stage: wip
verified: 2026-11-02 against scaffold (rig scope create)
created: 2026-11-02
intent: "Apple requirements for WantWise as a sourced, dated rule catalogue and a skill"
depends_on: []
acceptance: "python3 .claude/skills/apple-requirements/lint_rules.py"
approved-spec-by: nate@external
approved-spec-at: 2026-11-02T18:41:31.106Z
locked-artifacts:
  - name: Specification
    path: SPEC.md
    kind: spec
provenance: transport:v1
---

# Slice 01 — Apple Requirements Skill

## Intent

Write down what Apple requires of WantWise, from Apple's current published sources rather than memory, and make it usable by agents and reviewers. Each rule says how it is checked: an automated test, a reviewer check, or a person's sign-off. This is the base the compliance tests (slices 02 and 03) are built from.

## Mini-requirements

1. **Skill.** Add `.claude/skills/apple-requirements/SKILL.md`. It says when to use the skill (before any change to data, permissions, networking, dependencies, Info.plist, entitlements or sign-in; before a TestFlight upload), how to read the catalogue, and how to refresh it.
2. **Rule catalogue.** Add `.claude/skills/apple-requirements/rules.yaml` (or `rules.md` with one fenced YAML block per rule). Every rule has these fields:
   - `id`;
   - `title`;
   - `source` (a URL on developer.apple.com or apple.com);
   - `checked` (date fetched);
   - `applies_when` (`always`, or a trigger such as `networking`, `account_signin`, `third_party_login`, `camera`, `photos`, `notifications`, `release`);
   - `check` (`static`, `simulator`, `review` or `person`);
   - `test` (the test or checklist item that covers it, or `todo:<slice>`);
   - `status_now` for WantWise today (`met`, `not_met`, `not_applicable_yet`, `unknown`).
3. **Coverage.** At least these areas, read from Apple's current pages:
   - App Review Guidelines: 1.3 Kids Category, 2.1 App Completeness, 2.3 accurate metadata, 4.8 Login Services, 5.1.1 data collection and storage (including in-app account deletion), 5.1.2 data use and sharing;
   - privacy manifests and required-reason APIs;
   - App Privacy details (nutrition labels);
   - TestFlight and Beta App Review;
   - export compliance (`ITSAppUsesNonExemptEncryption`);
   - Info.plist purpose strings for camera, photos and notifications;
   - app icon requirements;
   - accessibility expectations relevant to review.
4. **Milestone triggers.** Rules that start to apply with Milestone 3 (parent sign-in, Supabase sync, data leaving the device) are present, with `applies_when` set and `status_now: not_applicable_yet`.
5. **Linter.** Add `.claude/skills/apple-requirements/lint_rules.py` (Python standard library only). It fails if:
   - any rule lacks a field;
   - a `source` isn't an Apple URL;
   - `checked` isn't a date;
   - a rule with `check: static` or `simulator` has a `test` that is neither a real path nor `todo:<slice>`;
   - ids are duplicated.
6. **Reviewer.** Update `.claude/agents/app-store-reviewer.md` to use the skill's catalogue as its checklist and to report by rule id. It stays read-only.
7. **Docs.** `docs/APP_STORE_COMPLIANCE.md` links the catalogue. Add a short note to `docs/DECISIONS.md` **only if** you find a rule that conflicts with an existing decision; describe the conflict and don't change the decision.

Facts must come from pages fetched during this attempt. If a page can't be fetched, mark the rule `status_now: unknown` and say why. Don't fill gaps from memory.

## Proof contract

- [ ] `python3 .claude/skills/apple-requirements/lint_rules.py` passes on the attempt branch
- [ ] The catalogue covers every area in mini-requirement 3, and every rule has an Apple source URL and a checked date
- [ ] Every rule names its check type and its test or checklist item, and the Milestone 3 rules are present as `not_applicable_yet`
- [ ] `app-store-reviewer` uses the catalogue, and the slice `PROGRESS.md` and `ATTEMPTS.md` are updated

## Source material

- `.claude/agents/app-store-reviewer.md`, `docs/APP_STORE_COMPLIANCE.md`, `docs/APPLE_HANDOFF.md`, `docs/DECISIONS.md` (D-016, D-017, D-018, D-026, D-027, D-031), `docs/PRODUCT.md` (users: one parent, one child), `apps/ios/Config/`
- Apple: App Review Guidelines, privacy manifest and required-reason API documentation, App Privacy details, TestFlight documentation, export compliance documentation
