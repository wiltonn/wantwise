import SwiftData
import SwiftUI
import WantWiseCore

/// Decided Wants and the decision timeline. Every outcome is presented the same way: as a decision made.
/// No totals of money "saved" here; that's for the parent view later, and never a score (PRODUCT.md).
struct HistoryView: View {
    @Environment(WantStore.self) private var store
    @Query(filter: #Predicate<WantEntity> { $0.deletedAt == nil }, sort: \WantEntity.updatedAt, order: .reverse)
    private var entities: [WantEntity]
    @Query(sort: \WantDecisionEntity.decidedAt, order: .reverse)
    private var decisions: [WantDecisionEntity]

    enum Mode: String, CaseIterable, Identifiable {
        case wants = "Decided"
        case timeline = "Timeline"
        var id: String { rawValue }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case stillWant = "Still want"
        case purchased = "Got it"
        case noLongerWant = "Changed mind"
        var id: String { rawValue }

        func includes(_ status: WantStatus) -> Bool {
            switch self {
            case .all: return true
            case .stillWant: return status == .stillWant
            case .purchased: return status == .purchased
            case .noLongerWant: return status == .noLongerWant
            }
        }
    }

    @State private var mode: Mode = .wants
    @State private var filter: Filter = .all

    var body: some View {
        let now = store.displayNow
        let snapshots = entities.map(\.snapshot)
        let decided = WantSections(snapshots, now: now).decided
        let byId = Dictionary(entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let metrics = ReflectionMetrics(
            wants: snapshots,
            decisions: decisions.map(\.snapshot),
            now: now,
            calendar: store.calendar
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Decided")
                    .font(.wwDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 12)

                summary(metrics: metrics, decidedCount: decided.count)

                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .wants:
                    wantsList(decided.filter { filter.includes($0.status) }, byId: byId)
                case .timeline:
                    timeline(byId: byId)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private func summary(metrics: ReflectionMetrics, decidedCount: Int) -> some View {
        HStack(spacing: 12) {
            statTile(value: "\(decidedCount)", label: decidedCount == 1 ? "thing decided" : "things decided")
            statTile(
                value: metrics.averageThinkingTime.map { CalendarDays.durationText(Int(($0 / 86_400).rounded())) } ?? "–",
                label: "average thinking time"
            )
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.wwTitle)
                .foregroundStyle(Theme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.wwCaption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
    }

    @ViewBuilder
    private func wantsList(_ wants: [Want], byId: [UUID: WantEntity]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { option in
                    ChoiceChip(title: option.rawValue, isSelected: filter == option) { filter = option }
                }
            }
        }

        if wants.isEmpty {
            Text(filter == .all
                 ? "When you decide about a Want, it shows up here."
                 : "Nothing here yet.")
                .font(.wwBody)
                .foregroundStyle(Theme.textMuted)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(wants) { want in
                    NavigationLink(value: WantRoute(id: want.id)) {
                        DecidedWantRow(want: want, imageURL: byId[want.id].flatMap(store.imageURL(for:)), calendar: store.calendar)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func timeline(byId: [UUID: WantEntity]) -> some View {
        let visible = decisions.filter { byId[$0.wantId] != nil }
        if visible.isEmpty {
            Text("Decisions you make will appear here.")
                .font(.wwBody)
                .foregroundStyle(Theme.textMuted)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 10) {
                ForEach(visible) { decision in
                    if let entity = byId[decision.wantId] {
                        NavigationLink(value: WantRoute(id: entity.id)) {
                            TimelineRow(decision: decision.snapshot, want: entity.snapshot, imageURL: store.imageURL(for: entity))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct DecidedWantRow: View {
    let want: Want
    let imageURL: URL?
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 16) {
            WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType, maxPixelSize: 300)
                .frame(width: 72, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(want.displayTitle)
                    .font(.wwHeadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(DecisionCopy.outcomeLabel(want.status))
                    .font(.wwLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .foregroundStyle(Theme.text)
                if let days = want.thinkingDays(calendar: calendar) {
                    Text("Thought about it for \(CalendarDays.durationText(days))")
                        .font(.wwCaption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.textFaint)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct TimelineRow: View {
    let decision: WantDecision
    let want: Want
    let imageURL: URL?

    var body: some View {
        HStack(spacing: 14) {
            WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType, maxPixelSize: 200)
                .frame(width: 48, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(want.displayTitle)
                    .font(.wwHeadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Label(DecisionCopy.timelineText(decision.kind), systemImage: decision.kind.symbol)
                    .font(.wwCaption)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
            Text(decision.decidedAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.wwLabel)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
    }
}

#if DEBUG
#Preview {
    NavigationStack { HistoryView() }
        .previewEnvironment(sample: true)
}
#endif
