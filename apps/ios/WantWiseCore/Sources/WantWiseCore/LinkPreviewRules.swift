import Foundation

/// When and how a fetched link preview may change a Want (CAPTURE.md → Shared URL). The app does the fetching.
extension Want {
    /// A shared link with no picture yet: worth fetching a preview for. Never for manual Wants or deleted ones.
    public var wantsLinkPreview: Bool {
        guard imageFilename == nil, !isDeleted, sourceType == .sharedURL || sourceType == .sharedText else { return false }
        return webLink != nil
    }

    /// The title is empty or just the link's host ("amazon.ca", "www.amazon.ca"), i.e. not something the child typed.
    public var hasPlaceholderTitle: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return true }
        guard let host = webLink?.host?.lowercased() else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return trimmed == host || trimmed == bare
    }

    /// Applies a preview: the page title replaces only a placeholder title; the image is used only if there is none.
    public func applyingLinkPreview(title pageTitle: String?, imageFilename newImage: String?, now: Date) -> Want {
        var want = self
        var changed = false
        if hasPlaceholderTitle, let pageTitle = pageTitle.nilIfBlank {
            want.title = pageTitle.count > 80 ? String(pageTitle.prefix(79)) + "…" : pageTitle
            changed = true
        }
        if want.imageFilename == nil, let newImage {
            want.imageFilename = newImage
            changed = true
        }
        if changed { want.updatedAt = now }
        return want
    }

    private var webLink: URL? {
        guard let url = productURL.flatMap(URL.init(string:)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else { return nil }
        return url
    }
}
