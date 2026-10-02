import Foundation

/// One entry in a Want's decision history. Append-only: never edited or deleted (D-007).
public struct WantDecision: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var wantId: UUID
    public var kind: DecisionKind
    public var note: String?
    public var previousRevisitAt: Date?
    public var newRevisitAt: Date?
    public var decidedAt: Date

    public init(
        id: UUID = UUID(),
        wantId: UUID,
        kind: DecisionKind,
        note: String? = nil,
        previousRevisitAt: Date? = nil,
        newRevisitAt: Date? = nil,
        decidedAt: Date
    ) {
        self.id = id
        self.wantId = wantId
        self.kind = kind
        self.note = note
        self.previousRevisitAt = previousRevisitAt
        self.newRevisitAt = newRevisitAt
        self.decidedAt = decidedAt
    }
}
