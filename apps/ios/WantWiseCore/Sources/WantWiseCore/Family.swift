import Foundation

public struct Family: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    /// Private. Never shown on the household Display.
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

public struct ChildProfile: Identifiable, Codable, Sendable, Equatable {
    public static let defaultCurrency = "CAD"

    public var id: UUID
    public var familyId: UUID
    public var displayName: String
    /// Seeds new Wants only; every Want stores its own currency (D-020).
    public var defaultCurrency: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        familyId: UUID,
        displayName: String,
        defaultCurrency: String = ChildProfile.defaultCurrency,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.displayName = displayName
        self.defaultCurrency = defaultCurrency
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

/// "Things I Love". Modelled now, built later (PRODUCT.md).
public struct LovedThing: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var childId: UUID
    public var title: String
    public var kind: LovedThingKind
    public var note: String?
    public var imageFilename: String?
    public var isVisibleOnDisplay: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        childId: UUID,
        title: String,
        kind: LovedThingKind,
        note: String? = nil,
        imageFilename: String? = nil,
        isVisibleOnDisplay: Bool = true,
        createdAt: Date,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.childId = childId
        self.title = title
        self.kind = kind
        self.note = note
        self.imageFilename = imageFilename
        self.isVisibleOnDisplay = isVisibleOnDisplay
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }
}
