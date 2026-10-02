import Foundation

/// File-based storage for a Want's primary image (screenshot, photo or link preview). See DECISIONS.md D-009/D-019.
///
/// - Images live as files; the database stores only the file name.
/// - Files are immutable: replacing an image writes a new file name (`<wantId>-<random>.jpg`). That keeps
///   sync simple later (Supabase Storage objects never change in place).
/// - Encoding (downsampling to JPEG) is injected so this type stays Foundation-only and testable on Linux.
///   The iOS app passes an ImageIO-based encoder.
public final class ImageFileStore: @unchecked Sendable {
    public enum StoreError: Error, Equatable {
        case invalidFilename(String)
    }

    public let directory: URL
    private let encode: @Sendable (Data) throws -> Data
    private let fileManager = FileManager.default

    public init(directory: URL, encode: @escaping @Sendable (Data) throws -> Data = { $0 }) {
        self.directory = directory
        self.encode = encode
    }

    /// Encodes and saves image data for a Want. Returns the new file name.
    public func save(_ data: Data, for wantId: UUID) throws -> String {
        let encoded = try encode(data)
        let filename = Self.newFilename(for: wantId)
        try ensureDirectory()
        try encoded.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    /// Moves an already-encoded file (e.g. from the capture inbox) into the store. Returns the new file name.
    public func adopt(fileAt source: URL, for wantId: UUID) throws -> String {
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension.lowercased()
        let filename = Self.newFilename(for: wantId, ext: ext)
        try ensureDirectory()
        let destination = directory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: source, to: destination)
        return filename
    }

    public func url(for filename: String) throws -> URL {
        guard Self.isValid(filename) else { throw StoreError.invalidFilename(filename) }
        return directory.appendingPathComponent(filename)
    }

    public func exists(_ filename: String) -> Bool {
        guard let url = try? url(for: filename) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    /// Deleting a missing file is not an error.
    public func delete(_ filename: String) throws {
        let url = try url(for: filename)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    /// Files no Want references any more (e.g. after an image was replaced and the old delete failed).
    public func orphans(referenced: Set<String>) -> [String] {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { !referenced.contains($0) && !$0.hasPrefix(".") }.sorted()
    }

    static func newFilename(for wantId: UUID, ext: String = "jpg") -> String {
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(wantId.uuidString.lowercased())-\(suffix).\(ext)"
    }

    /// A bare file name: no path separators, no traversal, not hidden.
    static func isValid(_ filename: String) -> Bool {
        !filename.isEmpty && !filename.contains("/") && !filename.contains("\\") && !filename.hasPrefix(".")
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
