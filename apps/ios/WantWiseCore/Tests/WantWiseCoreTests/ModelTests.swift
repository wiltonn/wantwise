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
            reason: "My friend has one",
            imageFilename: "shot.jpg",
            revisitAt: TestSupport.date("2026-10-05T16:00:00-04:00"),
            createdAt: TestSupport.date("2026-10-02T14:00:00-04:00")
        )
        let want = try capture.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.phase(now: TestSupport.date("2026-10-06T09:00:00-04:00")) == .readyToReconsider)
    }

    @Test(arguments: [nil, "", "   ", " \n\t "] as [String?])
    func captureWithoutReasonIsCapturedEvenWithAWaitChoice(reason: String?) throws {
        let createdAt = TestSupport.date("2026-10-02T14:00:00-04:00")
        let capture = CapturedWant(
            sourceType: .screenshot,
            reason: reason,
            imageFilename: "shot.jpg",
            revisitAt: TestSupport.date("2026-10-09T16:00:00-04:00"),
            createdAt: createdAt
        )
        let want = try capture.makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.status == .captured)
        #expect(want.revisitAt == nil)
        #expect(want.waitStartedAt == nil)
        #expect(want.reason == nil)
        #expect(want.createdAt == createdAt)
        #expect(want.phase(now: createdAt) == .needsReflection)
    }

    @Test func captureWithReasonWaitsUntilItsDate() throws {
        let revisit = TestSupport.date("2026-10-09T16:00:00-04:00")
        let want = try CapturedWant(sourceType: .sharedURL, reason: " So fast ", productURL: "https://example.com/x",
                                    revisitAt: revisit, createdAt: TestSupport.date("2026-10-02T14:00:00-04:00"))
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.status == .waiting)
        #expect(want.revisitAt == revisit)
        #expect(want.reason == "So fast")
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

    @Test func linkInSharedTextBecomesProductURL() throws {
        let text = "Look at this https://www.lego.com/en-ca/product/x it's cool"
        let want = try CapturedWant(sourceType: .sharedText, sharedText: text, createdAt: .now)
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.productURL == "https://www.lego.com/en-ca/product/x")
        #expect(want.details == text)
        #expect(want.title == text)
    }

    @Test func explicitProductURLWinsOverTextLink() throws {
        let capture = CapturedWant(
            sourceType: .sharedText,
            productURL: "https://example.com/explicit",
            sharedText: "see https://other.example.com/x",
            createdAt: .now
        )
        #expect(capture.draft.productURL == "https://example.com/explicit")
    }

    @Test func textThatIsOnlyALinkShowsTheHost() throws {
        let want = try CapturedWant(sourceType: .sharedText, sharedText: "https://www.lego.com/en-ca/product/x\n", createdAt: .now)
            .makeWant(childId: TestSupport.childId, defaultCurrency: "CAD")
        #expect(want.title == "")
        #expect(want.displayTitle == "lego.com")
        #expect(want.productURL == "https://www.lego.com/en-ca/product/x")
    }

    @Test func textWithoutLinkHasNoProductURL() throws {
        #expect(CapturedWant(sourceType: .sharedText, sharedText: "A blue bike", createdAt: .now).draft.productURL == nil)
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

@Suite("Links in shared text")
struct LinkExtractionTests {
    private func link(_ text: String) -> String? { LinkExtraction.firstWebLink(in: text)?.absoluteString }

    @Test func midSentence() {
        #expect(link("I want this https://example.com/toy?id=3 so much") == "https://example.com/toy?id=3")
    }

    @Test func trailingPunctuationIsTrimmed() {
        #expect(link("Here: https://example.com/a.") == "https://example.com/a")
        #expect(link("(see https://example.com/b)") == "https://example.com/b")
        #expect(link("https://example.com/c, and more") == "https://example.com/c")
        #expect(link("Wow https://example.com/d!?") == "https://example.com/d")
    }

    @Test func parenthesesThatBelongToTheLinkAreKept() {
        #expect(link("https://en.wikipedia.org/wiki/Lego_(company).") == "https://en.wikipedia.org/wiki/Lego_(company)")
    }

    @Test func linkGluedToPrecedingText() {
        #expect(link("link:https://example.com/e") == "https://example.com/e")
    }

    @Test func firstOfSeveralWins() {
        #expect(link("http://first.example.com then https://second.example.com") == "http://first.example.com")
        #expect(link("line one\nHTTPS://Upper.example.com/x\nhttps://b.example.com") == "HTTPS://Upper.example.com/x")
    }

    @Test func noLink() {
        #expect(link("Just words, no link.") == nil)
        #expect(link("") == nil)
        #expect(link("https://") == nil)
        #expect(link("example.com without a scheme") == nil)
    }

    @Test func nonWebSchemesAreIgnored() {
        #expect(link("mailto:me@example.com ftp://files.example.com tel:123 javascript:alert(1)") == nil)
        #expect(link("ftp://files.example.com then https://ok.example.com") == "https://ok.example.com")
    }
}

@Suite("Link preview rules")
struct LinkPreviewRuleTests {
    private let now = TestSupport.date("2026-10-03T09:00:00-04:00")

    private func shared(_ title: String = "", url: String? = "https://www.amazon.ca/dp/B0X", image: String? = nil,
                        source: SourceType = .sharedURL) -> Want {
        Want(childId: TestSupport.childId, title: title, productURL: url, imageFilename: image, sourceType: source,
             currency: "CAD", status: .captured, createdAt: TestSupport.date("2026-10-02T14:00:00-04:00"))
    }

    @Test func onlySharedLinksWithoutImageWantAPreview() {
        #expect(shared().wantsLinkPreview)
        #expect(shared(source: .sharedText).wantsLinkPreview)
        #expect(!shared(image: "x.jpg").wantsLinkPreview)
        #expect(!shared(source: .manual).wantsLinkPreview)
        #expect(!shared(url: nil).wantsLinkPreview)
        #expect(!shared(url: "ftp://files.example.com/x").wantsLinkPreview)
    }

    @Test func placeholderTitles() {
        #expect(shared("").hasPlaceholderTitle)
        #expect(shared("amazon.ca").hasPlaceholderTitle)
        #expect(shared("www.amazon.ca").hasPlaceholderTitle)
        #expect(shared(" Amazon.ca ").hasPlaceholderTitle)
        #expect(!shared("Red scooter").hasPlaceholderTitle)
        #expect(!shared("lego.com").hasPlaceholderTitle)
    }

    @Test func pageTitleReplacesOnlyAPlaceholder() {
        let fromHost = shared("amazon.ca").applyingLinkPreview(title: "Razor A5 Scooter", imageFilename: nil, now: now)
        #expect(fromHost.title == "Razor A5 Scooter")
        #expect(fromHost.updatedAt == now)

        let typed = shared("My scooter").applyingLinkPreview(title: "Razor A5 Scooter", imageFilename: nil, now: now)
        #expect(typed.title == "My scooter")
        #expect(typed.updatedAt != now)
    }

    @Test func imageIsUsedOnlyWhenThereIsNone() {
        #expect(shared().applyingLinkPreview(title: nil, imageFilename: "p.jpg", now: now).imageFilename == "p.jpg")
        #expect(shared(image: "mine.jpg").applyingLinkPreview(title: nil, imageFilename: "p.jpg", now: now).imageFilename == "mine.jpg")
    }

    @Test func blankOrLongPageTitles() {
        #expect(shared("").applyingLinkPreview(title: "  ", imageFilename: nil, now: now).title == "")
        let long = String(repeating: "a", count: 200)
        #expect(shared("").applyingLinkPreview(title: long, imageFilename: nil, now: now).title.count == 80)
    }
}
