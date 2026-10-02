import SwiftData
import SwiftUI
import WantWiseCore

/// Looks a Want up by id (navigation value), so the route survives the entity changing underneath.
struct WantDetailScreen: View {
    @Query private var matches: [WantEntity]

    init(wantId: UUID) {
        _matches = Query(filter: #Predicate<WantEntity> { $0.id == wantId && $0.deletedAt == nil })
    }

    var body: some View {
        if let entity = matches.first {
            WantDetailView(entity: entity)
        } else {
            ContentUnavailableView("This Want isn't here anymore", systemImage: "tray")
                .background(Theme.background.ignoresSafeArea())
        }
    }
}

/// One Want: its picture, why, how long is left, what was decided, and its history.
struct WantDetailView: View {
    @Environment(WantStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entity: WantEntity

    @State private var reconsidering = false
    @State private var finishing = false
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        let want = entity.snapshot
        let now = store.displayNow
        let phase = want.phase(now: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WantArtwork(imageURL: store.imageURL(for: entity), title: want.displayTitle, sourceType: want.sourceType, style: .poster, maxPixelSize: 1600)
                    .frame(height: store.imageURL(for: entity) == nil ? 260 : 440)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(want.displayTitle)
                        .font(.wwDisplay)
                        .tracking(-0.8)
                        .foregroundStyle(Theme.text)
                    if let price = Formatting.price(want.price) {
                        Text(price)
                            .font(.wwTitle2)
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                statusCard(want: want, phase: phase, now: now)

                if let reason = want.reason {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Why I want it")
                        Text("“\(reason)”")
                            .font(.wwTitle2)
                            .foregroundStyle(Theme.text)
                    }
                }

                if let similar = want.similarItemAnswer {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Something similar at home?")
                        Text([similar.label, want.similarItemNote].compactMap { $0 }.joined(separator: " · "))
                            .font(.wwBody)
                            .foregroundStyle(Theme.text)
                    }
                }

                if let link = want.productURL.flatMap(URL.init(string:)) {
                    Link(destination: link) {
                        Label(link.host ?? "Open link", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.wwSecondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("History")
                    DecisionTimeline(entries: TimelineEntry.entries(for: want, decisions: entity.decisionHistory))
                }
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu(want: want) }
        .fullScreenCover(isPresented: $reconsidering) { ReconsiderView(entity: entity) }
        .sheet(isPresented: $finishing) { FinishAddingView(entity: entity) }
        .sheet(isPresented: $editing) { AddWantView(mode: .edit(entity)) }
        .confirmationDialog("Remove this Want?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { perform { try store.softDelete(entity) } ; dismiss() }
        } message: {
            Text("It will disappear from your lists and the family screen.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Status

    @ViewBuilder
    private func statusCard(want: Want, phase: WantPhase, now: Date) -> some View {
        SurfaceCard {
            switch phase {
            case .waiting:
                if let countdown = want.countdown(now: now, calendar: store.calendar), let revisitAt = want.revisitAt {
                    Text(countdown.text)
                        .font(.wwTitle)
                        .foregroundStyle(Theme.text)
                    WaitProgressBar(progress: want.waitProgress(now: now) ?? 0)
                    HStack {
                        Text("Added \(CalendarDays.agoText(since: want.createdAt, now: now, calendar: store.calendar))")
                        Spacer()
                        Text("Think again \(Formatting.revisit(revisitAt, now: now, calendar: store.calendar))")
                    }
                    .font(.wwCaption)
                    .foregroundStyle(Theme.textMuted)
                    Button("Think about it now") { reconsidering = true }
                        .buttonStyle(.wwSecondary)
                        .padding(.top, 4)
                }
            case .readyToReconsider:
                StatusChip(want: want, now: now, calendar: store.calendar, large: true)
                Text(want.reconsiderPrompt(now: now, calendar: store.calendar))
                    .font(.wwTitle2)
                    .foregroundStyle(Theme.text)
                Button("Think about it") { reconsidering = true }
                    .buttonStyle(.wwPrimary)
            case .needsReflection:
                Text("You haven't chosen how long to think yet.")
                    .font(.wwTitle2)
                    .foregroundStyle(Theme.text)
                Button("Finish adding") { finishing = true }
                    .buttonStyle(.wwPrimary)
            case .stillWant:
                Text("You still want this")
                    .font(.wwTitle2)
                    .foregroundStyle(Theme.text)
                thoughtFor(want)
                Button("Think about it again") { reconsidering = true }
                    .buttonStyle(.wwSecondary)
            case .purchased, .noLongerWant:
                Text(DecisionCopy.outcomeLabel(want.status))
                    .font(.wwTitle2)
                    .foregroundStyle(Theme.text)
                thoughtFor(want)
            }
        }
    }

    @ViewBuilder
    private func thoughtFor(_ want: Want) -> some View {
        if let days = want.thinkingDays(calendar: store.calendar) {
            Text("You thought about it for \(CalendarDays.durationText(days)).")
                .font(.wwCaption)
                .foregroundStyle(Theme.textMuted)
        }
    }

    // MARK: - Menu

    @ToolbarContentBuilder
    private func toolbarMenu(want: Want) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                Button {
                    perform { try store.setVisibleOnDisplay(!want.isVisibleOnDisplay, for: entity) }
                } label: {
                    Label(
                        want.isVisibleOnDisplay ? "Hide from family screen" : "Show on family screen",
                        systemImage: want.isVisibleOnDisplay ? "eye.slash" : "eye"
                    )
                }
                Divider()
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Remove", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("More")
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

/// Vertical history of a Want: added, then each decision.
struct DecisionTimeline: View {
    let entries: [TimelineEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index == entries.count - 1 ? Theme.accent : Theme.textFaint)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        if index < entries.count - 1 {
                            Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text)
                            .font(.wwHeadline)
                            .foregroundStyle(Theme.text)
                        if let newRevisit = entry.newRevisitAt {
                            Text("Until \(Formatting.day(newRevisit))")
                                .font(.wwCaption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        if let note = entry.note {
                            Text("“\(note)”")
                                .font(.wwCaption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.wwLabel)
                            .foregroundStyle(Theme.textFaint)
                    }
                    .padding(.bottom, 18)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Waiting") {
    PreviewWant(status: .waiting) { entity in
        NavigationStack { WantDetailView(entity: entity) }
    }
}

#Preview("Ready") {
    PreviewWant(status: .readyToReconsider) { entity in
        NavigationStack { WantDetailView(entity: entity) }
    }
}
#endif
