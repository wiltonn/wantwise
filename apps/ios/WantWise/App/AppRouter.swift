import Foundation
import Observation

enum AppTab: Hashable {
    case thinking
    case decided
}

/// Navigation value for a Want's detail screen.
struct WantRoute: Hashable {
    let id: UUID
}

/// Tab selection and navigation paths, so notifications (and later deep links) can open a specific Want.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .thinking
    var thinkingPath: [WantRoute] = []
    var decidedPath: [WantRoute] = []
    /// Set when a reminder is tapped; the Thinking tab opens the reconsider screen for it.
    var reconsiderWantId: UUID?

    func openWant(_ id: UUID) {
        tab = .thinking
        thinkingPath = [WantRoute(id: id)]
        reconsiderWantId = id
    }
}
