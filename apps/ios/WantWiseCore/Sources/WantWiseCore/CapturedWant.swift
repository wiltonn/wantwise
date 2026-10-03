import Foundation

/// The Share Extension → app handoff record, written as `Inbox/<id>.json` in the App Group (CAPTURE.md, D-008).
///
/// Defined in Milestone 1 so the Want model is proven to fit screenshot capture before Milestone 2 builds it.
/// The inbox file I/O and import loop arrive in Milestone 2.
public struct CapturedWant: Codable, Sendable, Equatable, Identifiable {
    /// Bump when the format changes; the app must keep importing older versions.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    /// Becomes the Want's id, which makes importing idempotent.
    public var id: UUID
    public var sourceType: SourceType
    public var title: String?
    public var reason: String?
    public var productURL: String?
    public var sharedText: String?
    /// Image file written next to this record in the inbox, e.g. "<id>.jpg".
    public var imageFilename: String?
    public var revisitAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceType: SourceType,
        title: String? = nil,
        reason: String? = nil,
        productURL: String? = nil,
        sharedText: String? = nil,
        imageFilename: String? = nil,
        revisitAt: Date? = nil,
        createdAt: Date
    ) {
        self.formatVersion = CapturedWant.currentFormatVersion
        self.id = id
        self.sourceType = sourceType
        self.title = title
        self.reason = reason
        self.productURL = productURL
        self.sharedText = sharedText
        self.imageFilename = imageFilename
        self.revisitAt = revisitAt
        self.createdAt = createdAt
    }

    /// Shared text: the first line becomes the title and the first web link the `productURL` (an explicit
    /// `productURL` wins). A text that is only a link gets no title, so the Want shows the host until a preview arrives.
    public var draft: WantDraft {
        let textLink = sharedText.flatMap(LinkExtraction.firstWebLink(in:))
        let textTitle = sharedText.flatMap(Self.firstLine).flatMap { $0 == textLink?.absoluteString ? nil : $0 }
        return WantDraft(
            title: title.nilIfBlank ?? textTitle ?? "",
            details: sharedText.nilIfBlank,
            productURL: productURL.nilIfBlank ?? textLink?.absoluteString,
            imageFilename: imageFilename,
            sourceType: sourceType,
            reason: reason,
            revisitAt: revisitAt
        )
    }

    /// Builds the Want at import time. `createdAt` comes from the capture, not the import, so
    /// "You wanted this N days ago" stays truthful even if the app is opened days later.
    ///
    /// A revisit date that passed before import is kept: the Want will simply show as ready to reconsider.
    public func makeWant(childId: UUID, defaultCurrency: String) throws -> Want {
        var draft = self.draft
        let revisit = draft.revisitAt
        draft.revisitAt = nil
        var want = try draft.makeWant(id: id, childId: childId, defaultCurrency: defaultCurrency, now: createdAt)
        if let revisit {
            want.status = .waiting
            want.revisitAt = revisit
            want.waitStartedAt = createdAt
        }
        return want
    }

    static func firstLine(_ text: String) -> String? {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !line.isEmpty else { return nil }
        return line.count > 60 ? String(line.prefix(57)) + "…" : line
    }
}
