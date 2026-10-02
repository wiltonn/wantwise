import SwiftUI

/// WantWise visual tokens, shared with the household Display (apps/display/app/globals.css).
/// Dark, high-contrast, one warm accent. The accent marks "ready" and primary actions, nothing else.
enum Theme {
    static let background = Color(red: 0.039, green: 0.043, blue: 0.055)      // #0A0B0E
    static let surface = Color(red: 0.082, green: 0.090, blue: 0.110)         // #15171C
    static let surfaceRaised = Color(red: 0.110, green: 0.122, blue: 0.149)   // #1C1F26
    static let line = Color.white.opacity(0.10)
    static let text = Color(red: 0.961, green: 0.953, blue: 0.933)            // #F5F3EE
    static let textMuted = text.opacity(0.62)
    static let textFaint = text.opacity(0.40)
    static let accent = Color(red: 0.953, green: 0.769, blue: 0.420)          // #F3C46B
    static let accentInk = Color(red: 0.106, green: 0.078, blue: 0.027)       // #1B1407

    static let radiusLarge: CGFloat = 28
    static let radiusMedium: CGFloat = 20
    static let radiusSmall: CGFloat = 14
    /// Minimum height for anything a child taps.
    static let touchTarget: CGFloat = 56
    static let pagePadding: CGFloat = 20

    /// Deep, restrained hues for Wants without a picture. Chosen by a stable hash of the title.
    static let placeholderHues: [(Color, Color)] = [
        (Color(red: 0.16, green: 0.20, blue: 0.33), Color(red: 0.07, green: 0.08, blue: 0.14)),
        (Color(red: 0.29, green: 0.17, blue: 0.28), Color(red: 0.10, green: 0.06, blue: 0.11)),
        (Color(red: 0.13, green: 0.26, blue: 0.25), Color(red: 0.05, green: 0.10, blue: 0.10)),
        (Color(red: 0.33, green: 0.22, blue: 0.13), Color(red: 0.12, green: 0.08, blue: 0.05)),
        (Color(red: 0.20, green: 0.18, blue: 0.34), Color(red: 0.07, green: 0.06, blue: 0.13)),
        (Color(red: 0.27, green: 0.13, blue: 0.15), Color(red: 0.10, green: 0.05, blue: 0.06)),
    ]
}

extension Font {
    static let wwDisplay = Font.system(size: 40, weight: .bold, design: .default)
    static let wwTitle = Font.system(.title, design: .default, weight: .bold)
    static let wwTitle2 = Font.system(.title2, design: .default, weight: .semibold)
    static let wwHeadline = Font.system(.headline, design: .default, weight: .semibold)
    static let wwBody = Font.system(.body)
    static let wwCaption = Font.system(.subheadline, design: .default, weight: .medium)
    static let wwLabel = Font.system(.caption, design: .default, weight: .semibold)
}

/// Big, full-width primary action (accent fill).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wwHeadline)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            .foregroundStyle(Theme.accentInk)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.35), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Full-width secondary action (raised surface). Also used for equal-weight choices, e.g. reconsider options.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wwHeadline)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            .foregroundStyle(Theme.text)
            .background(Theme.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var wwPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var wwSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// A selectable capsule for short choices (wait durations, yes/no/not sure).
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.wwHeadline)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .foregroundStyle(isSelected ? Theme.accentInk : Theme.text)
                .background(isSelected ? Theme.accent : Theme.surfaceRaised, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
