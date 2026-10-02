import Foundation

/// User-facing wording for decisions and outcomes, in one place so tone stays consistent (PRODUCT.md → Language).
/// Every outcome is framed as a thoughtful decision. Not buying is never "better" than buying.
public enum DecisionCopy {
    public static func actionLabel(_ kind: DecisionKind) -> String {
        switch kind {
        case .stillWant: return "Still want it"
        case .waitLonger: return "Wait longer"
        case .noLongerWant: return "I don't need it anymore"
        case .purchased: return "I got it"
        }
    }

    public static func confirmationTitle(_ kind: DecisionKind) -> String {
        switch kind {
        case .stillWant: return "Still on your list"
        case .waitLonger: return "More time to think"
        case .noLongerWant: return "You changed your mind"
        case .purchased: return "Enjoy it!"
        }
    }

    public static func confirmationMessage(_ kind: DecisionKind) -> String {
        switch kind {
        case .stillWant: return "You gave it time and it still matters to you. That's a thoughtful decision."
        case .waitLonger: return "No rush. We'll look at it together again later."
        case .noLongerWant: return "You gave it time and decided you don't need it. That's a thoughtful decision too."
        case .purchased: return "You took time to decide before getting it."
        }
    }

    /// Short outcome label for history rows and chips.
    public static func outcomeLabel(_ status: WantStatus) -> String {
        switch status {
        case .captured: return "Just added"
        case .waiting: return "Thinking about it"
        case .stillWant: return "Still want it"
        case .purchased: return "Got it"
        case .noLongerWant: return "Changed my mind"
        }
    }

    /// One line per history entry.
    public static func timelineText(_ kind: DecisionKind) -> String {
        switch kind {
        case .stillWant: return "Still wanted it"
        case .waitLonger: return "Chose to wait longer"
        case .noLongerWant: return "Decided not to get it"
        case .purchased: return "Got it"
        }
    }
}

/// A Want's story, oldest first: added, then each decision.
public struct TimelineEntry: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case added
        case decision(DecisionKind)
    }

    public var id: String
    public var date: Date
    public var kind: Kind
    public var text: String
    public var note: String?
    /// For "wait longer": the new revisit date, formatted by the UI.
    public var newRevisitAt: Date?

    public static func entries(for want: Want, decisions: [WantDecision]) -> [TimelineEntry] {
        let added = TimelineEntry(id: "added-\(want.id)", date: want.createdAt, kind: .added, text: "Added to the list")
        let rest = decisions
            .filter { $0.wantId == want.id }
            .sorted { $0.decidedAt < $1.decidedAt }
            .map {
                TimelineEntry(
                    id: $0.id.uuidString,
                    date: $0.decidedAt,
                    kind: .decision($0.kind),
                    text: DecisionCopy.timelineText($0.kind),
                    note: $0.note,
                    newRevisitAt: $0.newRevisitAt
                )
            }
        return [added] + rest
    }
}
