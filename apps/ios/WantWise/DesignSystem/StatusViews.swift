import SwiftUI
import WantWiseCore

/// Status pill: accent-filled when ready, accent-outlined when due today/tomorrow, neutral otherwise.
struct StatusChip: View {
    let want: Want
    let now: Date
    let calendar: Calendar
    var large = false

    private enum Tone { case ready, soon, calm }

    var body: some View {
        let tone = tone
        HStack(spacing: 8) {
            Circle()
                .fill(tone == .ready ? Theme.accentInk : (tone == .soon ? Theme.accent : Theme.textMuted))
                .frame(width: 8, height: 8)
            Text(text)
        }
        .font(large ? .wwHeadline : .wwLabel)
        .padding(.horizontal, large ? 16 : 10)
        .padding(.vertical, large ? 9 : 6)
        .foregroundStyle(tone == .ready ? Theme.accentInk : Theme.text)
        .background(tone == .ready ? Theme.accent : Color.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(tone == .soon ? Theme.accent : .clear, lineWidth: 1.5))
        .fixedSize()
    }

    private var text: String {
        if let countdown = want.countdown(now: now, calendar: calendar) { return countdown.text }
        return DecisionCopy.outcomeLabel(want.status)
    }

    private var tone: Tone {
        switch want.countdown(now: now, calendar: calendar) {
        case .ready?: return .ready
        case .today?, .tomorrow?: return .soon
        default: return .calm
        }
    }
}

/// Thin progress bar for the current waiting period.
struct WaitProgressBar: View {
    let progress: Double
    var isReady = false
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(isReady ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(LinearGradient(
                        colors: [Theme.text.opacity(0.5), Theme.text], startPoint: .leading, endPoint: .trailing
                    )))
                    .frame(width: max(proxy.size.width * progress, height))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Waiting progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// Small uppercase label above a section.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.wwLabel)
            .tracking(1.6)
            .foregroundStyle(Theme.textFaint)
    }
}

/// Rounded surface used for grouped content.
struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).strokeBorder(Theme.line))
    }
}
