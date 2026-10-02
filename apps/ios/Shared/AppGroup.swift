import Foundation

/// The App Group shared by the app and the Share Extension. Holds only the capture inbox (D-019).
///
/// The identifier comes from Info.plist (`WantWiseAppGroup`, set from the WANTWISE_APP_GROUP build setting), so
/// nothing in code depends on the placeholder identifier (D-022).
enum AppGroup {
    static var identifier: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "WantWiseAppGroup") as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    /// Nil when the entitlement isn't present (e.g. an unsigned build). Callers must cope: the main app works
    /// fully without it; only Share Extension capture needs it.
    static var containerURL: URL? {
        guard let identifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
