---
id: OPR.99.0.2.2
slice: 02-static-compliance-checks
mission: m0
status: placeholder
stage: wip
verified: 2026-11-02 against scaffold (rig scope create)
created: 2026-11-02
intent: "Automated static checks of the repo against the Apple rule catalogue"
depends_on: [OPR.99.0.2.1]
acceptance: "python3 -m unittest discover -s apps/ios/scripts/compliance/tests && python3 apps/ios/scripts/compliance/static_checks.py"
approved-spec-by: nate@external
approved-spec-at: 2026-11-02T18:41:31.404Z
locked-artifacts:
  - name: Specification
    path: SPEC.md
    kind: spec
provenance: transport:v1
---

# Slice 02 — Static Compliance Checks

## Intent

Turn the catalogue's `check: static` rules into checks that run on Linux and macOS with no Apple tools, so every change gets them for free.

## Mini-requirements

1. Add `apps/ios/scripts/compliance/static_checks.py` (Python standard library only; `plistlib` for plists). It reads the catalogue from slice 01 and runs one check per static rule. It prints one line per rule (`PASS`, `FAIL` with the file and reason, or `SKIP` with why) and exits non-zero on any `FAIL`. At least these checks:
   - the privacy manifest is a valid plist and is listed as a resource for both the app and Share Extension targets in `project.yml`;
   - each required-reason API used in `WantWise/`, `WantWiseShare/`, `Shared/` and `WantWiseCore/Sources` has a matching declared reason in the manifest;
   - each permission-gated API in use has its purpose string in the right Info.plist;
   - no networking or third-party package is present without a matching manifest or App Privacy note in `docs/APP_STORE_COMPLIANCE.md`;
   - `ITSAppUsesNonExemptEncryption` is set;
   - entitlements and the App Group are consistent between the targets;
   - the app icon is 1024×1024 with no alpha. Use Python's `struct` to read the PNG header, with no third-party imaging library.
2. Add `apps/ios/scripts/compliance/tests/` with `unittest` tests for the checker itself, using small fixture files that pass and fail each check.
3. Update the catalogue: each rule covered here has `test:` pointing at its check.
4. Run it on the current repo:
   - **Fix a real failure only if the fix is small and within `CLAUDE.md`'s rules**, such as a missing purpose string or a missing manifest reason.
   - **Anything else is not suppressed.** Record it in `docs/APP_STORE_COMPLIANCE.md` and mark its rule `status_now: not_met`. Then the checker's exit for that rule is an explicit, listed `KNOWN` with the reason, and it fails again if the finding changes.
5. Document how to run it in `docs/DEVELOPMENT.md` (Testing strategy).

## Proof contract

- [ ] `python3 -m unittest discover -s apps/ios/scripts/compliance/tests && python3 apps/ios/scripts/compliance/static_checks.py` passes on the attempt branch
- [ ] Every `check: static` rule in the catalogue has a check, a passing fixture and a failing fixture
- [ ] Every real finding is either fixed or recorded as `KNOWN` with its reason in `docs/APP_STORE_COMPLIANCE.md`, none silently skipped
- [ ] `docs/DEVELOPMENT.md`, the slice `PROGRESS.md` and `ATTEMPTS.md` are updated

## Source material

- Slice 01's catalogue; `apps/ios/Config/` (Info.plists, entitlements, `PrivacyInfo.xcprivacy`); `apps/ios/project.yml`; `docs/APP_STORE_COMPLIANCE.md`
