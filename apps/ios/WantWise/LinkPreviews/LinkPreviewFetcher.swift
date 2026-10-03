import Foundation
import LinkPresentation
import UniformTypeIdentifiers

/// What a shared page offers for a Want: its title and a picture (CAPTURE.md → Shared URL).
struct LinkPreview: Sendable, Equatable {
    var title: String?
    /// Raw image data as served; the store downsamples it through `ImageFileStore`.
    var imageData: Data?
}

/// Behind a protocol so tests use a fake and never touch the network.
protocol LinkPreviewFetching: Sendable {
    /// Should stop promptly when its task is cancelled (the store cancels it on timeout).
    func preview(for url: URL) async throws -> LinkPreview
}

/// `LPMetadataProvider`: contacts only the shared site; nothing is sent to us.
struct LinkPresentationFetcher: LinkPreviewFetching {
    var timeout: TimeInterval = 15

    func preview(for url: URL) async throws -> LinkPreview {
        let metadata = try await fetchMetadata(for: url)
        var imageData: Data?
        if let provider = metadata.imageProvider {
            imageData = await Self.loadImage(provider)
        }
        // The site icon is a last resort: better than nothing for recognising the Want later.
        if imageData == nil, let provider = metadata.iconProvider {
            imageData = await Self.loadImage(provider)
        }
        return LinkPreview(title: metadata.title, imageData: imageData)
    }

    /// One provider per fetch (an `LPMetadataProvider` can fetch only once); cancelling the task cancels the fetch.
    private func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = timeout
        provider.shouldFetchSubresources = true
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                provider.startFetchingMetadata(for: url) { metadata, error in
                    if let metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: error ?? URLError(.cannotLoadFromNetwork))
                    }
                }
            }
        } onCancel: {
            provider.cancel()
        }
    }

    private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
        let progress = Progress(totalUnitCount: 1)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let load = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
                progress.addChild(load, withPendingUnitCount: 1)
            }
        } onCancel: {
            progress.cancel()
        }
    }
}
