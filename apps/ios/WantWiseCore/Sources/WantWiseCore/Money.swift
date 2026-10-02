import Foundation

/// An exact amount in a currency's minor units (cents for CAD). See DECISIONS.md D-010.
///
/// Display formatting is left to the UI layer (`Text(money.decimalValue, format: .currency(code:))` on iOS,
/// `Intl.NumberFormat` on the Display). That avoids depending on Linux locale data here.
public struct Money: Codable, Sendable, Equatable, Hashable {
    public var minorUnits: Int
    public var currency: String

    public init(minorUnits: Int, currency: String) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    /// Currencies without a minor unit. Everything else is assumed to use 2 decimal places.
    static let zeroDecimalCurrencies: Set<String> = ["JPY", "KRW", "VND", "CLP", "ISK"]

    public static func fractionDigits(for currency: String) -> Int {
        zeroDecimalCurrencies.contains(currency.uppercased()) ? 0 : 2
    }

    public var decimalValue: Decimal {
        var value = Decimal(minorUnits)
        for _ in 0..<Money.fractionDigits(for: currency) { value /= 10 }
        return value
    }

    /// Parses what a child might type into a price field: "49", "49.99", "$12.5", "1,299.00", "12,50".
    /// Returns nil for empty, negative or unreadable input.
    public static func parse(_ input: String, currency: String) -> Money? {
        let allowed = Set("0123456789.,")
        let cleaned = input.filter { allowed.contains($0) }
        guard !cleaned.isEmpty, cleaned.contains(where: \.isNumber) else { return nil }
        if input.contains("-") { return nil }

        let digits = fractionDigits(for: currency)

        // The last separator is a decimal point only if 1–2 digits follow it; otherwise it's a thousands separator.
        var whole = cleaned
        var fraction = ""
        if let lastSeparator = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) {
            let after = cleaned[cleaned.index(after: lastSeparator)...]
            if (1...2).contains(after.count) {
                whole = String(cleaned[..<lastSeparator])
                fraction = String(after)
            }
        }
        whole.removeAll { $0 == "." || $0 == "," }
        if whole.isEmpty { whole = "0" }
        guard let wholeValue = Int(whole) else { return nil }

        if digits == 0 {
            return Money(minorUnits: wholeValue, currency: currency)
        }
        let paddedFraction = (fraction + "00").prefix(digits)
        guard let fractionValue = Int(paddedFraction) else { return nil }
        let (scaled, overflow) = wholeValue.multipliedReportingOverflow(by: 100)
        guard !overflow else { return nil }
        return Money(minorUnits: scaled + fractionValue, currency: currency)
    }
}
