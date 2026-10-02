import Foundation

/// How a Want entered WantWise.
public enum SourceType: String, Codable, Sendable, CaseIterable {
    case manual
    case screenshot
    case photo
    case sharedURL
    case sharedText
}

/// Stored status. "Ready to reconsider" is deliberately not here; see `WantPhase` and DECISIONS.md D-006.
public enum WantStatus: String, Codable, Sendable, CaseIterable {
    /// Saved quickly (e.g. from the Share Extension) without a chosen waiting period yet.
    case captured
    /// Has a `revisitAt`; the child is thinking about it.
    case waiting
    case stillWant
    case purchased
    case noLongerWant

    /// No further decisions can be made from these.
    public var isFinal: Bool {
        self == .purchased || self == .noLongerWant
    }
}

/// "Do you already have something similar?"
public enum SimilarItemAnswer: String, Codable, Sendable, CaseIterable {
    case yes
    case no
    case notSure
}

public enum DecisionKind: String, Codable, Sendable, CaseIterable {
    case stillWant
    case waitLonger
    case noLongerWant
    case purchased
}

/// What a Want looks like *right now*, derived from status, revisitAt and the current time.
public enum WantPhase: String, Codable, Sendable, CaseIterable {
    /// `captured`: reason / waiting period not chosen yet.
    case needsReflection
    case waiting
    case readyToReconsider
    case stillWant
    case purchased
    case noLongerWant
}

public enum LovedThingKind: String, Codable, Sendable, CaseIterable {
    case possession
    case experience
    case pet
    case person
    case activity
}
