import Foundation

/// Time remaining until a Want should be reconsidered, by local calendar day.
///
/// The same rules are implemented in the Display (apps/display/lib/domain.ts) and both are tested against
/// docs/fixtures/countdown-cases.json.
public enum Countdown: Equatable, Sendable {
    case ready
    case today
    case tomorrow
    case days(Int)

    public static func until(_ revisitAt: Date, now: Date, calendar: Calendar) -> Countdown {
        if revisitAt <= now { return .ready }
        let days = CalendarDays.between(now, revisitAt, calendar: calendar)
        switch days {
        case ...0: return .today
        case 1: return .tomorrow
        default: return .days(days)
        }
    }

    public var text: String {
        switch self {
        case .ready: return "Ready to think again"
        case .today: return "Reconsider today"
        case .tomorrow: return "Reconsider tomorrow"
        case .days(let n): return "\(n) days left"
        }
    }
}

public enum CalendarDays {
    /// Whole local calendar days from `start`'s day to `end`'s day (midnight-to-midnight, DST-safe).
    public static func between(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// "You wanted this 7 days ago." / "earlier today" / "yesterday"
    public static func agoText(since createdAt: Date, now: Date, calendar: Calendar) -> String {
        let days = between(createdAt, now, calendar: calendar)
        switch days {
        case ...0: return "earlier today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }
}

extension Want {
    public func countdown(now: Date, calendar: Calendar) -> Countdown? {
        guard status == .waiting, let revisitAt else { return nil }
        return Countdown.until(revisitAt, now: now, calendar: calendar)
    }

    /// The reconsider prompt: "You wanted this 7 days ago. What do you think now?"
    public func reconsiderPrompt(now: Date, calendar: Calendar) -> String {
        "You wanted this \(CalendarDays.agoText(since: createdAt, now: now, calendar: calendar)). What do you think now?"
    }
}
