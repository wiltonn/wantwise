import Foundation

/// A local notification WantWise wants to exist.
public struct PlannedReminder: Equatable, Sendable, Identifiable {
    public var id: String
    public var wantId: UUID
    public var fireAt: Date
    public var title: String
    public var body: String
}

/// A notification already pending in the system, as far as reconciliation needs to know.
public struct PendingReminder: Equatable, Sendable {
    public var id: String
    public var fireAt: Date?

    public init(id: String, fireAt: Date?) {
        self.id = id
        self.fireAt = fireAt
    }
}

public struct ReminderDiff: Equatable, Sendable {
    /// Add (or replace: the system replaces a pending request with the same identifier).
    public var toAdd: [PlannedReminder]
    public var toRemove: [String]

    public var isEmpty: Bool { toAdd.isEmpty && toRemove.isEmpty }
}

/// Decides which revisit reminders should exist. The app applies the result to UNUserNotificationCenter.
///
/// One reminder per waiting Want, identified by `want-<uuid>`, so re-planning never creates duplicates.
public enum ReminderPlanner {
    public static let identifierPrefix = "want-"
    /// iOS keeps at most 64 pending local notifications per app; leave headroom.
    public static let maxPending = 60

    public static func identifier(for wantId: UUID) -> String {
        identifierPrefix + wantId.uuidString
    }

    public static func wantId(fromIdentifier id: String) -> UUID? {
        guard id.hasPrefix(identifierPrefix) else { return nil }
        return UUID(uuidString: String(id.dropFirst(identifierPrefix.count)))
    }

    public static func plan(wants: [Want], now: Date, calendar: Calendar) -> [PlannedReminder] {
        wants
            .filter { !$0.isDeleted && $0.status == .waiting }
            .compactMap { want -> PlannedReminder? in
                guard let revisitAt = want.revisitAt, revisitAt > now else { return nil }
                let days = CalendarDays.between(want.createdAt, revisitAt, calendar: calendar)
                return PlannedReminder(
                    id: identifier(for: want.id),
                    wantId: want.id,
                    fireAt: revisitAt,
                    title: "Still thinking about this?",
                    body: "You added “\(want.displayTitle)” \(CalendarDays.durationText(days)) ago. Take another look."
                )
            }
            .sorted { $0.fireAt < $1.fireAt }
            .prefix(maxPending)
            .map { $0 }
    }

    /// Only touches identifiers WantWise owns (`want-` prefix). A planned reminder whose pending twin has the
    /// same fire time is left alone; anything else is (re)added.
    public static func diff(planned: [PlannedReminder], pending: [PendingReminder]) -> ReminderDiff {
        let ours = pending.filter { $0.id.hasPrefix(identifierPrefix) }
        let pendingById = Dictionary(ours.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let plannedIds = Set(planned.map(\.id))

        let toRemove = ours.map(\.id).filter { !plannedIds.contains($0) }.sorted()
        let toAdd = planned.filter { reminder in
            guard let existing = pendingById[reminder.id], let fireAt = existing.fireAt else { return true }
            // Calendar triggers carry whole seconds.
            return abs(fireAt.timeIntervalSince(reminder.fireAt)) >= 1
        }
        return ReminderDiff(toAdd: toAdd, toRemove: toRemove)
    }
}
