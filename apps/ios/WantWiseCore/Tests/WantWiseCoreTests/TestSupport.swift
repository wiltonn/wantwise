import Foundation
@testable import WantWiseCore

enum TestSupport {
    static let toronto = TimeZone(identifier: "America/Toronto")!

    static func calendar(_ timeZone: TimeZone = toronto) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date in test: \(iso)") }
        return date
    }

    static let childId = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!

    static func waitingWant(
        created: String = "2026-10-02T14:00:00-04:00",
        revisit: String = "2026-10-09T16:00:00-04:00",
        price: Int? = 4900
    ) -> Want {
        Want(
            childId: childId,
            title: "Wireless headphones",
            sourceType: .manual,
            priceMinor: price,
            currency: "CAD",
            reason: "Mine hurt my ears",
            status: .waiting,
            revisitAt: date(revisit),
            waitStartedAt: date(created),
            createdAt: date(created)
        )
    }

    /// docs/fixtures, found relative to this file so it works from any working directory (WSL or Mac).
    static func sharedFixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // WantWiseCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // WantWiseCore
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // apps
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("docs/fixtures/\(name)")
    }
}
