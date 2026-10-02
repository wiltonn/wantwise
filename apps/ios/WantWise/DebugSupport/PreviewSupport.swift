#if DEBUG
import SwiftData
import SwiftUI
import WantWiseCore

/// In-memory environments for SwiftUI previews (and anything else that needs a throwaway store).
@MainActor
enum PreviewSupport {
    @MainActor
    struct Env {
        let container: ModelContainer
        let store: WantStore
        let router: AppRouter

        func want(in phase: WantPhase) -> WantEntity? {
            (try? store.liveWants())?.first { $0.snapshot.phase(now: store.displayNow) == phase }
        }
    }

    static func make(sample: Bool) -> Env {
        let container = try! Persistence.makeContainer(url: nil)
        let images = ImageFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("wantwise-preview-\(UUID().uuidString)"),
            encode: ImageEncoding.downsampledJPEG
        )
        let store = WantStore(context: container.mainContext, images: images, reminders: NoopReminders())
        if sample { SampleData.load(into: store) }
        return Env(container: container, store: store, router: AppRouter())
    }
}

/// Reminders that do nothing (previews never ask for notification permission).
@MainActor
final class NoopReminders: ReminderScheduling {
    func sync(wants: [Want], now: Date, calendar: Calendar) async {}
    func requestPermissionIfNeeded() async {}
    func clearDelivered(for wantId: UUID) {}
}

/// Hosts preview content with a store, router and model container.
@MainActor
struct PreviewHost<Content: View>: View {
    @State private var environment: PreviewSupport.Env
    private let content: (PreviewSupport.Env) -> Content

    init(sample: Bool, @ViewBuilder content: @escaping (PreviewSupport.Env) -> Content) {
        _environment = State(initialValue: PreviewSupport.make(sample: sample))
        self.content = content
    }

    var body: some View {
        content(environment)
            .environment(environment.store)
            .environment(environment.router)
            .modelContainer(environment.container)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
    }
}

/// Preview a view that takes a WantEntity in a particular phase.
@MainActor
struct PreviewWant<Content: View>: View {
    let status: WantPhase
    @ViewBuilder let content: (WantEntity) -> Content

    var body: some View {
        PreviewHost(sample: true) { environment in
            if let entity = environment.want(in: status) {
                content(entity)
            } else {
                Text("No sample Want in phase \(status.rawValue)")
            }
        }
    }
}

extension View {
    @MainActor
    func previewEnvironment(sample: Bool) -> some View {
        PreviewHost(sample: sample) { _ in self }
    }
}
#endif
