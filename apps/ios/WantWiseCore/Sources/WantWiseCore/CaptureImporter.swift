import Foundation

/// Imports completed captures from the inbox into Wants:
///
/// ```
/// Share Extension → Inbox/<id>.jpg + <id>.json → adopt image into ImageFileStore → Want (primary image) → remove inbox item
/// ```
///
/// Persistence is passed in as closures so this runs against SwiftData in the app and plain values in tests.
public enum CaptureImporter {
    public struct Report: Equatable, Sendable {
        public var imported: [UUID] = []
        /// Already present (an earlier import finished but the inbox item wasn't removed): cleaned up, not duplicated.
        public var skippedExisting: [UUID] = []
        public var failed: [UUID] = []
        public var unreadable: Int = 0

        public init() {}
    }

    public static func importAll(
        from inbox: CaptureInbox,
        images: ImageFileStore,
        childId: UUID,
        defaultCurrency: String,
        exists: (UUID) throws -> Bool,
        insert: (Want) throws -> Void
    ) -> Report {
        var report = Report()
        let (items, unreadable) = inbox.pending()
        report.unreadable = unreadable.count

        for item in items {
            let id = item.capture.id
            do {
                if try exists(id) {
                    try? inbox.remove(item)
                    report.skippedExisting.append(id)
                    continue
                }

                var capture = item.capture
                var adopted: String?
                if let imageURL = item.imageURL {
                    adopted = try images.adopt(fileAt: imageURL, for: id)
                }
                capture.imageFilename = adopted

                do {
                    let want = try capture.makeWant(childId: childId, defaultCurrency: defaultCurrency)
                    try insert(want)
                } catch {
                    // Put things back as they were so the next launch can retry with the image intact.
                    if let adopted, let imageURL = item.imageURL, let stored = try? images.url(for: adopted) {
                        try? FileManager.default.moveItem(at: stored, to: imageURL)
                    }
                    throw error
                }
                try? inbox.remove(item)
                report.imported.append(id)
            } catch {
                report.failed.append(id)
            }
        }
        return report
    }
}
