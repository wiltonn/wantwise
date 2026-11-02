---
id: OPR.99.0.2.3
slice: 03-simulator-compliance-checks
mission: m0
status: placeholder
stage: wip
verified: 2026-11-02 against scaffold (rig scope create)
created: 2026-11-02
intent: "Simulator checks for accessibility, permission timing, text size and Release contents"
depends_on: [OPR.99.0.2.1]
acceptance: "apps/ios/scripts/mac-build.sh uitest && apps/ios/scripts/compliance/release_bundle_check.sh"
approved-spec-by: nate@external
approved-spec-at: 2026-11-02T18:41:31.706Z
locked-artifacts:
  - name: Specification
    path: SPEC.md
    kind: spec
provenance: transport:v1
---

# Slice 03 — Simulator Compliance Checks

## Intent

Check, in the Simulator, the catalogue's `check: simulator` rules that a static check can't see: accessibility, when permission prompts appear, large text, and what a Release build contains.

## Mini-requirements

1. **Accessibility audit.** Add a UI test that opens each Milestone 1–2 screen in turn (list, add, finish adding, detail, reconsider, decided) and runs Xcode's `XCUIApplication.performAccessibilityAudit()`. Use sample data launch arguments as the existing tests do.
   - **Fix real issues when the fix is small and keeps the design** (labels, traits, hit targets).
   - Anything else goes in an explicit, commented exclusion list in the test, giving the audit type, the element and the reason, plus a line in `docs/VERIFICATION.md`. No blanket exclusions.
2. **Permissions in context.** A UI test launches the app fresh (`-WantWiseResetData`) and asserts that no system permission alert (notifications, photos, camera) appears before the user acts.
3. **Largest text.** A UI test launches at the largest accessibility content size and checks that the list and add screens still expose their primary actions. Combine it with the audit's text-clipping results.
4. **Release contents.** Add `apps/ios/scripts/compliance/release_bundle_check.sh`. It builds Release for the Simulator, unsigned per D-026, and fails if any DEBUG sample-data resource (D-027) or launch-argument handling for sample data is present in the built app.
5. **Records.** Update the catalogue's `test:` fields for these rules, and `docs/VERIFICATION.md` with what ran, the Xcode and iOS Simulator versions, and any exclusions.

## Proof contract

- [ ] `apps/ios/scripts/mac-build.sh uitest && apps/ios/scripts/compliance/release_bundle_check.sh` passes on the attempt branch
- [ ] An accessibility audit runs on every Milestone 1–2 screen, and every exclusion is listed with its reason in the test and in `docs/VERIFICATION.md`
- [ ] Tests show no permission prompt at launch and usable primary actions at the largest text size, and the Release bundle check passes
- [ ] The catalogue, `docs/VERIFICATION.md`, the slice `PROGRESS.md` and `ATTEMPTS.md` are updated

## Source material

- Slice 01's catalogue; `apps/ios/WantWiseUITests/WantWiseUITests.swift`; `apps/ios/WantWise/App/WantWiseApp.swift` (launch arguments); `apps/ios/scripts/mac-build.sh`; D-026, D-027
