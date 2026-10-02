import Foundation

/// Groups Wants for the home screen (and the Display's ordering), in a fixed, predictable order.
public struct WantSections: Sendable, Equatable {
    /// Waiting period over: oldest revisit first.
    public var ready: [Want]
    /// Captured without a waiting period: newest first.
    public var needsReflection: [Want]
    /// Still thinking: soonest revisit first.
    public var waiting: [Want]
    /// stillWant / purchased / noLongerWant: most recently decided first.
    public var decided: [Want]

    public init(_ wants: [Want], now: Date) {
        let live = wants.filter { !$0.isDeleted }
        ready = live
            .filter { $0.phase(now: now) == .readyToReconsider }
            .sorted { ($0.revisitAt ?? .distantPast, $0.createdAt) < ($1.revisitAt ?? .distantPast, $1.createdAt) }
        needsReflection = live
            .filter { $0.status == .captured }
            .sorted { $0.createdAt > $1.createdAt }
        waiting = live
            .filter { $0.phase(now: now) == .waiting }
            .sorted { ($0.revisitAt ?? .distantFuture, $0.createdAt) < ($1.revisitAt ?? .distantFuture, $1.createdAt) }
        decided = live
            .filter { [.stillWant, .purchased, .noLongerWant].contains($0.status) }
            .sorted { ($0.decidedAt ?? $0.updatedAt) > ($1.decidedAt ?? $1.updatedAt) }
    }

    public var isEmpty: Bool {
        ready.isEmpty && needsReflection.isEmpty && waiting.isEmpty && decided.isEmpty
    }
}
