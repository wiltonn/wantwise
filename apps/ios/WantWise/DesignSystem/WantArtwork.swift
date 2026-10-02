import SwiftUI
import UIKit
import WantWiseCore

/// Decodes and caches downsampled images off the main thread.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func cached(_ url: URL, maxPixelSize: Int) -> UIImage? {
        cache.object(forKey: key(url, maxPixelSize))
    }

    func image(at url: URL, maxPixelSize: Int) async -> UIImage? {
        let key = key(url, maxPixelSize)
        if let hit = cache.object(forKey: key) { return hit }
        let cgImage = await Task.detached(priority: .userInitiated) {
            ImageEncoding.thumbnail(at: url, maxPixelSize: maxPixelSize)
        }.value
        guard let cgImage else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }

    private func key(_ url: URL, _ size: Int) -> NSString {
        "\(url.lastPathComponent)#\(size)" as NSString
    }
}

/// How a Want's picture is framed.
enum ArtworkStyle {
    /// Whole image visible (aspect fit) over a blurred copy of itself — the Display's "poster" look. For heroes.
    case poster
    /// Fills the frame, cropped around a focal point. Screenshots focus on their upper-middle where products sit.
    case fill
}

/// A Want's primary visual. Image-first: if there's a picture it dominates; if not, an intentional placeholder.
struct WantArtwork: View {
    let imageURL: URL?
    let title: String
    let sourceType: SourceType
    var style: ArtworkStyle = .fill
    var maxPixelSize: Int = 900

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                switch style {
                case .poster: poster(image)
                case .fill: FocalFillImage(image: image, focusY: sourceType == .screenshot ? 0.32 : 0.5)
                }
            } else if imageURL == nil {
                PlaceholderArt(title: title)
            } else {
                Theme.surface // loading
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .task(id: imageURL) {
            guard let imageURL else { image = nil; return }
            if let hit = ImageCache.shared.cached(imageURL, maxPixelSize: maxPixelSize) {
                image = hit
                return
            }
            image = await ImageCache.shared.image(at: imageURL, maxPixelSize: maxPixelSize)
        }
        .accessibilityHidden(true)
    }

    private func poster(_ image: UIImage) -> some View {
        ZStack {
            // The fill layer sits in an overlay so it can't size the ZStack: a scaledToFill child would grow the
            // artwork past the frame its parent gives it, covering (and taking taps from) the content below.
            Color.clear.overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .saturation(1.2)
                    .overlay(Color.black.opacity(0.45))
            }
            .clipped()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.5), radius: 24, y: 16)
                .padding(20)
        }
    }
}

/// Aspect-fill that keeps a vertical focal point in view instead of always centring.
struct FocalFillImage: View {
    let image: UIImage
    /// 0 = top, 0.5 = centre, 1 = bottom.
    let focusY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let imageSize = image.size
            let scale = max(size.width / max(imageSize.width, 1), size.height / max(imageSize.height, 1))
            let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let overflowY = drawn.height - size.height
            let offsetY = -min(max(overflowY * focusY, 0), overflowY)
            Image(uiImage: image)
                .resizable()
                .frame(width: drawn.width, height: drawn.height)
                .offset(x: (size.width - drawn.width) / 2, y: offsetY)
        }
    }
}

/// For Wants without a picture: a deep gradient (stable per title) and a large initial. Looks deliberate, not missing.
struct PlaceholderArt: View {
    let title: String

    var body: some View {
        let (top, bottom) = Theme.placeholderHues[Self.stableIndex(title, count: Theme.placeholderHues.count)]
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
            Text(Self.initial(title))
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(.white.opacity(0.22))
                .minimumScaleFactor(0.3)
                .padding(12)
        }
    }

    static func initial(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "★"
    }

    /// Swift's `hashValue` changes every launch; this doesn't.
    static func stableIndex(_ text: String, count: Int) -> Int {
        var hash: UInt64 = 5381
        for scalar in text.unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
        return Int(hash % UInt64(max(count, 1)))
    }
}
