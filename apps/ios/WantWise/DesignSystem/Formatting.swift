import Foundation
import WantWiseCore

/// Display formatting. Always uses the Want's own currency (D-020).
enum Formatting {
    /// "$49" for whole amounts, "$12.99" otherwise.
    static func price(_ money: Money?) -> String? {
        guard let money else { return nil }
        let digits = Money.fractionDigits(for: money.currency)
        let isWhole = money.minorUnits % Int(pow(10, Double(digits))) == 0
        let style = Decimal.FormatStyle.Currency(code: money.currency)
            .precision(.fractionLength(isWhole ? 0 : digits))
        return money.decimalValue.formatted(style)
    }

    /// "Friday, Oct 9"
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "4 PM"
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// "today at 4 PM" / "tomorrow" / "Friday, Oct 9"
    static func revisit(_ date: Date, now: Date, calendar: Calendar) -> String {
        switch Countdown.until(date, now: now, calendar: calendar) {
        case .ready: return day(date)
        case .today: return "today at \(time(date))"
        case .tomorrow: return "tomorrow"
        case .days: return day(date)
        }
    }

    /// Text shown after saving: "Let's think about this again on Friday, Oct 9."
    static func thinkAgainSentence(_ date: Date, now: Date, calendar: Calendar) -> String {
        switch Countdown.until(date, now: now, calendar: calendar) {
        case .tomorrow: return "Let's think about this again tomorrow."
        case .today: return "Let's think about this again today at \(time(date))."
        default: return "Let's think about this again on \(day(date))."
        }
    }
}
