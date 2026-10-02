import Foundation
import Testing
@testable import WantWiseCore

@Suite("Drafts")
struct WantDraftTests {
    let now = TestSupport.date("2026-10-02T14:00:00-04:00")

    @Test func draftWithRevisitBecomesWaiting() throws {
        let draft = WantDraft(
            title: "  Art set ",
            price: Money(minorUnits: 3200, currency: "CAD"),
            reason: "I want better markers",
            similarItemAnswer: .yes,
            revisitAt: TestSupport.date("2026-10-14T16:00:00-04:00")
        )
        let want = try draft.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        #expect(want.status == .waiting)
        #expect(want.title == "Art set")
        #expect(want.priceMinor == 3200)
        #expect(want.currency == "CAD")
        #expect(want.waitStartedAt == now)
        #expect(want.createdAt == now && want.updatedAt == now)
        #expect(want.isVisibleOnDisplay)
    }

    @Test func draftWithoutRevisitIsCaptured() throws {
        let draft = WantDraft(imageFilename: "abc.jpg", sourceType: .screenshot)
        let want = try draft.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        #expect(want.status == .captured)
        #expect(want.revisitAt == nil)
        #expect(want.displayTitle == "Something I saw")
        #expect(want.phase(now: now) == .needsReflection)
    }

    @Test func currencyComesFromPriceOtherwiseDefault() throws {
        let usd = try WantDraft(title: "Game", price: Money(minorUnits: 1999, currency: "USD"))
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        #expect(usd.currency == "USD")
        let noPrice = try WantDraft(title: "Game").makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        #expect(noPrice.currency == "CAD")
        #expect(noPrice.priceMinor == nil)
    }

    @Test func blankDraftIsRejected() {
        let draft = WantDraft(title: "   ")
        #expect(draft.validate(now: now) == [.nothingToRecognise])
        #expect(throws: WantDraft.Problem.nothingToRecognise) {
            try draft.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        }
    }

    @Test func pastRevisitIsRejected() {
        let draft = WantDraft(title: "x", revisitAt: TestSupport.date("2026-10-01T16:00:00-04:00"))
        #expect(draft.validate(now: now) == [.revisitNotInFuture])
    }

    @Test func blankOptionalTextBecomesNil() throws {
        let want = try WantDraft(title: "x", reason: "  ", similarItemNote: "")
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        #expect(want.reason == nil)
        #expect(want.similarItemNote == nil)
    }

    @Test func urlHostAsTitleFallback() {
        var want = TestSupport.waitingWant()
        want.title = ""
        want.productURL = "https://www.amazon.ca/dp/B0123"
        #expect(want.displayTitle == "amazon.ca")
    }
}

@Suite("Transitions and decision history")
struct TransitionTests {
    let calendar = TestSupport.calendar()

    @Test func readyIsDerivedNotStored() {
        let want = TestSupport.waitingWant()
        #expect(want.phase(now: TestSupport.date("2026-10-09T15:59:59-04:00")) == .waiting)
        #expect(want.phase(now: TestSupport.date("2026-10-09T16:00:00-04:00")) == .readyToReconsider)
        #expect(want.status == .waiting)
    }

    @Test func stillWant() throws {
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        let outcome = try TestSupport.waitingWant().deciding(.stillWant, note: "I still need them", now: now)
        #expect(outcome.want.status == .stillWant)
        #expect(outcome.want.decidedAt == now)
        #expect(outcome.want.decisionReason == "I still need them")
        #expect(outcome.decision.kind == .stillWant)
        #expect(outcome.decision.wantId == outcome.want.id)
        #expect(outcome.want.updatedAt == now)
    }

    @Test func waitLongerResetsWaitAndRecordsDates() throws {
        let want = TestSupport.waitingWant()
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        let newRevisit = RevisitPolicy.standard.revisitDate(afterDays: 7, from: now, calendar: calendar)
        let outcome = try want.deciding(.waitLonger, newRevisitAt: newRevisit, now: now)
        #expect(outcome.want.status == .waiting)
        #expect(outcome.want.revisitAt == newRevisit)
        #expect(outcome.want.waitStartedAt == now)
        #expect(outcome.want.decidedAt == nil)
        #expect(outcome.decision.previousRevisitAt == want.revisitAt)
        #expect(outcome.decision.newRevisitAt == newRevisit)
        #expect(outcome.want.phase(now: now) == .waiting)
        #expect(outcome.want.hasWaitedLonger(history: [outcome.decision]))
        #expect(!want.hasWaitedLonger(history: []))
    }

    @Test func waitLongerNeedsFutureDate() {
        let want = TestSupport.waitingWant()
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        #expect(throws: TransitionError.missingRevisitDate) { try want.deciding(.waitLonger, now: now) }
        #expect(throws: TransitionError.revisitNotInFuture) {
            try want.deciding(.waitLonger, newRevisitAt: now, now: now)
        }
    }

    @Test func noLongerWant() throws {
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        let outcome = try TestSupport.waitingWant().deciding(.noLongerWant, now: now)
        #expect(outcome.want.status == .noLongerWant)
        #expect(outcome.want.allowedDecisions.isEmpty)
    }

    @Test func earlyReconsiderIsAllowed() throws {
        let early = TestSupport.date("2026-10-03T10:00:00-04:00")
        let outcome = try TestSupport.waitingWant().deciding(.noLongerWant, now: early)
        #expect(outcome.want.status == .noLongerWant)
    }

    @Test func stillWantThenPurchased() throws {
        let t1 = TestSupport.date("2026-10-09T17:00:00-04:00")
        let t2 = TestSupport.date("2026-10-12T10:00:00-04:00")
        let first = try TestSupport.waitingWant().deciding(.stillWant, now: t1)
        let second = try first.want.deciding(.purchased, now: t2)
        #expect(second.want.status == .purchased)
        #expect(second.want.decidedAt == t2)
        #expect([first.decision, second.decision].map(\.kind) == [.stillWant, .purchased])
    }

    @Test func finalStatesAcceptNoDecisions() throws {
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        let gone = try TestSupport.waitingWant().deciding(.noLongerWant, now: now).want
        for kind in DecisionKind.allCases {
            #expect(throws: TransitionError.notAllowed(from: .noLongerWant, kind: kind)) {
                try gone.deciding(kind, newRevisitAt: now.addingTimeInterval(86_400), now: now)
            }
        }
    }

    @Test func cannotBuyStraightFromWaiting() {
        let now = TestSupport.date("2026-10-09T17:00:00-04:00")
        #expect(throws: TransitionError.notAllowed(from: .waiting, kind: .purchased)) {
            try TestSupport.waitingWant().deciding(.purchased, now: now)
        }
    }

    @Test func finishingReflectionMovesCapturedToWaiting() throws {
        let created = TestSupport.date("2026-10-02T14:00:00-04:00")
        let captured = try WantDraft(imageFilename: "a.jpg", sourceType: .screenshot)
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: created)
        let later = TestSupport.date("2026-10-02T19:00:00-04:00")
        let revisit = RevisitPolicy.standard.revisitDate(afterDays: 3, from: later, calendar: calendar)
        let waiting = try captured.finishingReflection(reason: "Looks fun", similarItemAnswer: .no, revisitAt: revisit, now: later)
        #expect(waiting.status == .waiting)
        #expect(waiting.reason == "Looks fun")
        #expect(waiting.waitStartedAt == later)
        #expect(waiting.createdAt == created)
        #expect(throws: TransitionError.notCaptured(.waiting)) {
            try waiting.finishingReflection(reason: nil, similarItemAnswer: nil, revisitAt: revisit, now: later)
        }
    }
}
