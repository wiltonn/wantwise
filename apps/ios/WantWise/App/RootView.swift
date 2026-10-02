import SwiftUI

/// Two tabs: what I'm thinking about, and what I've decided.
struct RootView: View {
    @Environment(WantStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            NavigationStack(path: $router.thinkingPath) {
                WantListView()
                    .navigationDestination(for: WantRoute.self) { WantDetailScreen(wantId: $0.id) }
            }
            .tabItem { Label("Thinking", systemImage: "hourglass") }
            .tag(AppTab.thinking)

            NavigationStack(path: $router.decidedPath) {
                HistoryView()
                    .navigationDestination(for: WantRoute.self) { WantDetailScreen(wantId: $0.id) }
            }
            .tabItem { Label("Decided", systemImage: "checkmark.seal") }
            .tag(AppTab.decided)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: store.appBecameActive()
            case .background: store.appWentToBackground()
            default: break
            }
        }
        .task { store.appBecameActive() }
    }
}

#if DEBUG
#Preview {
    RootView()
        .previewEnvironment(sample: true)
}
#endif
