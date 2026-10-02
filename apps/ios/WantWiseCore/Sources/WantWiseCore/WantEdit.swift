import Foundation

/// Editable fields of an existing Want. Status and dates change only through decisions (Transitions.swift).
public struct WantEdit: Sendable, Equatable {
    public var title: String
    public var details: String?
    public var productURL: String?
    public var price: Money?
    public var reason: String?
    public var similarItemAnswer: SimilarItemAnswer?
    public var similarItemNote: String?

    public init(
        title: String,
        details: String? = nil,
        productURL: String? = nil,
        price: Money? = nil,
        reason: String? = nil,
        similarItemAnswer: SimilarItemAnswer? = nil,
        similarItemNote: String? = nil
    ) {
        self.title = title
        self.details = details
        self.productURL = productURL
        self.price = price
        self.reason = reason
        self.similarItemAnswer = similarItemAnswer
        self.similarItemNote = similarItemNote
    }

    /// Starts an edit from a Want's current values.
    public init(_ want: Want) {
        self.init(
            title: want.title,
            details: want.details,
            productURL: want.productURL,
            price: want.price,
            reason: want.reason,
            similarItemAnswer: want.similarItemAnswer,
            similarItemNote: want.similarItemNote
        )
    }
}

extension Want {
    public func updating(_ edit: WantEdit, now: Date) throws -> Want {
        var want = self
        want.title = edit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        want.details = edit.details.nilIfBlank
        want.productURL = edit.productURL.nilIfBlank
        want.priceMinor = edit.price?.minorUnits
        if let currency = edit.price?.currency { want.currency = currency }
        want.reason = edit.reason.nilIfBlank
        want.similarItemAnswer = edit.similarItemAnswer
        want.similarItemNote = edit.similarItemNote.nilIfBlank
        guard want.isRecognisable else { throw WantDraft.Problem.nothingToRecognise }
        want.updatedAt = now
        return want
    }

    /// Replaces (or removes) the primary image. Image files are immutable; a new image gets a new file name.
    public func withImage(_ filename: String?, now: Date) -> Want {
        var want = self
        want.imageFilename = filename
        want.updatedAt = now
        return want
    }

    public func settingVisibleOnDisplay(_ visible: Bool, now: Date) -> Want {
        var want = self
        want.isVisibleOnDisplay = visible
        want.updatedAt = now
        return want
    }

    /// Soft delete: the record stays (so deletion can sync) but disappears from every list.
    public func softDeleting(now: Date) -> Want {
        var want = self
        want.deletedAt = now
        want.updatedAt = now
        return want
    }

    public func restoring(now: Date) -> Want {
        var want = self
        want.deletedAt = nil
        want.updatedAt = now
        return want
    }

    /// Has a name, a picture or a link: something the child can recognise later.
    public var isRecognisable: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageFilename != nil || productURL != nil
    }

    /// Whole calendar days between capture and the latest decision ("You thought about it for 9 days").
    public func thinkingDays(calendar: Calendar) -> Int? {
        guard let decidedAt else { return nil }
        return CalendarDays.between(createdAt, decidedAt, calendar: calendar)
    }
}
