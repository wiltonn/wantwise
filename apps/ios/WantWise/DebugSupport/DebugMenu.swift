#if DEBUG
import SwiftUI

/// Ladybug menu on the home screen (DEBUG builds only) for exercising Milestone 1 quickly in the Simulator.
struct DebugMenu: View {
    @Environment(WantStore.self) private var store

    var body: some View {
        Menu {
            Button("Load sample Wants") { SampleData.load(into: store) }
            Button("Make one ready to think again") { store.debugMakeOneReady() }
            Button("Send a reminder in 10 seconds") { Task { await store.debugReminderSoon() } }
            Divider()
            Button("Delete everything", role: .destructive) { store.debugDeleteEverything() }
        } label: {
            Image(systemName: "ladybug")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Debug")
        .accessibilityIdentifier("debugMenu")
    }
}
#endif
