import Foundation

/// The canonical Want record. Field meanings are documented in docs/DATA_MODEL.md.
///
/// This is a plain value type. The iOS app persists it via SwiftData entities that convert to and from `Want`,
/// and the same shape maps 1:1 to the Supabase `wants` table.
public struct Want: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var childId: UUID
    public var title: String
    public var details: String?
    public var productURL: String?
    /// File name of the Want's primary image (a screenshot, photo or link preview). Not a path.
    public var imageFilename: String?
    public var sourceType: SourceType
    public var priceMinor: Int?
    /// ISO 4217 code. Always explicit per Want (D-020).
    public var currency: String
    public var reason: String?
    public var similarItemAnswer: SimilarItemAnswer?
    public var similarItemNote: String?
    public var status: WantStatus
    public var revisitAt: Date?
    /// When the current waiting period started. Resets on "Wait longer"; used for progress bars.
    public var waitStartedAt: Date?
    public var decidedAt: Date?
    public var decisionReason: String?
    public var isVisibleOnDisplay: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        childId: UUID,
        title: String,
        details: String? = nil,
        productURL: String? = nil,
        imageFilename: String? = nil,
        sourceType: SourceType,
        priceMinor: Int? = nil,
        currency: String,
        reason: String? = nil,
        similarItemAnswer: SimilarItemAnswer? = nil,
        similarItemNote: String? = nil,
        status: WantStatus,
        revisitAt: Date? = nil,
        waitStartedAt: Date? = nil,
        decidedAt: Date? = nil,
        decisionReason: String? = nil,
        isVisibleOnDisplay: Bool = true,
        createdAt: Date,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.childId = childId
        self.title = title
        self.details = details
        self.productURL = productURL
        self.imageFilename = imageFilename
        self.sourceType = sourceType
        self.priceMinor = priceMinor
        self.currency = currency
        self.reason = reason
        self.similarItemAnswer = similarItemAnswer
        self.similarItemNote = similarItemNote
        self.status = status
        self.revisitAt = revisitAt
        self.waitStartedAt = waitStartedAt
        self.decidedAt = decidedAt
        self.decisionReason = decisionReason
        self.isVisibleOnDisplay = isVisibleOnDisplay
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}

extension Want {
    public var isDeleted: Bool { deletedAt != nil }

    public var price: Money? {
        priceMinor.map { Money(minorUnits: $0, currency: currency) }
    }

    /// A title is optional for image captures, so there's always something sensible to show.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = productURL.flatMap(URL.init(string:))?.host {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return "Something I saw"
    }

    public func phase(now: Date) -> WantPhase {
        switch status {
        case .captured: return .needsReflection
        case .waiting:
            if let revisitAt, revisitAt <= now { return .readyToReconsider }
            return .waiting
        case .stillWant: return .stillWant
        case .purchased: return .purchased
        case .noLongerWant: return .noLongerWant
        }
    }

    /// Fraction of the current waiting period that has passed, 0...1. Nil when not waiting.
    public func waitProgress(now: Date) -> Double? {
        guard status == .waiting, let revisitAt else { return nil }
        let start = waitStartedAt ?? createdAt
        let total = revisitAt.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }
}
