import Foundation
import SwiftData
import Testing
import WantWiseCore
@testable import WantWise

@MainActor
@Suite("WantStore (SwiftData, in-memory)")
struct WantStoreTests {
    @Test func createsWaitingWantWithChildAndCurrency() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(
            title: "Wireless headphones",
            price: Money(minorUnits: 4900, currency: "CAD"),
            reason: "Mine hurt my ears",
            similarItemAnswer: .yes,
            revisitAt: h.store.revisitDate(for: .days(7))
        ))
        let want = entity.snapshot
        #expect(want.status == .waiting)
        #expect(want.currency == "CAD")
        #expect(want.childId == (try h.store.currentChild()).id)
        #expect(entity.needsUpload)
        #expect(try h.store.liveWants().count == 1)
    }

    @Test func firstLaunchCreatesExactlyOneChild() throws {
        let h = try StoreHarness.make()
        let a = try h.store.currentChild()
        let b = try h.store.currentChild()
        #expect(a.id == b.id)
        #expect(a.defaultCurrency == "CAD")
        #expect(try h.container.mainContext.fetch(FetchDescriptor<ChildProfileEntity>()).count == 1)
        #expect(try h.container.mainContext.fetch(FetchDescriptor<FamilyEntity>()).count == 1)
    }

    @Test func decisionsAppendHistory() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Art set", revisitAt: h.store.revisitDate(for: .days(3))))
        h.clock.advance(days: 4)
        try h.store.waitLonger(entity, wait: .days(7))
        #expect(entity.snapshot.status == .waiting)
        h.clock.advance(days: 8)
        try h.store.stillWant(entity, note: "Still yes")
        h.clock.advance(days: 2)
        try h.store.markPurchased(entity)

        let history = entity.decisionHistory
        #expect(history.map(\.kind) == [.waitLonger, .stillWant, .purchased])
        #expect(history.allSatisfy { $0.wantId == entity.id })
        #expect(entity.snapshot.status == .purchased)
        #expect(try h.container.mainContext.fetch(FetchDescriptor<WantDecisionEntity>()).count == 3)
    }

    @Test func noLongerWanted() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Sneakers", revisitAt: h.store.revisitDate(for: .days(3))))
        try h.store.markNoLongerWanted(entity)
        #expect(entity.snapshot.status == .noLongerWant)
        #expect(entity.decidedAt == h.clock.now)
    }

    @Test func invalidDecisionThrowsAndChangesNothing() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Game", revisitAt: h.store.revisitDate(for: .days(3))))
        #expect(throws: TransitionError.self) { try h.store.markPurchased(entity) }
        #expect(entity.snapshot.status == .waiting)
        #expect(entity.decisionHistory.isEmpty)
    }

    @Test func updateEditsFields() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Headphones", revisitAt: h.store.revisitDate(for: .days(3))))
        var edit = WantEdit(entity.snapshot)
        edit.title = "Studio headphones"
        edit.price = Money(minorUnits: 5999, currency: "CAD")
        h.clock.advance(days: 1)
        try h.store.update(entity, with: edit)
        #expect(entity.title == "Studio headphones")
        #expect(entity.priceMinor == 5999)
        #expect(entity.updatedAt == h.clock.now)
    }

    @Test func softDeleteHidesButKeepsRecord() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Gone", revisitAt: h.store.revisitDate(for: .days(3))))
        try h.store.softDelete(entity)
        #expect(try h.store.liveWants().isEmpty)
        #expect(try h.store.want(id: entity.id)?.deletedAt != nil)
        try h.store.restore(entity)
        #expect(try h.store.liveWants().count == 1)
    }

    @Test func displayVisibility() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Secret gift", revisitAt: h.store.revisitDate(for: .days(3))))
        try h.store.setVisibleOnDisplay(false, for: entity)
        #expect(entity.isVisibleOnDisplay == false)
    }

    @Test func finishReflectionMovesCapturedToWaiting() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Quick capture"))
        #expect(entity.snapshot.status == .captured)
        try h.store.finishReflection(entity, reason: "Looks fun", similarItemAnswer: .no, wait: .days(3))
        #expect(entity.snapshot.status == .waiting)
        #expect(entity.reason == "Looks fun")
    }

    @Test func sectionsGroupForTheHomeScreen() throws {
        let h = try StoreHarness.make()
        try h.store.create(WantDraft(title: "Waiting", revisitAt: h.store.revisitDate(for: .days(7))))
        try h.store.create(WantDraft(title: "Captured"))
        let decided = try h.store.create(WantDraft(title: "Decided", revisitAt: h.store.revisitDate(for: .days(3))))
        try h.store.markNoLongerWanted(decided)
        let sections = try h.store.sections()
        #expect(sections.waiting.map(\.title) == ["Waiting"])
        #expect(sections.needsReflection.map(\.title) == ["Captured"])
        #expect(sections.decided.map(\.title) == ["Decided"])
    }
}

@MainActor
@Suite("Images")
struct ImageTests {
    @Test func createWithImageStoresDownsampledFile() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(
            WantDraft(title: "Tall screenshot", sourceType: .screenshot, revisitAt: h.store.revisitDate(for: .days(7))),
            imageData: makePNG(width: 1170, height: 2532)
        )
        let url = try #require(h.store.imageURL(for: entity))
        let size = try #require(ImageEncoding.pixelSize(of: Data(contentsOf: url)))
        #expect(max(size.width, size.height) <= ImageEncoding.maxPixelSize)
        #expect(size.height > size.width)
    }

    @Test func replacingImageDeletesOldFile() throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Photo", revisitAt: h.store.revisitDate(for: .days(7))), imageData: makePNG(width: 400, height: 300))
        let oldURL = try #require(h.store.imageURL(for: entity))
        try h.store.setImage(makePNG(width: 300, height: 400), for: entity)
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        #expect(h.store.imageURL(for: entity) != nil)
        try h.store.setImage(nil, for: entity)
        #expect(entity.imageFilename == nil)
    }

    @Test func downsamplesLargeImages() throws {
        let jpeg = try ImageEncoding.downsampledJPEG(makePNG(width: 4000, height: 3000))
        let size = try #require(ImageEncoding.pixelSize(of: jpeg))
        #expect(size.width == 2048)
        #expect(size.height == 1536)
    }

    @Test func unreadableImageIsRejectedAndNothingSaved() throws {
        let h = try StoreHarness.make()
        #expect(throws: (any Error).self) {
            try h.store.create(WantDraft(title: "Bad"), imageData: Data("not an image".utf8))
        }
        #expect(try h.store.liveWants().isEmpty)
    }
}

@MainActor
@Suite("Reminders")
struct ReminderTests {
    @Test func oneReminderPerWaitingWantAndNoDuplicates() async throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Headphones", revisitAt: h.store.revisitDate(for: .days(7))))
        try await h.settleReminders()
        h.store.syncReminders()
        h.store.syncReminders()
        try await h.settleReminders()
        #expect(h.center.pending.count == 1)
        #expect(h.center.pending[ReminderPlanner.identifier(for: entity.id)]?.fireAt == entity.revisitAt)
        #expect(h.center.addCount == 1)
    }

    @Test func waitLongerMovesReminderAndDecisionRemovesIt() async throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Game", revisitAt: h.store.revisitDate(for: .days(3))))
        try await h.settleReminders()
        h.clock.advance(days: 4)
        try h.store.waitLonger(entity, wait: .days(7))
        try await h.settleReminders()
        #expect(h.center.pending[ReminderPlanner.identifier(for: entity.id)]?.fireAt == entity.revisitAt)

        try h.store.markNoLongerWanted(entity)
        try await h.settleReminders()
        #expect(h.center.pending.isEmpty)
        #expect(h.center.removedDelivered.contains(ReminderPlanner.identifier(for: entity.id)))
    }

    @Test func softDeleteRemovesReminder() async throws {
        let h = try StoreHarness.make()
        let entity = try h.store.create(WantDraft(title: "Gone", revisitAt: h.store.revisitDate(for: .days(3))))
        try await h.settleReminders()
        try h.store.softDelete(entity)
        try await h.settleReminders()
        #expect(h.center.pending.isEmpty)
    }

    @Test func permissionRequestedOnlyWhenUndetermined() async throws {
        let h = try StoreHarness.make()
        await h.scheduler.requestPermissionIfNeeded()
        await h.scheduler.requestPermissionIfNeeded()
        #expect(h.center.authorizationRequests == 1)
    }
}

@MainActor
@Suite("Persistence across relaunch")
struct PersistenceTests {
    @Test func wantsAndHistorySurviveReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("wantwise-relaunch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("WantWise.store")

        var wantId: UUID?
        do {
            let first = try StoreHarness.make(storeURL: storeURL, directory: directory)
            let entity = try first.store.create(
                WantDraft(title: "Survives", revisitAt: first.store.revisitDate(for: .days(3))),
                imageData: makePNG(width: 300, height: 600)
            )
            try first.store.waitLonger(entity, wait: .days(7))
            wantId = entity.id
        }

        let second = try StoreHarness.make(storeURL: storeURL, directory: directory)
        let id = try #require(wantId)
        let reopened = try #require(try second.store.want(id: id))
        #expect(reopened.title == "Survives")
        #expect(reopened.decisionHistory.map(\.kind) == [.waitLonger])
        #expect(second.store.imageURL(for: reopened) != nil)
    }
}

@MainActor
@Suite("Capture import into SwiftData")
struct CaptureImportTests {
    @Test func importsInboxScreenshotAsPrimaryImageOnce() throws {
        let h = try StoreHarness.make()
        let inbox = CaptureInbox(appGroupContainer: h.directory.appendingPathComponent("Group"))
        let capture = CapturedWant(
            sourceType: .screenshot,
            reason: "I love this design",
            revisitAt: h.store.revisitDate(for: .days(3)),
            createdAt: h.clock.now
        )
        try inbox.write(capture, imageData: ImageEncoding.downsampledJPEG(makePNG(width: 1170, height: 2532)))

        let report = h.store.importCapturedWants(from: inbox)
        #expect(report.imported == [capture.id])
        let entity = try #require(try h.store.want(id: capture.id))
        #expect(entity.snapshot.sourceType == .screenshot)
        #expect(h.store.imageURL(for: entity) != nil)

        #expect(h.store.importCapturedWants(from: inbox).imported.isEmpty)
        #expect(try h.store.liveWants().count == 1)
    }
}

@MainActor
@Suite("Link previews on import")
struct LinkPreviewImportTests {
    private func importShared(_ h: StoreHarness, title: String? = nil, url: String = "https://www.amazon.ca/dp/B0X",
                              source: SourceType = .sharedURL, text: String? = nil, image: Data? = nil) throws -> UUID {
        let inbox = CaptureInbox(appGroupContainer: h.directory.appendingPathComponent("Group"))
        let capture = CapturedWant(
            sourceType: source,
            title: title,
            productURL: source == .sharedURL ? url : nil,
            sharedText: text,
            createdAt: h.clock.now
        )
        try inbox.write(capture, imageData: image)
        #expect(h.store.importCapturedWants(from: inbox).imported == [capture.id])
        return capture.id
    }

    @Test func hostTitleIsReplacedAndImageSavedDownsampled() async throws {
        let fake = FakeLinkPreviews(.succeed(LinkPreview(title: "Razor A5 Scooter", imageData: makePNG(width: 3000, height: 1500))))
        let h = try StoreHarness.make(linkPreviews: fake)
        let id = try importShared(h, title: "www.amazon.ca")
        await h.store.waitForLinkPreviews()

        let entity = try #require(try h.store.want(id: id))
        #expect(fake.requested.map(\.absoluteString) == ["https://www.amazon.ca/dp/B0X"])
        #expect(entity.title == "Razor A5 Scooter")
        let url = try #require(h.store.imageURL(for: entity))
        let size = try #require(ImageEncoding.pixelSize(of: Data(contentsOf: url)))
        #expect(max(size.width, size.height) == ImageEncoding.maxPixelSize)
        #expect(url.pathExtension == "jpg")
    }

    @Test func typedTitleIsKept() async throws {
        let h = try StoreHarness.make(linkPreviews: FakeLinkPreviews(.succeed(LinkPreview(title: "Razor A5 Scooter", imageData: nil))))
        let id = try importShared(h, title: "Scooter for the park")
        await h.store.waitForLinkPreviews()
        #expect(try h.store.want(id: id)?.title == "Scooter for the park")
    }

    @Test func linkInSharedTextGetsAPreview() async throws {
        let fake = FakeLinkPreviews(.succeed(LinkPreview(title: "LEGO Set", imageData: makePNG(width: 200, height: 200))))
        let h = try StoreHarness.make(linkPreviews: fake)
        let id = try importShared(h, source: .sharedText, text: "https://www.lego.com/en-ca/product/x")
        await h.store.waitForLinkPreviews()
        let entity = try #require(try h.store.want(id: id))
        #expect(entity.title == "LEGO Set")
        #expect(entity.imageFilename != nil)
    }

    @Test func wantsWithAPictureAreNotFetched() async throws {
        let fake = FakeLinkPreviews(.succeed(LinkPreview(title: "Page", imageData: nil)))
        let h = try StoreHarness.make(linkPreviews: fake)
        _ = try importShared(h, image: ImageEncoding.downsampledJPEG(makePNG(width: 100, height: 100)))
        await h.store.waitForLinkPreviews()
        #expect(fake.requested.isEmpty)
    }

    @Test func failureLeavesTheWantUnchanged() async throws {
        let h = try StoreHarness.make(linkPreviews: FakeLinkPreviews(.fail))
        let id = try importShared(h)
        let before = try #require(try h.store.want(id: id)).snapshot
        await h.store.waitForLinkPreviews()
        #expect(try h.store.want(id: id)?.snapshot == before)
    }

    @Test func timeoutLeavesTheWantUnchanged() async throws {
        let h = try StoreHarness.make(linkPreviews: FakeLinkPreviews(.hang), linkPreviewTimeout: .milliseconds(200))
        let id = try importShared(h)
        let before = try #require(try h.store.want(id: id)).snapshot
        let started = Date()
        await h.store.waitForLinkPreviews()
        #expect(Date().timeIntervalSince(started) < 10)
        #expect(try h.store.want(id: id)?.snapshot == before)
        #expect(h.store.images.orphans(referenced: []).isEmpty)
    }

    @Test func unreadableImageStillUpdatesTitle() async throws {
        let h = try StoreHarness.make(linkPreviews: FakeLinkPreviews(.succeed(LinkPreview(title: "Page title", imageData: Data([1, 2, 3])))))
        let id = try importShared(h)
        await h.store.waitForLinkPreviews()
        let entity = try #require(try h.store.want(id: id))
        #expect(entity.title == "Page title")
        #expect(entity.imageFilename == nil)
    }
}
