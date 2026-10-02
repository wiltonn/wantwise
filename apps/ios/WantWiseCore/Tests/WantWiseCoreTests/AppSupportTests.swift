import Foundation
import Testing
@testable import WantWiseCore

private func tempDirectory() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wantwise-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("Editing, visibility and soft delete")
struct EditTests {
    let now = TestSupport.date("2026-10-03T10:00:00-04:00")

    @Test func editUpdatesFieldsAndTimestamp() throws {
        let want = TestSupport.waitingWant()
        var edit = WantEdit(want)
        edit.title = " Studio headphones "
        edit.price = Money(minorUnits: 5999, currency: "CAD")
        edit.reason = "  "
        edit.similarItemAnswer = .yes
        let updated = try want.updating(edit, now: now)
        #expect(updated.title == "Studio headphones")
        #expect(updated.priceMinor == 5999)
        #expect(updated.reason == nil)
        #expect(updated.similarItemAnswer == .yes)
        #expect(updated.updatedAt == now)
        #expect(updated.status == want.status)
        #expect(updated.revisitAt == want.revisitAt)
    }

    @Test func editCannotMakeWantUnrecognisable() {
        let want = TestSupport.waitingWant()
        var edit = WantEdit(want)
        edit.title = ""
        #expect(throws: WantDraft.Problem.nothingToRecognise) { try want.updating(edit, now: now) }
        // ...unless it has a picture.
        let withImage = want.withImage("a.jpg", now: now)
        #expect((try? withImage.updating(edit, now: now)) != nil)
    }

    @Test func removingPriceKeepsCurrency() throws {
        var edit = WantEdit(TestSupport.waitingWant())
        edit.price = nil
        let updated = try TestSupport.waitingWant().updating(edit, now: now)
        #expect(updated.priceMinor == nil)
        #expect(updated.currency == "CAD")
    }

    @Test func softDeleteAndRestore() {
        let want = TestSupport.waitingWant()
        let deleted = want.softDeleting(now: now)
        #expect(deleted.isDeleted)
        #expect(deleted.deletedAt == now)
        #expect(WantSections([deleted], now: now).isEmpty)
        #expect(ReminderPlanner.plan(wants: [deleted], now: now, calendar: TestSupport.calendar()).isEmpty)
        #expect(!deleted.restoring(now: now).isDeleted)
    }

    @Test func displayVisibility() {
        let hidden = TestSupport.waitingWant().settingVisibleOnDisplay(false, now: now)
        #expect(!hidden.isVisibleOnDisplay)
        #expect(hidden.updatedAt == now)
    }

    @Test func thinkingDays() throws {
        let decided = try TestSupport.waitingWant().deciding(.noLongerWant, now: TestSupport.date("2026-10-11T09:00:00-04:00")).want
        #expect(decided.thinkingDays(calendar: TestSupport.calendar()) == 9)
        #expect(TestSupport.waitingWant().thinkingDays(calendar: TestSupport.calendar()) == nil)
    }
}

@Suite("Wait choices")
struct WaitChoiceTests {
    @Test func presetsAndLabels() {
        #expect(WaitChoice.presets() == [.days(3), .days(7), .days(30)])
        #expect(WaitChoice.recommended() == .days(7))
        #expect(WaitChoice.days(1).presetLabel == "1 day")
        #expect(WaitChoice.days(30).presetLabel == "30 days")
        #expect(WaitChoice.custom(.now).presetLabel == nil)
    }

    @Test func revisitDates() {
        let calendar = TestSupport.calendar()
        let now = TestSupport.date("2026-10-02T21:00:00-04:00")
        #expect(WaitChoice.days(3).revisitDate(from: now, calendar: calendar) == TestSupport.date("2026-10-05T16:00:00-04:00"))
        let custom = WaitChoice.custom(TestSupport.date("2026-10-20T08:00:00-04:00"))
        #expect(custom.revisitDate(from: now, calendar: calendar) == TestSupport.date("2026-10-20T16:00:00-04:00"))
    }
}

@Suite("Reminder planning")
struct ReminderPlannerTests {
    let calendar = TestSupport.calendar()
    let now = TestSupport.date("2026-10-03T10:00:00-04:00")

    @Test func oneReminderPerFutureWaitingWant() throws {
        let a = TestSupport.waitingWant(revisit: "2026-10-09T16:00:00-04:00")
        let past = TestSupport.waitingWant(revisit: "2026-10-02T16:00:00-04:00")
        let decided = try TestSupport.waitingWant().deciding(.stillWant, now: now).want
        let planned = ReminderPlanner.plan(wants: [a, past, decided], now: now, calendar: calendar)
        #expect(planned.map(\.wantId) == [a.id])
        #expect(planned[0].id == "want-\(a.id.uuidString)")
        #expect(planned[0].fireAt == a.revisitAt)
        #expect(planned[0].title == "Still thinking about this?")
        #expect(planned[0].body == "You added “Wireless headphones” 7 days ago. Take another look.")
    }

    @Test func soonestFirstAndCapped() {
        let wants = (0..<70).map { i in
            TestSupport.waitingWant(revisit: "2026-10-09T16:00:00-04:00").withRevisit(daysLater: 69 - i)
        }
        let planned = ReminderPlanner.plan(wants: wants, now: now, calendar: calendar)
        #expect(planned.count == ReminderPlanner.maxPending)
        #expect(planned.map(\.fireAt) == planned.map(\.fireAt).sorted())
    }

    @Test func identifierRoundTrip() {
        let id = UUID()
        #expect(ReminderPlanner.wantId(fromIdentifier: ReminderPlanner.identifier(for: id)) == id)
        #expect(ReminderPlanner.wantId(fromIdentifier: "other-\(id)") == nil)
    }

    @Test func diffAddsMissingRemovesObsoleteAndLeavesUnchanged() {
        let a = TestSupport.waitingWant(revisit: "2026-10-09T16:00:00-04:00")
        let b = TestSupport.waitingWant(revisit: "2026-10-12T16:00:00-04:00")
        let c = TestSupport.waitingWant(revisit: "2026-10-15T16:00:00-04:00")
        let planned = ReminderPlanner.plan(wants: [a, b, c], now: now, calendar: calendar)
        let pending = [
            PendingReminder(id: ReminderPlanner.identifier(for: a.id), fireAt: a.revisitAt),                       // unchanged
            PendingReminder(id: ReminderPlanner.identifier(for: b.id), fireAt: TestSupport.date("2026-10-10T16:00:00-04:00")), // moved
            PendingReminder(id: ReminderPlanner.identifier(for: UUID()), fireAt: now),                              // obsolete
            PendingReminder(id: "someone-else", fireAt: now),                                                       // not ours
        ]
        let diff = ReminderPlanner.diff(planned: planned, pending: pending)
        #expect(Set(diff.toAdd.map(\.wantId)) == [b.id, c.id])
        #expect(diff.toRemove == [pending[2].id])
    }

    @Test func diffIsEmptyWhenInSync() {
        let a = TestSupport.waitingWant()
        let planned = ReminderPlanner.plan(wants: [a], now: now, calendar: calendar)
        let pending = planned.map { PendingReminder(id: $0.id, fireAt: $0.fireAt) }
        #expect(ReminderPlanner.diff(planned: planned, pending: pending).isEmpty)
    }
}

@Suite("Image file store")
struct ImageFileStoreTests {
    @Test func saveEncodesAndNamesFilesPerWant() throws {
        let store = ImageFileStore(directory: tempDirectory().appendingPathComponent("Images")) { Data($0.reversed()) }
        let wantId = UUID()
        let name = try store.save(Data([1, 2, 3]), for: wantId)
        #expect(name.hasPrefix(wantId.uuidString.lowercased() + "-"))
        #expect(name.hasSuffix(".jpg"))
        #expect(try Data(contentsOf: store.url(for: name)) == Data([3, 2, 1]))
        #expect(store.exists(name))
    }

    @Test func replacingAnImageUsesANewName() throws {
        let store = ImageFileStore(directory: tempDirectory())
        let id = UUID()
        let first = try store.save(Data([1]), for: id)
        let second = try store.save(Data([2]), for: id)
        #expect(first != second)
        try store.delete(first)
        #expect(!store.exists(first))
        #expect(store.exists(second))
        try store.delete(first) // missing file is fine
    }

    @Test func rejectsPathTraversal() {
        let store = ImageFileStore(directory: tempDirectory())
        #expect(throws: ImageFileStore.StoreError.invalidFilename("../secret")) { try store.url(for: "../secret") }
        #expect(!store.exists(".hidden"))
    }

    @Test func orphans() throws {
        let store = ImageFileStore(directory: tempDirectory())
        let keep = try store.save(Data([1]), for: UUID())
        let orphan = try store.save(Data([2]), for: UUID())
        #expect(store.orphans(referenced: [keep]) == [orphan])
    }
}

@Suite("Capture inbox and import")
struct CaptureInboxTests {
    let createdAt = TestSupport.date("2026-10-02T14:00:00-04:00")

    @Test func writeThenReadPending() throws {
        let inbox = CaptureInbox(appGroupContainer: tempDirectory())
        let capture = CapturedWant(sourceType: .screenshot, reason: "Looks fun", createdAt: createdAt)
        let written = try inbox.write(capture, imageData: Data([9, 9]))
        #expect(written.imageFilename == "\(capture.id.uuidString.lowercased()).jpg")
        let (items, unreadable) = inbox.pending()
        #expect(unreadable.isEmpty)
        #expect(items.count == 1)
        #expect(items[0].capture == written)
        #expect(try Data(contentsOf: items[0].imageURL!) == Data([9, 9]))
    }

    @Test func imageWithoutRecordIsNotPending() throws {
        let dir = tempDirectory()
        try Data([1]).write(to: dir.appendingPathComponent("orphan.jpg"))
        #expect(CaptureInbox(directory: dir).pending().items.isEmpty)
    }

    @Test func corruptRecordIsReportedNotFatal() throws {
        let inbox = CaptureInbox(directory: tempDirectory())
        try inbox.write(CapturedWant(sourceType: .sharedURL, productURL: "https://example.com", createdAt: createdAt), imageData: nil)
        try Data("{nope".utf8).write(to: inbox.directory.appendingPathComponent("bad.json"))
        let (items, unreadable) = inbox.pending()
        #expect(items.count == 1)
        #expect(unreadable.count == 1)
    }

    @Test func importMovesImageCreatesWantAndCleansUp() throws {
        let root = tempDirectory()
        let inbox = CaptureInbox(appGroupContainer: root)
        let images = ImageFileStore(directory: root.appendingPathComponent("Images"))
        let capture = CapturedWant(
            sourceType: .screenshot,
            reason: "I love this design",
            revisitAt: TestSupport.date("2026-10-09T16:00:00-04:00"),
            createdAt: createdAt
        )
        try inbox.write(capture, imageData: Data([7]))

        var stored: [Want] = []
        let report = CaptureImporter.importAll(
            from: inbox, images: images, childId: TestSupport.childId, defaultCurrency: "CAD",
            exists: { id in stored.contains { $0.id == id } },
            insert: { stored.append($0) }
        )
        #expect(report.imported == [capture.id])
        #expect(stored.count == 1)
        let want = stored[0]
        #expect(want.id == capture.id)
        #expect(want.sourceType == .screenshot)
        #expect(want.status == .waiting)
        #expect(want.createdAt == createdAt)
        let filename = try #require(want.imageFilename)
        #expect(try Data(contentsOf: images.url(for: filename)) == Data([7]))
        #expect(inbox.pending().items.isEmpty)

        // Importing again is a no-op.
        let again = CaptureImporter.importAll(
            from: inbox, images: images, childId: TestSupport.childId, defaultCurrency: "CAD",
            exists: { id in stored.contains { $0.id == id } }, insert: { stored.append($0) }
        )
        #expect(again == CaptureImporter.Report())
        #expect(stored.count == 1)
    }

    @Test func alreadyImportedItemIsCleanedNotDuplicated() throws {
        let root = tempDirectory()
        let inbox = CaptureInbox(appGroupContainer: root)
        let capture = try inbox.write(CapturedWant(sourceType: .screenshot, createdAt: createdAt), imageData: Data([1]))
        let report = CaptureImporter.importAll(
            from: inbox, images: ImageFileStore(directory: root.appendingPathComponent("Images")),
            childId: TestSupport.childId, defaultCurrency: "CAD",
            exists: { _ in true }, insert: { _ in Issue.record("should not insert") }
        )
        #expect(report.skippedExisting == [capture.id])
        #expect(inbox.pending().items.isEmpty)
    }

    @Test func failedInsertKeepsInboxItemAndImageForRetry() throws {
        struct Boom: Error {}
        let root = tempDirectory()
        let inbox = CaptureInbox(appGroupContainer: root)
        let images = ImageFileStore(directory: root.appendingPathComponent("Images"))
        let capture = try inbox.write(CapturedWant(sourceType: .screenshot, createdAt: createdAt), imageData: Data([5]))
        let report = CaptureImporter.importAll(
            from: inbox, images: images, childId: TestSupport.childId, defaultCurrency: "CAD",
            exists: { _ in false }, insert: { _ in throw Boom() }
        )
        #expect(report.failed == [capture.id])
        let pending = inbox.pending().items
        #expect(pending.count == 1)
        #expect(try Data(contentsOf: pending[0].imageURL!) == Data([5]))
        #expect(images.orphans(referenced: []).isEmpty)
    }
}

@Suite("Decision wording and timeline")
struct DecisionCopyTests {
    @Test func everyOutcomeIsFramedAsThoughtful() {
        for kind in DecisionKind.allCases {
            #expect(!DecisionCopy.actionLabel(kind).isEmpty)
            #expect(!DecisionCopy.confirmationTitle(kind).isEmpty)
            let message = DecisionCopy.confirmationMessage(kind).lowercased()
            for word in ["good job", "great job", "resist", "win", "better", "should"] {
                #expect(!message.contains(word), "\(kind): \(word)")
            }
        }
        #expect(DecisionCopy.actionLabel(.noLongerWant) == "I don't need it anymore")
    }

    @Test func timelineIsChronological() throws {
        let want = TestSupport.waitingWant()
        let t1 = TestSupport.date("2026-10-09T17:00:00-04:00")
        let t2 = TestSupport.date("2026-10-16T17:00:00-04:00")
        let wait = try want.deciding(.waitLonger, newRevisitAt: TestSupport.date("2026-10-16T16:00:00-04:00"), now: t1)
        let still = try wait.want.deciding(.stillWant, note: "Yes!", now: t2)
        let entries = TimelineEntry.entries(for: want, decisions: [still.decision, wait.decision])
        #expect(entries.map(\.kind) == [.added, .decision(.waitLonger), .decision(.stillWant)])
        #expect(entries[1].newRevisitAt == TestSupport.date("2026-10-16T16:00:00-04:00"))
        #expect(entries[2].note == "Yes!")
    }
}

private extension Want {
    func withRevisit(daysLater: Int) -> Want {
        var want = self
        want.id = UUID()
        want.revisitAt = revisitAt!.addingTimeInterval(Double(daysLater) * 86_400)
        return want
    }
}

@Suite("Source type inference")
struct SourceTypeInferenceTests {
    @Test(arguments: [
        (1170, 2532, SourceType.screenshot), // iPhone 13–15 screenshot
        (1290, 2796, .screenshot),            // Pro Max
        (750, 1334, .photo),                  // iPhone SE screenshot (16:9) — indistinguishable from a photo; acceptable
        (4032, 3024, .photo),                 // landscape photo
        (3024, 4032, .photo),                 // portrait photo
        (0, 0, .photo),
    ])
    func infers(width: Int, height: Int, expected: SourceType) {
        #expect(SourceType.inferredForLibraryImage(width: width, height: height) == expected)
    }
}
