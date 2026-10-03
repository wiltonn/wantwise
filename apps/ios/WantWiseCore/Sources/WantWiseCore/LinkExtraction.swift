import Foundation

/// Finds web links in shared text (CAPTURE.md → Shared text). No AI, no `NSDataDetector` (not implemented in
/// swift-corelibs-foundation): a whitespace token scan, trailing-punctuation trim and `URL(string:)` with a scheme check.
public enum LinkExtraction {
    /// The first `http`/`https` link in `text`, or nil.
    public static func firstWebLink(in text: String) -> URL? {
        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            if let url = webLink(in: Substring(token)) { return url }
        }
        return nil
    }

    /// Characters that end a sentence or wrap a link rather than belong to it.
    private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", ">", "\"", "'", "»", "”", "’"]

    private static func webLink(in token: Substring) -> URL? {
        // The link may start mid-token, e.g. "(https://…)" or "here:https://…".
        let lower = token.lowercased()
        guard let range = lower.range(of: "https://") ?? lower.range(of: "http://") else { return nil }
        let offset = lower.distance(from: lower.startIndex, to: range.lowerBound)
        var candidate = token.dropFirst(offset)

        while let last = candidate.last, trailingPunctuation.contains(last) {
            // Keep a closing parenthesis that belongs to the link, e.g. Wikipedia's "Lego_(company)".
            if last == ")" && candidate.filter({ $0 == "(" }).count >= candidate.filter({ $0 == ")" }).count { break }
            candidate = candidate.dropLast()
        }

        guard let url = URL(string: String(candidate)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
