import Foundation

/// The Share Extension → app handoff folder inside the App Group container (CAPTURE.md, D-008, D-019).
///
/// Writer (extension): image first, then `<id>.json` atomically. The JSON's presence means "complete".
/// Reader (app): import each complete item, then remove it. Import is idempotent because the Want id is the capture id.
public struct CaptureInbox: Sendable {
    public struct Item: Sendable, Equatable {
        public var capture: CapturedWant
        public var recordURL: URL
        /// Nil when the capture had no image, or the image file is missing.
        public var imageURL: URL?
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `<App Group container>/Inbox`
    public init(appGroupContainer: URL) {
        self.init(directory: appGroupContainer.appendingPathComponent("Inbox", isDirectory: true))
    }

    /// Writes a capture. `imageData` should already be downsampled. Returns the record as written.
    @discardableResult
    public func write(_ capture: CapturedWant, imageData: Data?, imageExtension: String = "jpg") throws -> CapturedWant {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var record = capture
        if let imageData {
            let name = "\(capture.id.uuidString.lowercased()).\(imageExtension)"
            try imageData.write(to: directory.appendingPathComponent(name), options: .atomic)
            record.imageFilename = name
        } else {
            record.imageFilename = nil
        }
        let json = try WantWiseJSON.encoder().encode(record)
        try json.write(to: recordURL(for: record.id), options: .atomic)
        return record
    }

    /// Complete captures, oldest first. Unreadable records are skipped (and reported) rather than blocking the rest.
    public func pending() -> (items: [Item], unreadable: [URL]) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return ([], []) }
        var items: [Item] = []
        var unreadable: [URL] = []
        for name in names where name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let capture = try? WantWiseJSON.decoder().decode(CapturedWant.self, from: data) else {
                unreadable.append(url)
                continue
            }
            var imageURL: URL?
            if let imageName = capture.imageFilename, !imageName.contains("/") {
                let candidate = directory.appendingPathComponent(imageName)
                if fm.fileExists(atPath: candidate.path) { imageURL = candidate }
            }
            items.append(Item(capture: capture, recordURL: url, imageURL: imageURL))
        }
        items.sort { $0.capture.createdAt < $1.capture.createdAt }
        return (items, unreadable)
    }

    /// Removes the record and any image still in the inbox (the importer normally moves the image out first).
    public func remove(_ item: Item) throws {
        let fm = FileManager.default
        if let imageURL = item.imageURL, fm.fileExists(atPath: imageURL.path) { try fm.removeItem(at: imageURL) }
        if fm.fileExists(atPath: item.recordURL.path) { try fm.removeItem(at: item.recordURL) }
    }

    func recordURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }
}
