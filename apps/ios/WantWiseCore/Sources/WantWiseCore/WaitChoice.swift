import Foundation

/// "Think about it for: 3 days · 7 days · 30 days · Pick a date"
public enum WaitChoice: Hashable, Sendable {
    case days(Int)
    /// Any time on the chosen calendar day; the policy sets the hour.
    case custom(Date)

    public static func presets(_ policy: RevisitPolicy = .standard) -> [WaitChoice] {
        policy.presetDays.map(WaitChoice.days)
    }

    public static func recommended(_ policy: RevisitPolicy = .standard) -> WaitChoice {
        .days(policy.defaultDays)
    }

    public func revisitDate(from now: Date, policy: RevisitPolicy = .standard, calendar: Calendar) -> Date {
        switch self {
        case .days(let n): return policy.revisitDate(afterDays: n, from: now, calendar: calendar)
        case .custom(let day): return policy.revisitDate(on: day, calendar: calendar)
        }
    }

    /// Label for preset chips. Custom dates are labelled by the UI with a formatted date.
    public var presetLabel: String? {
        guard case .days(let n) = self else { return nil }
        return CalendarDays.durationText(n)
    }
}

extension CalendarDays {
    /// "1 day", "7 days", "less than a day"
    public static func durationText(_ days: Int) -> String {
        switch days {
        case ...0: return "less than a day"
        case 1: return "1 day"
        default: return "\(days) days"
        }
    }
}
