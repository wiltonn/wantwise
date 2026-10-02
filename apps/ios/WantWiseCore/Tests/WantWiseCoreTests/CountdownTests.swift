import Foundation
import Testing
@testable import WantWiseCore

struct SharedCountdownCases: Decodable {
    struct CountdownCase: Decodable {
        struct Expected: Decodable {
            var kind: String
            var days: Int?
            var text: String
        }
        var name: String
        var timeZone: String
        var now: String
        var revisitAt: String
        var expected: Expected
    }
    struct AgoCase: Decodable {
        var name: String
        var timeZone: String
        var createdAt: String
        var now: String
        var expected: String
    }
    var countdown: [CountdownCase]
    var ago: [AgoCase]

    static func load() throws -> SharedCountdownCases {
        let data = try Data(contentsOf: TestSupport.sharedFixtureURL("countdown-cases.json"))
        return try JSONDecoder().decode(SharedCountdownCases.self, from: data)
    }
}

@Suite("Countdown (shared fixture)")
struct CountdownTests {
    @Test func sharedCountdownCases() throws {
        let cases = try SharedCountdownCases.load()
        #expect(!cases.countdown.isEmpty)
        for c in cases.countdown {
            let calendar = TestSupport.calendar(TimeZone(identifier: c.timeZone)!)
            let result = Countdown.until(TestSupport.date(c.revisitAt), now: TestSupport.date(c.now), calendar: calendar)
            let expected: Countdown = switch c.expected.kind {
            case "ready": .ready
            case "today": .today
            case "tomorrow": .tomorrow
            default: .days(c.expected.days ?? -1)
            }
            #expect(result == expected, "\(c.name)")
            #expect(result.text == c.expected.text, "\(c.name)")
        }
    }

    @Test func sharedAgoCases() throws {
        let cases = try SharedCountdownCases.load()
        for c in cases.ago {
            let calendar = TestSupport.calendar(TimeZone(identifier: c.timeZone)!)
            let text = CalendarDays.agoText(since: TestSupport.date(c.createdAt), now: TestSupport.date(c.now), calendar: calendar)
            #expect(text == c.expected, "\(c.name)")
        }
    }

    @Test func reconsiderPromptUsesCalendarDays() {
        let want = TestSupport.waitingWant()
        let prompt = want.reconsiderPrompt(now: TestSupport.date("2026-10-09T16:05:00-04:00"), calendar: TestSupport.calendar())
        #expect(prompt == "You wanted this 7 days ago. What do you think now?")
    }

    @Test func countdownOnlyForWaitingWants() {
        var want = TestSupport.waitingWant()
        let now = TestSupport.date("2026-10-05T12:00:00-04:00")
        #expect(want.countdown(now: now, calendar: TestSupport.calendar()) == .days(4))
        want.status = .stillWant
        #expect(want.countdown(now: now, calendar: TestSupport.calendar()) == nil)
    }

    @Test func waitProgress() {
        let want = TestSupport.waitingWant(created: "2026-10-01T16:00:00-04:00", revisit: "2026-10-11T16:00:00-04:00")
        #expect(want.waitProgress(now: TestSupport.date("2026-10-01T16:00:00-04:00")) == 0)
        #expect(want.waitProgress(now: TestSupport.date("2026-10-06T16:00:00-04:00")) == 0.5)
        #expect(want.waitProgress(now: TestSupport.date("2026-10-20T16:00:00-04:00")) == 1)
    }
}

@Suite("Revisit policy")
struct RevisitPolicyTests {
    let policy = RevisitPolicy.standard
    let calendar = TestSupport.calendar()

    @Test func presetLandsAtFourPMLocal() {
        let now = TestSupport.date("2026-10-02T21:45:00-04:00")
        #expect(policy.revisitDate(afterDays: 7, from: now, calendar: calendar) == TestSupport.date("2026-10-09T16:00:00-04:00"))
        #expect(policy.revisitDate(afterDays: 3, from: now, calendar: calendar) == TestSupport.date("2026-10-05T16:00:00-04:00"))
    }

    @Test func presetAcrossDSTKeepsLocalHour() {
        let now = TestSupport.date("2026-10-30T10:00:00-04:00")
        // Nov 6 is after DST ends, so the offset is -05:00 but the local time is still 4 pm.
        #expect(policy.revisitDate(afterDays: 7, from: now, calendar: calendar) == TestSupport.date("2026-11-06T16:00:00-05:00"))
    }

    @Test func customDayUsesPolicyTime() {
        let picked = TestSupport.date("2026-12-24T09:13:00-05:00")
        #expect(policy.revisitDate(on: picked, calendar: calendar) == TestSupport.date("2026-12-24T16:00:00-05:00"))
    }

    @Test func customPickerStartsTomorrow() {
        let now = TestSupport.date("2026-10-02T23:59:00-04:00")
        #expect(policy.earliestCustomDay(from: now, calendar: calendar) == TestSupport.date("2026-10-03T00:00:00-04:00"))
    }

    @Test func defaultsMatchProduct() {
        #expect(policy.presetDays == [3, 7, 30])
        #expect(policy.defaultDays == 7)
    }
}
