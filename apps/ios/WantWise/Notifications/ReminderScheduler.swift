import Foundation
import UserNotifications
import WantWiseCore

/// What WantStore needs from reminders. Faked in tests.
@MainActor
protocol ReminderScheduling: AnyObject {
    func sync(wants: [Want], now: Date, calendar: Calendar) async
    func requestPermissionIfNeeded() async
    func clearDelivered(for wantId: UUID)
}

/// The slice of UNUserNotificationCenter WantWise uses. Faked in tests.
protocol NotificationCentering: AnyObject {
    func pendingReminders() async -> [PendingReminder]
    func add(_ reminder: PlannedReminder, calendar: Calendar) async throws
    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
}

/// Local revisit reminders only; no remote push (D-016).
///
/// Planning (which reminders should exist) is pure logic in WantWiseCore's ReminderPlanner and is tested on Linux.
/// This class only applies the plan. Identifiers are `want-<uuid>`, so re-syncing never duplicates.
@MainActor
final class ReminderScheduler: ReminderScheduling {
    let center: NotificationCentering
    /// UI tests and previews turn this off so the permission alert never appears.
    var isEnabled: Bool

    init(center: NotificationCentering, isEnabled: Bool = true) {
        self.center = center
        self.isEnabled = isEnabled
    }

    func sync(wants: [Want], now: Date, calendar: Calendar) async {
        guard isEnabled else { return }
        let planned = ReminderPlanner.plan(wants: wants, now: now, calendar: calendar)
        let pending = await center.pendingReminders()
        let diff = ReminderPlanner.diff(planned: planned, pending: pending)
        if !diff.toRemove.isEmpty { center.removePending(identifiers: diff.toRemove) }
        for reminder in diff.toAdd {
            // Adding with an existing identifier replaces the pending request.
            try? await center.add(reminder, calendar: calendar)
        }
    }

    /// Asked in context (when the first waiting Want is saved), not at launch.
    func requestPermissionIfNeeded() async {
        guard isEnabled else { return }
        if await center.authorizationStatus() == .notDetermined {
            _ = await center.requestAuthorization()
        }
    }

    func clearDelivered(for wantId: UUID) {
        center.removeDelivered(identifiers: [ReminderPlanner.identifier(for: wantId)])
    }
}

/// The real notification center.
final class SystemNotificationCenter: NotificationCentering {
    private let center = UNUserNotificationCenter.current()
    static let fireAtKey = "fireAt"
    static let wantIdKey = "wantId"

    func pendingReminders() async -> [PendingReminder] {
        let requests = await center.pendingNotificationRequests()
        return requests.map { request in
            let stored = (request.content.userInfo[Self.fireAtKey] as? Double).map(Date.init(timeIntervalSince1970:))
            let fromTrigger = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            return PendingReminder(id: request.identifier, fireAt: stored ?? fromTrigger)
        }
    }

    func add(_ reminder: PlannedReminder, calendar: Calendar) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = [
            Self.wantIdKey: reminder.wantId.uuidString,
            Self.fireAtKey: reminder.fireAt.timeIntervalSince1970,
        ]
        // Calendar trigger: fires at the local wall-clock time, even if the device changes time zone.
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }

    func removePending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
