import Foundation
import Testing
@testable import WantWiseCore

@Suite("Money")
struct MoneyTests {
    @Test(arguments: [
        ("49", 4900),
        ("49.99", 4999),
        ("$12.5", 1250),
        ("12,50", 1250),
        ("1,299", 129_900),
        ("1,299.00", 129_900),
        ("1.299,00", 129_900),
        (".99", 99),
        (" 32 ", 3200),
    ])
    func parsesCAD(input: String, cents: Int) {
        #expect(Money.parse(input, currency: "CAD") == Money(minorUnits: cents, currency: "CAD"))
    }

    @Test(arguments: ["", "abc", "-5", "$"])
    func rejectsBadInput(input: String) {
        #expect(Money.parse(input, currency: "CAD") == nil)
    }

    @Test func zeroDecimalCurrency() {
        #expect(Money.parse("1500", currency: "JPY") == Money(minorUnits: 1500, currency: "JPY"))
        #expect(Money(minorUnits: 1500, currency: "JPY").decimalValue == Decimal(1500))
    }

    @Test func decimalValue() {
        #expect(Money(minorUnits: 4999, currency: "CAD").decimalValue == Decimal(string: "49.99"))
    }
}

@Suite("Sections")
struct SectionTests {
    @Test func groupsAndOrders() throws {
        let now = TestSupport.date("2026-10-10T12:00:00-04:00")
        let ready = TestSupport.waitingWant(revisit: "2026-10-09T16:00:00-04:00")
        let soon = TestSupport.waitingWant(revisit: "2026-10-11T16:00:00-04:00")
        let later = TestSupport.waitingWant(revisit: "2026-10-30T16:00:00-04:00")
        let captured = try WantDraft(imageFilename: "a.jpg", sourceType: .screenshot)
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD", now: now)
        let decided = try TestSupport.waitingWant().deciding(.noLongerWant, now: now).want
        var deleted = TestSupport.waitingWant()
        deleted.deletedAt = now

        let sections = WantSections([later, decided, soon, captured, ready, deleted], now: now)
        #expect(sections.ready.map(\.id) == [ready.id])
        #expect(sections.waiting.map(\.id) == [soon.id, later.id])
        #expect(sections.needsReflection.map(\.id) == [captured.id])
        #expect(sections.decided.map(\.id) == [decided.id])
        #expect(!sections.isEmpty)
        #expect(WantSections([], now: now).isEmpty)
    }
}

@Suite("Reflection metrics")
struct MetricsTests {
    @Test func computesHouseholdNumbers() throws {
        let calendar = TestSupport.calendar()
        let now = TestSupport.date("2026-10-20T12:00:00-04:00")

        let a = TestSupport.waitingWant(created: "2026-10-01T12:00:00-04:00", revisit: "2026-10-08T16:00:00-04:00", price: 4900)
        let b = TestSupport.waitingWant(created: "2026-10-05T12:00:00-04:00", revisit: "2026-10-08T16:00:00-04:00", price: 1200)
        let c = TestSupport.waitingWant(created: "2026-09-20T12:00:00-04:00", revisit: "2026-10-25T16:00:00-04:00", price: nil)
        var usd = TestSupport.waitingWant(created: "2026-10-06T12:00:00-04:00", revisit: "2026-10-08T16:00:00-04:00", price: 2000)
        usd.currency = "USD"

        let aDone = try a.deciding(.noLongerWant, now: TestSupport.date("2026-10-11T12:00:00-04:00")) // 10 days
        let bDone = try b.deciding(.stillWant, now: TestSupport.date("2026-10-09T12:00:00-04:00"))    // 4 days
        let usdDone = try usd.deciding(.noLongerWant, now: TestSupport.date("2026-10-08T12:00:00-04:00")) // 2 days

        let metrics = ReflectionMetrics(
            wants: [aDone.want, bDone.want, c, usdDone.want],
            decisions: [aDone.decision, bDone.decision, usdDone.decision],
            now: now,
            calendar: calendar
        )
        #expect(metrics.consideredThisMonth == 3)
        #expect(metrics.reconsideredCount == 3)
        #expect(metrics.moneyKept == ["CAD": 4900, "USD": 2000])
        #expect(metrics.letGoShare == 2.0 / 3.0)
        #expect(metrics.averageThinkingTime == (10 + 4 + 2) / 3.0 * 86_400)
    }

    @Test func emptyHasNoAverages() {
        let metrics = ReflectionMetrics(wants: [], decisions: [], now: .now, calendar: TestSupport.calendar())
        #expect(metrics.averageThinkingTime == nil)
        #expect(metrics.letGoShare == nil)
        #expect(metrics.moneyKept.isEmpty)
    }
}

@Suite("Capture inbox format")
struct CapturedWantTests {
    @Test func screenshotCaptureBecomesWaitingWantKeepingCaptureTime() throws {
        let createdAt = TestSupport.date("2026-10-02T14:00:00-04:00")
        let capture = CapturedWant(
            sourceType: .screenshot,
            reason: "I love this design",
            imageFilename: "shot.jpg",
            revisitAt: TestSupport.date("2026-10-05T16:00:00-04:00"),
            createdAt: createdAt
        )
        let want = try capture.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.id == capture.id)
        #expect(want.status == .waiting)
        #expect(want.sourceType == .screenshot)
        #expect(want.imageFilename == "shot.jpg")
        #expect(want.createdAt == createdAt)
        #expect(want.waitStartedAt == createdAt)
        #expect(want.currency == "CAD")
        #expect(want.displayTitle == "Something I saw")
    }

    @Test func revisitThatPassedBeforeImportIsStillImported() throws {
        let capture = CapturedWant(
            sourceType: .screenshot,
            imageFilename: "shot.jpg",
            revisitAt: TestSupport.date("2026-10-05T16:00:00-04:00"),
            createdAt: TestSupport.date("2026-10-02T14:00:00-04:00")
        )
        let want = try capture.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.phase(now: TestSupport.date("2026-10-06T09:00:00-04:00")) == .readyToReconsider)
    }

    @Test func quickCaptureWithoutWaitIsCaptured() throws {
        let capture = CapturedWant(sourceType: .sharedURL, productURL: "https://www.lego.com/en-ca/product/x", createdAt: .now)
        let want = try capture.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.status == .captured)
        #expect(want.displayTitle == "lego.com")
    }

    @Test func sharedTextFirstLineBecomesTitle() throws {
        let text = "NeeDoh Nice Cube - Glow in the dark\nOnly $12 at the store"
        let want = try CapturedWant(sourceType: .sharedText, sharedText: text, createdAt: .now)
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.title == "NeeDoh Nice Cube - Glow in the dark")
        #expect(want.details == text)
    }

    @Test func roundTripsThroughJSON() throws {
        let capture = CapturedWant(
            sourceType: .screenshot,
            title: "Headphones",
            imageFilename: "x.jpg",
            revisitAt: TestSupport.date("2026-10-05T16:00:00-04:00"),
            createdAt: TestSupport.date("2026-10-02T14:00:00-04:00")
        )
        let data = try WantWiseJSON.encoder().encode(capture)
        let decoded = try WantWiseJSON.decoder().decode(CapturedWant.self, from: data)
        #expect(decoded == capture)
        #expect(String(decoding: data, as: UTF8.self).contains("\"formatVersion\" : 1"))
    }

    @Test func wantRoundTripsThroughJSON() throws {
        let want = TestSupport.waitingWant()
        let data = try WantWiseJSON.encoder().encode(want)
        #expect(try WantWiseJSON.decoder().decode(Want.self, from: data) == want)
    }
}
