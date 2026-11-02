---
id: OPR.99.0.1.1
slice: 01-finish-adding-uitest
mission: m1
status: placeholder
stage: wip
verified: 2026-11-02 against scaffold (rig scope create)
created: 2026-11-02
intent: "Drive the D-032 Finish adding flow in a permanent UI test"
depends_on: []
---

# Slice 01 — UI test for Finish adding

## Intent

Make the D-032 *Finish adding* flow a permanent, driven UI test. `docs/VERIFICATION.md` and `docs/IOS_ROADMAP.md` (step 2.4) list it as "📝 not driven by a UI test"; Follow-up 5 drove it only with a throwaway XCUITest.

## Mini-requirements

1. A new test in `apps/ios/WantWiseUITests` drives the D-032 flow: a share saved without a reason imports as *Finish adding*, the child completes it, saves, and the Want shows on the list with its reason.
2. Stage the imported share through a DEBUG-only launch argument or fixture, in the style of the existing `-WantWise…` arguments. Change app code only as far as the test needs, keep it out of Release builds, and record any new argument in `CLAUDE.md`'s list.
3. Update `docs/VERIFICATION.md` truthfully: the *Finish adding* row moves from 📝 to 🍎 only if the test ran green, with a Mac session log entry giving the Xcode and iOS Simulator versions.

## Proof contract

- [ ] `apps/ios/scripts/mac-build.sh uitest` passes on the attempt branch
- [ ] The new UI test drives *Finish adding* from an imported, reason-less share through to Save
- [ ] `docs/VERIFICATION.md`, the slice `PROGRESS.md` and `ATTEMPTS.md` are updated by the attempt

## Source material

- `docs/DECISIONS.md` D-032; `docs/VERIFICATION.md` (Follow-up 5); `apps/ios/WantWise/Features/AddWant/FinishAddingView.swift`; `apps/ios/WantWiseUITests/WantWiseUITests.swift`; `apps/ios/WantWise/App/WantWiseApp.swift` (launch arguments)
