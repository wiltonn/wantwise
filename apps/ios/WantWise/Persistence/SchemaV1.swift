import Foundation
import SwiftData
import WantWiseCore

/// SwiftData schema, version 1. Field meanings: docs/DATA_MODEL.md.
///
/// Migration-conscious choices (D-024):
/// - Models live inside a `VersionedSchema` from day one, so a V2 adds a `SchemaMigrationPlan` stage instead of
///   retrofitting versioning onto an unversioned store.
/// - Every stored property has a default, so additive changes stay lightweight migrations.
/// - Enums are stored as raw `String`s (readable, extendable, predicate-safe on iOS 17).
/// - Sync bookkeeping (`needsUpload`, `lastSyncedAt`) is included now so Milestone 3 needs no schema change.
/// - Images are file names, never blobs (D-009).
enum WantWiseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [FamilyEntity.self, ChildProfileEntity.self, WantEntity.self, WantDecisionEntity.self]
    }
}

enum WantWiseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WantWiseSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// The rest of the app refers to the current version's models by these names.
typealias FamilyEntity = WantWiseSchemaV1.FamilyEntity
typealias ChildProfileEntity = WantWiseSchemaV1.ChildProfileEntity
typealias WantEntity = WantWiseSchemaV1.WantEntity
typealias WantDecisionEntity = WantWiseSchemaV1.WantDecisionEntity

extension WantWiseSchemaV1 {
    @Model
    final class FamilyEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var needsUpload: Bool = true
        var lastSyncedAt: Date?

        init(_ family: Family) {
            id = family.id
            name = family.name
            createdAt = family.createdAt
            updatedAt = family.updatedAt
        }
    }

    @Model
    final class ChildProfileEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var familyId: UUID = UUID()
        var displayName: String = ""
        var defaultCurrency: String = ChildProfile.defaultCurrency
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var needsUpload: Bool = true
        var lastSyncedAt: Date?

        init(_ child: ChildProfile) {
            id = child.id
            familyId = child.familyId
            displayName = child.displayName
            defaultCurrency = child.defaultCurrency
            createdAt = child.createdAt
            updatedAt = child.updatedAt
        }

        var snapshot: ChildProfile {
            ChildProfile(
                id: id, familyId: familyId, displayName: displayName,
                defaultCurrency: defaultCurrency, createdAt: createdAt, updatedAt: updatedAt
            )
        }
    }

    @Model
    final class WantEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var childId: UUID = UUID()
        var title: String = ""
        var details: String?
        var productURL: String?
        /// File name inside the app's Images directory (ImageFileStore). Later also the Storage object name.
        var imageFilename: String?
        var sourceTypeRaw: String = SourceType.manual.rawValue
        var priceMinor: Int?
        var currency: String = ChildProfile.defaultCurrency
        var reason: String?
        var similarItemAnswerRaw: String?
        var similarItemNote: String?
        var statusRaw: String = WantStatus.captured.rawValue
        var revisitAt: Date?
        var waitStartedAt: Date?
        var decidedAt: Date?
        var decisionReason: String?
        var isVisibleOnDisplay: Bool = true
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        /// Soft delete (D-013). Lists filter on `deletedAt == nil`.
        var deletedAt: Date?
        var needsUpload: Bool = true
        var lastSyncedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \WantDecisionEntity.want)
        var decisions: [WantDecisionEntity]? = []

        init(_ want: Want) {
            id = want.id
            apply(want)
        }

        /// The domain value. All logic (transitions, countdowns, sections) runs on this, in WantWiseCore.
        var snapshot: Want {
            Want(
                id: id,
                childId: childId,
                title: title,
                details: details,
                productURL: productURL,
                imageFilename: imageFilename,
                sourceType: SourceType(rawValue: sourceTypeRaw) ?? .manual,
                priceMinor: priceMinor,
                currency: currency,
                reason: reason,
                similarItemAnswer: similarItemAnswerRaw.flatMap(SimilarItemAnswer.init(rawValue:)),
                similarItemNote: similarItemNote,
                status: WantStatus(rawValue: statusRaw) ?? .waiting,
                revisitAt: revisitAt,
                waitStartedAt: waitStartedAt,
                decidedAt: decidedAt,
                decisionReason: decisionReason,
                isVisibleOnDisplay: isVisibleOnDisplay,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt
            )
        }

        /// Copies a domain value back. Marks the record for upload (Milestone 3 sync).
        func apply(_ want: Want) {
            childId = want.childId
            title = want.title
            details = want.details
            productURL = want.productURL
            imageFilename = want.imageFilename
            sourceTypeRaw = want.sourceType.rawValue
            priceMinor = want.priceMinor
            currency = want.currency
            reason = want.reason
            similarItemAnswerRaw = want.similarItemAnswer?.rawValue
            similarItemNote = want.similarItemNote
            statusRaw = want.status.rawValue
            revisitAt = want.revisitAt
            waitStartedAt = want.waitStartedAt
            decidedAt = want.decidedAt
            decisionReason = want.decisionReason
            isVisibleOnDisplay = want.isVisibleOnDisplay
            createdAt = want.createdAt
            updatedAt = want.updatedAt
            deletedAt = want.deletedAt
            needsUpload = true
        }

        var decisionHistory: [WantDecision] {
            (decisions ?? []).map(\.snapshot).sorted { $0.decidedAt < $1.decidedAt }
        }
    }

    /// Append-only (D-007): created, never edited or deleted (except by cascading a hard delete, which V1 never does).
    @Model
    final class WantDecisionEntity {
        @Attribute(.unique) var id: UUID = UUID()
        /// Denormalised for sync; mirrors `want?.id`.
        var wantId: UUID = UUID()
        var kindRaw: String = DecisionKind.stillWant.rawValue
        var note: String?
        var previousRevisitAt: Date?
        var newRevisitAt: Date?
        var decidedAt: Date = Date()
        var needsUpload: Bool = true
        var lastSyncedAt: Date?
        var want: WantEntity?

        /// Insert into a context before setting `want` (some iOS 17 builds mishandle relationships on un-inserted models).
        init(_ decision: WantDecision) {
            id = decision.id
            wantId = decision.wantId
            kindRaw = decision.kind.rawValue
            note = decision.note
            previousRevisitAt = decision.previousRevisitAt
            newRevisitAt = decision.newRevisitAt
            decidedAt = decision.decidedAt
        }

        var snapshot: WantDecision {
            WantDecision(
                id: id,
                wantId: wantId,
                kind: DecisionKind(rawValue: kindRaw) ?? .stillWant,
                note: note,
                previousRevisitAt: previousRevisitAt,
                newRevisitAt: newRevisitAt,
                decidedAt: decidedAt
            )
        }
    }
}
