import SwiftUI
import WantWiseCore

/// For a quick capture (`captured`): add the reason and choose how long to think. Turns it into a waiting Want.
struct FinishAddingView: View {
    @Environment(WantStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entity: WantEntity

    @State private var reason = ""
    @State private var similar: SimilarItemAnswer?
    @State private var wait: WaitChoice = .recommended()
    @State private var customDay = Date()
    @State private var savedRevisit: Date?
    @State private var errorMessage: String?

    var body: some View {
        let want = entity.snapshot
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    WantArtwork(imageURL: store.imageURL(for: entity), title: want.displayTitle, sourceType: want.sourceType, style: .poster)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))

                    if let savedRevisit {
                        Text(Formatting.thinkAgainSentence(savedRevisit, now: store.displayNow, calendar: store.calendar))
                            .font(.wwTitle2)
                            .foregroundStyle(Theme.text)
                        Button("Done") { dismiss() }
                            .buttonStyle(.wwPrimary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("What makes you want it?")
                            TextField("Because…", text: $reason, axis: .vertical)
                                .lineLimit(2...5)
                                .padding(16)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("Do you already have something similar?")
                            HStack(spacing: 10) {
                                ForEach(SimilarItemAnswer.allCases, id: \.self) { answer in
                                    ChoiceChip(title: answer.label, isSelected: similar == answer) {
                                        similar = similar == answer ? nil : answer
                                    }
                                }
                            }
                        }
                        WaitChooser(wait: $wait, customDay: $customDay, title: "Think about it for")
                        Button("Save", action: save)
                            .buttonStyle(.wwPrimary)
                    }
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(want.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationBackground(Theme.background)
        .onAppear { reason = want.reason ?? "" }
    }

    private func save() {
        do {
            try store.finishReflection(entity, reason: reason, similarItemAnswer: similar, wait: wait)
            withAnimation { savedRevisit = entity.revisitAt }
        } catch {
            errorMessage = "Please choose a day in the future."
        }
    }
}

extension SimilarItemAnswer {
    var label: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .notSure: return "Not sure"
        }
    }
}
