import SwiftUI
import WantWiseCore

/// "Want this?" — the whole capture in one screen: picture, reason, how long to think, save.
struct CaptureView: View {
    @Bindable var model: CaptureModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch model.phase {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                    case .failed(let message):
                        Text(message)
                            .font(.wwTitle2)
                            .foregroundStyle(Theme.text)
                        Button("Close") { model.cancel() }.buttonStyle(.wwSecondary)
                    case .saved(let revisitAt):
                        saved(revisitAt)
                    case .ready:
                        form
                    }
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("WantWise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var form: some View {
        Text("Want this?")
            .font(.wwDisplay)
            .foregroundStyle(Theme.text)

        if let preview = model.preview {
            Image(uiImage: preview)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        } else if let url = model.sharedURL {
            Label(url.host ?? url.absoluteString, systemImage: "link")
                .font(.wwHeadline)
                .foregroundStyle(Theme.text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        } else if let text = model.sharedText {
            Text(text)
                .lineLimit(4)
                .foregroundStyle(Theme.textMuted)
        }

        captureField("What is it?", text: $model.title, prompt: "Optional")
        captureField("What makes you want it?", text: $model.reason, prompt: "Because…")

        VStack(alignment: .leading, spacing: 10) {
            Text("THINK ABOUT IT FOR")
                .font(.wwLabel)
                .tracking(1.6)
                .foregroundStyle(Theme.textFaint)
            HStack(spacing: 10) {
                ForEach(WaitChoice.presets(), id: \.self) { choice in
                    ChoiceChip(title: choice.presetLabel ?? "", isSelected: model.wait == choice) { model.wait = choice }
                }
            }
        }

        Button("Add to WantWise") { model.save() }
            .buttonStyle(.wwPrimary)
            .padding(.top, 6)
    }

    private func captureField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.wwLabel)
                .tracking(1.6)
                .foregroundStyle(Theme.textFaint)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...3)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
    }

    private func saved(_ revisitAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("Saved")
                .font(.wwDisplay)
                .foregroundStyle(Theme.text)
            Group {
                if let revisitAt {
                    Text("Let's think about this again on \(revisitAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).")
                } else {
                    Text("Open WantWise to say why you want it.")
                }
            }
            .font(.wwTitle2)
            .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }
}
