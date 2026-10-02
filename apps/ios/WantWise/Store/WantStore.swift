import Foundation
import Observation
import SwiftData
import WantWiseCore

/// The single write path for Wants (ARCHITECTURE.md, D-005). Views read with `@Query`; every mutation comes here.
///
/// Each write: compute the new value with WantWiseCore → copy onto the SwiftData entity → save → re-sync reminders.
/// Milestone 3 sync hooks in here (entities are already flagged `needsUpload`).
@MainActor
@Observable
final class WantStore {
    enum StoreError: LocalizedError {
        case missingImage

        var errorDescription: String? {
            switch self {
            case .missingImage: return "That picture couldn't be read."
            }
        }
    }

    let context: ModelContext
    let images: ImageFileStore
    let reminders: ReminderScheduling
    let clock: () -> Date
    let calendar: Calendar
    let policy: RevisitPolicy

    /// "Now" for countdowns on screen. Refreshed when the app becomes active and once a minute while visible.
    private(set) var displayNow: Date
    /// Last problem worth telling the user about (shown as an alert by RootView).
    var lastErrorMessage: String?

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var reminderSync: Task<Void, Never>?

    init(
        context: ModelContext,
        images: ImageFileStore,
        reminders: ReminderScheduling,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        policy: RevisitPolicy = .standard
    ) {
        self.context = context
        self.images = images
        self.reminders = reminders
        self.clock = clock
        self.calendar = calendar
        self.policy = policy
        self.displayNow = clock()
    }

    // MARK: - Lifecycle

    /// Call on launch and whenever the scene becomes active.
    func appBecameActive() {
        displayNow = clock()
        importCapturedWants()
        syncReminders()
        startTicker()
    }

    func appWentToBackground() {
        ticker?.cancel()
        ticker = nil
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.displayNow = self.clock()
            }
        }
    }

    // MARK: - Child profile (V1: one family, one child, created on first launch)

    func currentChild() throws -> ChildProfileEntity {
        var descriptor = FetchDescriptor<ChildProfileEntity>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let child = try context.fetch(descriptor).first { return child }

        let now = clock()
        let family = Family(name: "My family", createdAt: now)
        // The name is only used by the household Display (Milestone 4); editable later.
        let child = ChildProfile(familyId: family.id, displayName: "Me", createdAt: now)
        let childEntity = ChildProfileEntity(child)
        context.insert(FamilyEntity(family))
        context.insert(childEntity)
        try context.save()
        return childEntity
    }

    var defaultCurrency: String {
        (try? currentChild().defaultCurrency) ?? ChildProfile.defaultCurrency
    }

    // MARK: - Queries

    func liveWants() throws -> [WantEntity] {
        let descriptor = FetchDescriptor<WantEntity>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Includes soft-deleted Wants (for restore and import de-duplication).
    func want(id: UUID) throws -> WantEntity? {
        var descriptor = FetchDescriptor<WantEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func sections() throws -> WantSections {
        WantSections(try liveWants().map(\.snapshot), now: displayNow)
    }

    func metrics() throws -> ReflectionMetrics {
        let wants = try liveWants()
        let decisions = wants.flatMap(\.decisionHistory)
        return ReflectionMetrics(wants: wants.map(\.snapshot), decisions: decisions, now: clock(), calendar: calendar)
    }

    func imageURL(for want: WantEntity) -> URL? {
        guard let name = want.imageFilename, images.exists(name) else { return nil }
        return try? images.url(for: name)
    }

    func revisitDate(for choice: WaitChoice) -> Date {
        choice.revisitDate(from: clock(), policy: policy, calendar: calendar)
    }

    // MARK: - Create / update

    /// Creates a Want. If `imageData` is given it's downsampled and stored first and becomes the primary image.
    @discardableResult
    func create(_ draft: WantDraft, imageData: Data? = nil) throws -> WantEntity {
        let child = try currentChild()
        let id = UUID()
        var draft = draft
        var savedImage: String?
        if let imageData {
            savedImage = try images.save(imageData, for: id)
            draft.imageFilename = savedImage
        }
        do {
            let want = try draft.makeWant(id: id, childId: child.id, defaultCurrency: child.defaultCurrency, now: clock())
            let entity = WantEntity(want)
            context.insert(entity)
            try context.save()
            if want.status == .waiting { requestReminderPermissionIfNeeded() }
            syncReminders()
            return entity
        } catch {
            if let savedImage { try? images.delete(savedImage) }
            throw error
        }
    }

    func update(_ entity: WantEntity, with edit: WantEdit) throws {
        try write(entity) { try $0.updating(edit, now: clock()) }
    }

    /// Replaces or removes the primary image. The old file is deleted after the new one is saved.
    func setImage(_ data: Data?, for entity: WantEntity) throws {
        let old = entity.imageFilename
        let new = try data.map { try images.save($0, for: entity.id) }
        do {
            try write(entity) { $0.withImage(new, now: clock()) }
        } catch {
            if let new { try? images.delete(new) }
            throw error
        }
        if let old { try? images.delete(old) }
    }

    func setVisibleOnDisplay(_ visible: Bool, for entity: WantEntity) throws {
        try write(entity) { $0.settingVisibleOnDisplay(visible, now: clock()) }
    }

    /// `captured` → `waiting` (e.g. after a quick Share Extension capture).
    func finishReflection(_ entity: WantEntity, reason: String?, similarItemAnswer: SimilarItemAnswer?, wait: WaitChoice) throws {
        let revisit = revisitDate(for: wait)
        try write(entity) {
            try $0.finishingReflection(reason: reason, similarItemAnswer: similarItemAnswer, revisitAt: revisit, now: clock())
        }
        requestReminderPermissionIfNeeded()
    }

    // MARK: - Decisions (append to history)

    @discardableResult
    func decide(_ entity: WantEntity, _ kind: DecisionKind, note: String? = nil, wait: WaitChoice? = nil) throws -> WantDecision {
        let newRevisit = wait.map(revisitDate(for:))
        let outcome = try entity.snapshot.deciding(kind, note: note, newRevisitAt: newRevisit, now: clock())
        entity.apply(outcome.want)
        let decision = WantDecisionEntity(outcome.decision, want: entity)
        context.insert(decision)
        try context.save()
        if kind != .waitLonger { reminders.clearDelivered(for: entity.id) }
        syncReminders()
        return outcome.decision
    }

    func stillWant(_ entity: WantEntity, note: String? = nil) throws {
        try decide(entity, .stillWant, note: note)
    }

    /// Extends the waiting period. Recorded as a decision so history shows it.
    func waitLonger(_ entity: WantEntity, wait: WaitChoice, note: String? = nil) throws {
        try decide(entity, .waitLonger, note: note, wait: wait)
    }

    func markPurchased(_ entity: WantEntity, note: String? = nil) throws {
        try decide(entity, .purchased, note: note)
    }

    func markNoLongerWanted(_ entity: WantEntity, note: String? = nil) throws {
        try decide(entity, .noLongerWant, note: note)
    }

    // MARK: - Delete

    /// Soft delete: hidden everywhere, kept for sync and possible restore. The image file is kept too.
    func softDelete(_ entity: WantEntity) throws {
        try write(entity) { $0.softDeleting(now: clock()) }
        reminders.clearDelivered(for: entity.id)
    }

    func restore(_ entity: WantEntity) throws {
        try write(entity) { $0.restoring(now: clock()) }
    }

    // MARK: - Capture import (Share Extension → App Group inbox → Want)

    @discardableResult
    func importCapturedWants() -> CaptureImporter.Report? {
        guard let container = AppGroup.containerURL else { return nil }
        return importCapturedWants(from: CaptureInbox(appGroupContainer: container))
    }

    @discardableResult
    func importCapturedWants(from inbox: CaptureInbox) -> CaptureImporter.Report {
        guard let child = try? currentChild() else { return CaptureImporter.Report() }
        let report = CaptureImporter.importAll(
            from: inbox,
            images: images,
            childId: child.id,
            defaultCurrency: child.defaultCurrency,
            exists: { [self] id in try want(id: id) != nil },
            insert: { [self] want in
                context.insert(WantEntity(want))
                try context.save()
            }
        )
        if !report.imported.isEmpty { syncReminders() }
        return report
    }

    // MARK: - Reminders

    /// Brings pending local notifications in line with the current Wants: adds missing, moves changed, removes obsolete.
    ///
    /// Syncs are chained, and each reads the Wants when it actually runs, so a late sync can never re-add a
    /// reminder that a newer change removed.
    func syncReminders() {
        let previous = reminderSync
        reminderSync = Task { [weak self] in
            await previous?.value
            guard let self, let wants = try? self.liveWants().map(\.snapshot) else { return }
            await self.reminders.sync(wants: wants, now: self.clock(), calendar: self.calendar)
        }
    }

    /// Waits for queued reminder syncs to finish (tests, debug tools).
    func waitForReminderSync() async {
        await reminderSync?.value
    }

    private func requestReminderPermissionIfNeeded() {
        let reminders = reminders
        Task { await reminders.requestPermissionIfNeeded() }
    }

    // MARK: - Helpers

    private func write(_ entity: WantEntity, _ change: (Want) throws -> Want) throws {
        let updated = try change(entity.snapshot)
        entity.apply(updated)
        try context.save()
        syncReminders()
    }
}
