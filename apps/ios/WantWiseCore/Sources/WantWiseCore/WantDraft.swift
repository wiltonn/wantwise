import Foundation

/// What the Add Want form (or a capture) collects before a Want exists.
public struct WantDraft: Sendable, Equatable {
    public var title: String
    public var details: String?
    public var productURL: String?
    public var imageFilename: String?
    public var sourceType: SourceType
    public var price: Money?
    public var reason: String?
    public var similarItemAnswer: SimilarItemAnswer?
    public var similarItemNote: String?
    /// Nil means "not chosen yet": the Want is saved as `captured`.
    public var revisitAt: Date?
    public var isVisibleOnDisplay: Bool

    public init(
        title: String = "",
        details: String? = nil,
        productURL: String? = nil,
        imageFilename: String? = nil,
        sourceType: SourceType = .manual,
        price: Money? = nil,
        reason: String? = nil,
        similarItemAnswer: SimilarItemAnswer? = nil,
        similarItemNote: String? = nil,
        revisitAt: Date? = nil,
        isVisibleOnDisplay: Bool = true
    ) {
        self.title = title
        self.details = details
        self.productURL = productURL
        self.imageFilename = imageFilename
        self.sourceType = sourceType
        self.price = price
        self.reason = reason
        self.similarItemAnswer = similarItemAnswer
        self.similarItemNote = similarItemNote
        self.revisitAt = revisitAt
        self.isVisibleOnDisplay = isVisibleOnDisplay
    }

    public enum Problem: Error, Equatable, Sendable {
        /// A Want needs a name, a picture or a link so the child can recognise it later.
        case nothingToRecognise
        case revisitNotInFuture
    }

    public func validate(now: Date) -> [Problem] {
        var problems: [Problem] = []
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasTitle && imageFilename == nil && productURL == nil {
            problems.append(.nothingToRecognise)
        }
        if let revisitAt, revisitAt <= now {
            problems.append(.revisitNotInFuture)
        }
        return problems
    }

    /// Creates the Want. Status is `waiting` when a revisit date was chosen, otherwise `captured`.
    public func makeWant(id: UUID = UUID(), childId: UUID, defaultCurrency: String, now: Date) throws -> Want {
        if let problem = validate(now: now).first { throw problem }
        return Want(
            id: id,
            childId: childId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.nilIfBlank,
            productURL: productURL.nilIfBlank,
            imageFilename: imageFilename,
            sourceType: sourceType,
            priceMinor: price?.minorUnits,
            currency: price?.currency ?? defaultCurrency,
            reason: reason.nilIfBlank,
            similarItemAnswer: similarItemAnswer,
            similarItemNote: similarItemNote.nilIfBlank,
            status: revisitAt == nil ? .captured : .waiting,
            revisitAt: revisitAt,
            waitStartedAt: revisitAt == nil ? nil : now,
            isVisibleOnDisplay: isVisibleOnDisplay,
            createdAt: now
        )
    }
}

extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
