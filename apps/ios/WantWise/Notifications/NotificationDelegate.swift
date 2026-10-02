import Foundation
import UserNotifications
import WantWiseCore

/// Shows reminders while the app is open, and opens the Want when a reminder is tapped.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        let fromInfo = (request.content.userInfo[SystemNotificationCenter.wantIdKey] as? String).flatMap(UUID.init(uuidString:))
        guard let wantId = ReminderPlanner.wantId(fromIdentifier: request.identifier) ?? fromInfo else { return }
        await MainActor.run { router.openWant(wantId) }
    }
}
