# Progress — Apple Requirements Skill

> Current state and retained outcomes for this slice. In-process steps belong
> in the working agent's todo tool. For current acceptance under the selected
> proof policy, run `rig proof show <slice>`; this log is not a second checklist.
> See the `mission-slice-sop` skill and the conventions SSOT
> (`docs/reference/sdlc-conventions.md` in the OpenRig source repository,
> `$OPENRIG_HOME/reference/sdlc-conventions.md` when installed).

## Current state

Attempt b607bb87 (2026-11-02): built and committed on `att/01-apple-requirements-skill/b607bb87`, waiting for review. Acceptance command `python3 .claude/skills/apple-requirements/lint_rules.py` passes (53 rules: met 20, not_applicable_yet 20, not_met 3, unknown 10).

Next: review by review-verifier. Then slice 02 replaces the `todo:02-static-compliance-checks` tests and slice 03 the `todo:03-simulator-compliance-checks` tests.

## Outcomes

- 2026-11-02 (b607bb87): added `.claude/skills/apple-requirements/` (`SKILL.md`, `rules.yaml`, `lint_rules.py`). Every rule's text comes from an Apple page fetched in this attempt (App Review Guidelines; privacy manifest, required-reason API, Info.plist key, export compliance, notification and app icon documentation; App Privacy details; TestFlight and account deletion pages; HIG app icons and accessibility; Accessibility Nutrition Labels). All 14 coverage areas from mini-requirement 3 are present; Milestone 3 rules (`account_signin`, `third_party_login`, `data_leaves_device`) are `not_applicable_yet`, and the linter enforces both.
- Linter checked against deliberately broken copies (missing field, non-Apple and look-alike hosts, bad date, missing test path, unknown todo slice, checklist on a static rule, duplicate id, unknown field): each fails with exit 1.
- `app-store-reviewer` now uses the catalogue as its checklist and reports by rule id; still read-only.
- Findings: `not_met` for Guideline 5.1.1(i) / App Privacy privacy-policy URL (no policy yet; the checklist had deferred it to Milestone 3) and Guideline 2.2 (TestFlight beta "should be intended for public distribution"). The 2.2 conflict with D-014/D-031 is recorded as open note D-033; no decision changed. Both linked from `docs/APP_STORE_COMPLIANCE.md`.
- Not settled by the fetched pages (marked `unknown`): tester age for the child's Apple Account, App Privacy answers for TestFlight-only builds, export self-classification report, icon color space; "no alpha" for the icon wasn't found on the pages read. The Sign in with Apple overview page returned no readable body.
