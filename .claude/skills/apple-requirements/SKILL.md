---
name: apple-requirements
description: Apple's App Store, TestFlight and privacy requirements for WantWise as a sourced, dated rule catalogue (rules.yaml). Use before any change to data, permissions, networking, dependencies, Info.plist, entitlements or sign-in, and before a TestFlight upload; also when asked whether WantWise meets an Apple rule, or to refresh the catalogue from Apple's pages.
---

# Apple requirements (WantWise)

`rules.yaml` in this folder lists what Apple requires of WantWise, one rule per entry. Each rule was read from an Apple page on a stated date, says how it is checked, and records whether WantWise meets it today. It replaces memory: if a rule isn't here, or its `checked` date is old, fetch the page before relying on it.

## When to use it

- **Before a change** that touches data storage or sharing, permissions (camera, photos, notifications), networking, dependencies or SDKs, `Info.plist`, entitlements, the privacy manifest, or sign-in/accounts. Find the rules whose `applies_when` matches the change and keep them true (or update their `status_now`).
- **Before a TestFlight upload**: every rule with `applies_when: release`, plus everything `always`. The `app-store-reviewer` agent works through the catalogue and reports by rule id.
- **When a milestone starts**: Milestone 3 (parent sign-in, Supabase sync, data leaving the device) turns on the rules marked `milestone: 3`.

## Reading the catalogue

| Field | Meaning |
|---|---|
| `id` | Stable id. `AR-GL-<n>` = App Review Guideline n; `AR-PM` privacy manifest; `AR-RR` required-reason API; `AR-APD` App Privacy details; `AR-TF` TestFlight; `AR-EXP` export compliance; `AR-PS` purpose strings/permissions; `AR-ICON`; `AR-A11Y`; `AR-ACCT` account deletion; `AR-PRIV` tracking |
| `title` | The rule in one line |
| `area` | Coverage area (the linter requires every area in the slice 01 spec) |
| `source` | The Apple page (developer.apple.com or apple.com) the rule was read from |
| `checked` | Date the page was fetched (YYYY-MM-DD) |
| `applies_when` | `always`, or a trigger: `release`, `networking`, `data_leaves_device`, `account_signin`, `third_party_login`, `camera`, `photos`, `notifications`, `dependencies`, `kids_category` |
| `milestone` | `3` for rules that start to apply with Milestone 3 (these must be `not_applicable_yet`) |
| `check` | `static` (file/grep check, any OS), `simulator` (needs an Xcode run), `review` (the `app-store-reviewer` agent judges it), `person` (someone signs off, usually in App Store Connect) |
| `test` | What covers it: a repo path (optionally `path::TestName`), `todo:<slice>` for a check not written yet, or `checklist:<file>#<heading>` for review/person items |
| `status_now` | WantWise today: `met`, `not_met`, `not_applicable_yet`, `unknown` (with the reason in `notes`) |
| `requirement` | What the page says, quoted or closely paraphrased |
| `notes` | How it applies to WantWise, evidence for `status_now`, and anything the page didn't settle |

Quick queries:

```bash
grep -n "status_now: not_met" -B8 .claude/skills/apple-requirements/rules.yaml   # open problems
grep -n "applies_when: networking" -B5 .claude/skills/apple-requirements/rules.yaml
python3 .claude/skills/apple-requirements/lint_rules.py                          # must pass
```

## Changing or refreshing it

1. **Fetch the page now**; don't write a rule from memory. Many developer.apple.com documentation pages render in the browser only; their content is at `https://developer.apple.com/tutorials/data/documentation/<path>.json` (and `.../tutorials/data/design/human-interface-guidelines/<page>.json` for the HIG). The App Review Guidelines page is plain HTML; its section anchors (`#2.3.7`, `#login-services`) are stable.
2. Update `requirement` from the page text, set `checked` to today, and re-judge `status_now` against the code (say what you grepped or ran in `notes`).
3. If a page can't be fetched or doesn't settle the question, set `status_now: unknown` and say why. Don't fill the gap from memory.
4. Keep `test` honest: point at the real check once slice 02 (`apps/ios/scripts/compliance/static_checks.py`) or slice 03 (Simulator UI tests) adds it.
5. Run the linter. Mirror any status change in `docs/APP_STORE_COMPLIANCE.md`; if a rule conflicts with a decision in `docs/DECISIONS.md`, add a dated note there instead of changing the decision.

The linter (`lint_rules.py`, standard library only) fails on a missing field, a non-Apple or non-https `source`, a bad or future `checked` date, an unknown enum value, a `test` that doesn't resolve, a duplicate id, a missing coverage area, or a Milestone 3 rule that isn't `not_applicable_yet`.
