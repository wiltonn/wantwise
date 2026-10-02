import Foundation
import SwiftData

/// Where things live on disk, and how the SwiftData container is built.
///
/// Long-lived data (store + images) is in the app's own container, not the App Group (D-019).
enum AppPaths {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WantWise", isDirectory: true)
    }

    static var storeURL: URL { root.appendingPathComponent("WantWise.store") }
    static var imagesDirectory: URL { root.appendingPathComponent("Images", isDirectory: true) }

    static func ensureRoot() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}

enum Persistence {
    static let schema = Schema(versionedSchema: WantWiseSchemaV1.self)

    /// - Parameter url: nil for an in-memory store (tests, previews, UI tests).
    static func makeContainer(url: URL?) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: WantWiseMigrationPlan.self, configurations: [configuration])
    }

    /// Removes the on-disk store and images. DEBUG reset only.
    static func destroyLocalData() {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(at: URL(fileURLWithPath: AppPaths.storeURL.path + suffix))
        }
        try? fm.removeItem(at: AppPaths.imagesDirectory)
    }
}
