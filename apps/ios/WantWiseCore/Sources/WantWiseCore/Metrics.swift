import Foundation

/// Household reflection numbers (DATA_MODEL.md → Reflection metrics). Plain facts, never a score.
public struct ReflectionMetrics: Sendable, Equatable {
    public var consideredThisMonth: Int
    /// Mean time from capture to a decision, over decided Wants. Nil if nothing has been decided.
    public var averageThinkingTime: TimeInterval?
    /// Wants with at least one recorded decision.
    public var reconsideredCount: Int
    /// Sum of prices of Wants let go, by currency code. Currencies are never mixed.
    public var moneyKept: [String: Int]
    /// Share of decided Wants that were let go, 0...1. Nil if nothing has been decided.
    public var letGoShare: Double?

    public init(wants: [Want], decisions: [WantDecision], now: Date, calendar: Calendar) {
        let live = wants.filter { !$0.isDeleted }

        let month = calendar.dateComponents([.year, .month], from: now)
        consideredThisMonth = live.filter {
            calendar.dateComponents([.year, .month], from: $0.createdAt) == month
        }.count

        let decided = live.filter { [.stillWant, .purchased, .noLongerWant].contains($0.status) }
        let durations = decided.compactMap { want in want.decidedAt.map { $0.timeIntervalSince(want.createdAt) } }
        averageThinkingTime = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)

        let liveIds = Set(live.map(\.id))
        reconsideredCount = Set(decisions.map(\.wantId)).intersection(liveIds).count

        var kept: [String: Int] = [:]
        for want in live where want.status == .noLongerWant {
            if let price = want.priceMinor { kept[want.currency, default: 0] += price }
        }
        moneyKept = kept

        let letGo = decided.filter { $0.status == .noLongerWant }.count
        letGoShare = decided.isEmpty ? nil : Double(letGo) / Double(decided.count)
    }
}
