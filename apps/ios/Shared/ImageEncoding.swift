import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Memory-safe image downsampling to JPEG with ImageIO. Never decodes the full-size bitmap, which matters in the
/// memory-limited Share Extension (CAPTURE.md). Used by the app's ImageFileStore and by the extension.
enum ImageEncoding {
    /// Long edge of stored images. A tall screenshot stays readable on the Display.
    static let maxPixelSize = 2048
    static let jpegQuality = 0.82

    enum EncodingError: Error {
        case unreadable
        case encodeFailed
    }

    /// For `ImageFileStore(encode:)`.
    @Sendable
    static func downsampledJPEG(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw EncodingError.unreadable
        }
        return try encode(source)
    }

    /// Reads straight from a file (e.g. a shared screenshot) without loading it into memory first.
    static func downsampledJPEG(fileURL: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw EncodingError.unreadable
        }
        return try encode(source)
    }

    /// Pixel size without decoding, for screenshot detection.
    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        // EXIF orientations 5–8 are rotated 90°.
        if let orientation = props[kCGImagePropertyOrientation] as? Int, (5...8).contains(orientation) {
            return (height, width)
        }
        return (width, height)
    }

    /// A small decoded thumbnail for on-screen use.
    static func thumbnail(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encode(_ source: CGImageSource) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // bake in EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw EncodingError.unreadable
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw EncodingError.encodeFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw EncodingError.encodeFailed }
        return output as Data
    }
}
