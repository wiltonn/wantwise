import Foundation
import SwiftData
import UIKit
import UserNotifications
import WantWiseCore
@testable import WantWise

/// A clock tests can move.
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(days: Int) { now = now.addingTimeInterval(Double(days) * 86_400) }
}

/// In-memory stand-in for UNUserNotificationCenter.
final class FakeNotificationCenter: NotificationCentering {
    var pending: [String: PlannedReminder] = [:]
    var addCount = 0
    var removedDelivered: [String] = []
    var status: UNAuthorizationStatus = .notDetermined
    var authorizationRequests = 0

    func pendingReminders() async -> [PendingReminder] {
        pending.values.map { PendingReminder(id: $0.id, fireAt: $0.fireAt) }
    }

    func add(_ reminder: PlannedReminder, calendar: Calendar) async throws {
        addCount += 1
        pending[reminder.id] = reminder // same identifier replaces, like the real center
    }

    func removePending(identifiers: [String]) {
        identifiers.forEach { pending[$0] = nil }
    }

    func removeDelivered(identifiers: [String]) {
        removedDelivered += identifiers
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        status = .authorized
        return true
    }
}

@MainActor
struct StoreHarness {
    let container: ModelContainer
    let store: WantStore
    let clock: TestClock
    let center: FakeNotificationCenter
    let scheduler: ReminderScheduler
    let directory: URL

    static func toronto() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    /// - Parameter storeURL: nil = in-memory; pass a file URL to test persistence across "relaunches".
    static func make(storeURL: URL? = nil, directory: URL? = nil, now: Date = ISO8601DateFormatter().date(from: "2026-10-02T14:00:00-04:00")!) throws -> StoreHarness {
        let directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("wantwise-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try Persistence.makeContainer(url: storeURL)
        let clock = TestClock(now)
        let center = FakeNotificationCenter()
        let scheduler = ReminderScheduler(center: center)
        let store = WantStore(
            context: container.mainContext,
            images: ImageFileStore(directory: directory.appendingPathComponent("Images"), encode: ImageEncoding.downsampledJPEG),
            reminders: scheduler,
            clock: { clock.now },
            calendar: toronto()
        )
        return StoreHarness(container: container, store: store, clock: clock, center: center, scheduler: scheduler, directory: directory)
    }

    /// WantStore applies reminder changes in queued Tasks; wait for them before asserting.
    func settleReminders() async throws {
        await store.waitForReminderSync()
    }
}

/// A small real PNG (ImageIO must be able to decode it).
func makePNG(width: Int, height: Int) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return format
    }())
    return renderer.pngData { context in
        UIColor.orange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}
