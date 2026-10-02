import Foundation

/// How revisit dates are chosen. See DATA_MODEL.md → Revisit dates.
public struct RevisitPolicy: Sendable, Equatable {
    /// Revisits land at this local hour: after school, notification-friendly.
    public var hour: Int
    public var minute: Int
    public var presetDays: [Int]
    public var defaultDays: Int

    public init(hour: Int = 16, minute: Int = 0, presetDays: [Int] = [3, 7, 30], defaultDays: Int = 7) {
        self.hour = hour
        self.minute = minute
        self.presetDays = presetDays
        self.defaultDays = defaultDays
    }

    public static let standard = RevisitPolicy()

    /// The local calendar day `days` after `now`, at the policy time.
    public func revisitDate(afterDays days: Int, from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: days, to: today) ?? today
        return revisitDate(on: day, calendar: calendar)
    }

    /// The given calendar day (any time on it) at the policy time. Used for a custom date.
    public func revisitDate(on day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }

    /// The earliest day a custom date picker should allow: tomorrow. "Think about it for zero days" isn't waiting.
    public func earliestCustomDay(from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
