import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers
import WantWiseCore

/// Loads what was shared, and writes a CapturedWant to the App Group inbox.
@MainActor
@Observable
final class CaptureModel {
    enum Phase: Equatable {
        case loading
        case ready
        case saved(revisitAt: Date)
        case failed(String)
    }

    var phase: Phase = .loading
    var preview: UIImage?
    var title = ""
    var reason = ""
    var wait: WaitChoice = .recommended()
    private(set) var sharedURL: URL?
    private(set) var sharedText: String?
    private var imageData: Data?

    @ObservationIgnored var onFinish: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?

    // MARK: - Loading

    func load(from items: [NSExtensionItem]) async {
        let providers = items.flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            imageData = await Self.loadImage(provider)
        }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            sharedURL = await Self.loadURL(provider)
        }
        if imageData == nil, sharedURL == nil,
           let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            sharedText = await Self.loadText(provider)
        }

        preview = imageData.flatMap(UIImage.init(data:))
        if let host = sharedURL?.host, title.isEmpty, imageData == nil { title = host }
        phase = (imageData != nil || sharedURL != nil || sharedText != nil)
            ? .ready
            : .failed("WantWise couldn't read what you shared. Try a screenshot or a link.")
    }

    /// File representation first (no full decode in memory); data representation as a fallback.
    nonisolated private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        let fromFile: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                // The file only exists for the duration of this callback.
                continuation.resume(returning: url.flatMap { try? ImageEncoding.downsampledJPEG(fileURL: $0) })
            }
        }
        if let fromFile { return fromFile }
        return await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data.flatMap { try? ImageEncoding.downsampledJPEG($0) })
            }
        }
    }

    nonisolated private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
    }

    nonisolated private static func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text) }
        }
    }

    // MARK: - Saving

    func save() {
        guard let container = AppGroup.containerURL else {
            phase = .failed("WantWise can't receive shares in this build yet (App Group not configured).")
            return
        }
        let now = Date()
        let revisitAt = wait.revisitDate(from: now, calendar: .current)
        let capture = CapturedWant(
            sourceType: sourceType,
            title: title.isEmpty ? nil : title,
            reason: reason.isEmpty ? nil : reason,
            productURL: sharedURL?.absoluteString,
            sharedText: sharedText,
            revisitAt: revisitAt,
            createdAt: now
        )
        do {
            try CaptureInbox(appGroupContainer: container).write(capture, imageData: imageData)
            phase = .saved(revisitAt: revisitAt)
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                onFinish?()
            }
        } catch {
            phase = .failed("That didn't save. Please try again.")
        }
    }

    func cancel() {
        onCancel?()
    }

    private var sourceType: SourceType {
        if let imageData, let size = ImageEncoding.pixelSize(of: imageData) {
            return SourceType.inferredForLibraryImage(width: size.width, height: size.height)
        }
        if sharedURL != nil { return .sharedURL }
        return .sharedText
    }
}
