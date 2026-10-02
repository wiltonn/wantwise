import SwiftUI
import WantWiseCore

/// "You wanted this 7 days ago. What do you think now?"
///
/// The choices are deliberately equal in weight: no option is styled as the "right" one (PRODUCT.md).
struct ReconsiderView: View {
    @Environment(WantStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entity: WantEntity

    private enum Step: Equatable {
        case ask
        case chooseWait
        case done(DecisionKind)
    }

    @State private var step: Step = .ask
    @State private var wait: WaitChoice = .recommended()
    @State private var customDay = Date()
    @State private var errorMessage: String?

    var body: some View {
        let want = entity.snapshot
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WantArtwork(imageURL: store.imageURL(for: entity), title: want.displayTitle, sourceType: want.sourceType, style: .poster, maxPixelSize: 1600)
                        .frame(height: step == .ask ? 380 : 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
                        .animation(.easeInOut(duration: 0.35), value: step)

                    switch step {
                    case .ask: ask(want)
                    case .chooseWait: chooseWait()
                    case .done(let kind): done(kind, want: want)
                    }
                }
                .padding(Theme.pagePadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .done = step {
                        EmptyView()
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(Theme.text)
    }

    // MARK: - Steps

    @ViewBuilder
    private func ask(_ want: Want) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(want.displayTitle)
                .font(.wwLabel)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accent)
            Text(want.reconsiderPrompt(now: store.displayNow, calendar: store.calendar))
                .font(.wwTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let reason = want.reason {
                Text("You said: “\(reason)”")
                    .font(.wwBody)
                    .foregroundStyle(Theme.textMuted)
            }
        }

        VStack(spacing: 12) {
            ForEach(want.allowedDecisions, id: \.self) { kind in
                Button {
                    choose(kind)
                } label: {
                    Label(DecisionCopy.actionLabel(kind), systemImage: kind.symbol)
                }
                .buttonStyle(.wwSecondary)
                .accessibilityIdentifier("decision-\(kind.rawValue)")
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func chooseWait() -> some View {
        Text("How much longer?")
            .font(.wwTitle)
            .foregroundStyle(Theme.text)
        WaitChooser(wait: $wait, customDay: $customDay, title: "Think about it for")
        Button("Wait longer") { record(.waitLonger) }
            .buttonStyle(.wwPrimary)
            .accessibilityIdentifier("confirmWaitLonger")
        Button("Back") { withAnimation { step = .ask } }
            .buttonStyle(.wwSecondary)
    }

    @ViewBuilder
    private func done(_ kind: DecisionKind, want: Want) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(DecisionCopy.confirmationTitle(kind))
                .font(.wwDisplay)
                .foregroundStyle(Theme.text)
            Text(DecisionCopy.confirmationMessage(kind))
                .font(.wwTitle2)
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if kind == .waitLonger, let revisitAt = entity.revisitAt {
                Text(Formatting.thinkAgainSentence(revisitAt, now: store.displayNow, calendar: store.calendar))
                    .font(.wwHeadline)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 4)
            }
        }
        Button("Done") { dismiss() }
            .buttonStyle(.wwPrimary)
            .padding(.top, 12)
            .accessibilityIdentifier("doneAfterDecision")
    }

    // MARK: - Actions

    private func choose(_ kind: DecisionKind) {
        if kind == .waitLonger {
            withAnimation { step = .chooseWait }
        } else {
            record(kind)
        }
    }

    private func record(_ kind: DecisionKind) {
        do {
            try store.decide(entity, kind, wait: kind == .waitLonger ? wait : nil)
            withAnimation(.easeOut(duration: 0.3)) { step = .done(kind) }
        } catch {
            errorMessage = "That didn't save. Please try again."
        }
    }
}

extension DecisionKind {
    var symbol: String {
        switch self {
        case .stillWant: return "heart"
        case .waitLonger: return "hourglass"
        case .noLongerWant: return "hand.wave"
        case .purchased: return "bag"
        }
    }
}

#if DEBUG
#Preview {
    PreviewWant(status: .readyToReconsider) { entity in
        ReconsiderView(entity: entity)
    }
}
#endif
