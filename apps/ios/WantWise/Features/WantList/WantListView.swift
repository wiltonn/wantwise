import SwiftData
import SwiftUI
import WantWiseCore

/// Home: everything the child is thinking about, image-first.
///
/// Order: ready to think again (big cards) → finish adding (quick captures) → thinking about (grid).
/// Decided Wants live in the Decided tab.
struct WantListView: View {
    @Environment(WantStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<WantEntity> { $0.deletedAt == nil }, sort: \WantEntity.createdAt, order: .reverse)
    private var entities: [WantEntity]

    @State private var showingAdd = false
    @State private var reconsidering: WantEntity?
    @State private var finishing: WantEntity?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let now = store.displayNow
        let sections = WantSections(entities.map(\.snapshot), now: now)
        let byId = Dictionary(entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let active = sections.ready.count + sections.needsReflection.count + sections.waiting.count

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header(active: active, ready: sections.ready.count)

                if active == 0 {
                    EmptyWantsView { showingAdd = true }
                }

                if !sections.ready.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel("Ready to think again")
                        ForEach(sections.ready) { want in
                            if let entity = byId[want.id] {
                                ReadyWantCard(want: want, imageURL: store.imageURL(for: entity), now: now, calendar: store.calendar) {
                                    reconsidering = entity
                                }
                            }
                        }
                    }
                }

                if !sections.needsReflection.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Finish adding")
                        ForEach(sections.needsReflection) { want in
                            if let entity = byId[want.id] {
                                CapturedWantRow(want: want, imageURL: store.imageURL(for: entity)) { finishing = entity }
                            }
                        }
                    }
                }

                if !sections.waiting.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel("Thinking about")
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(sections.waiting) { want in
                                NavigationLink(value: WantRoute(id: want.id)) {
                                    WantGridCard(
                                        want: want,
                                        imageURL: byId[want.id].flatMap(store.imageURL(for:)),
                                        now: now,
                                        calendar: store.calendar
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if active > 0 { AddWantFloatingButton { showingAdd = true } }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) { AddWantView() }
        .sheet(item: $finishing) { FinishAddingView(entity: $0) }
        .fullScreenCover(item: $reconsidering) { ReconsiderView(entity: $0) }
        .onChange(of: router.reconsiderWantId, initial: true) { _, id in
            guard let id, let entity = byId[id] else { return }
            router.reconsiderWantId = nil
            if entity.snapshot.phase(now: store.displayNow) == .readyToReconsider { reconsidering = entity }
        }
    }

    private func header(active: Int, ready: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Thinking about")
                    .font(.wwDisplay)
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
                if active > 0 {
                    Text(ready > 0 ? "\(ready) ready to think again" : "Take your time.")
                        .font(.wwCaption)
                        .foregroundStyle(ready > 0 ? Theme.accent : Theme.textMuted)
                }
            }
            Spacer()
            #if DEBUG
            DebugMenu()
            #endif
        }
        .padding(.top, 12)
    }
}

// MARK: - Cards

/// Large card for a Want whose waiting time is over.
struct ReadyWantCard: View {
    let want: Want
    let imageURL: URL?
    let now: Date
    let calendar: Calendar
    let onThink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType, style: .poster)
                .frame(height: 240)
            VStack(alignment: .leading, spacing: 12) {
                StatusChip(want: want, now: now, calendar: calendar)
                Text(want.displayTitle)
                    .font(.wwTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text("You added this \(CalendarDays.agoText(since: want.createdAt, now: now, calendar: calendar)).")
                    .font(.wwCaption)
                    .foregroundStyle(Theme.textMuted)
                Button("Think about it", action: onThink)
                    .buttonStyle(.wwPrimary)
                    .padding(.top, 4)
                    .accessibilityIdentifier("thinkAboutIt")
            }
            .padding(20)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous).strokeBorder(Theme.accent.opacity(0.35)))
    }
}

/// Grid card: tall image (screenshots look natural), title, price, countdown, progress.
struct WantGridCard: View {
    let want: Want
    let imageURL: URL?
    let now: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType) }
                .clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text(want.displayTitle)
                    .font(.wwHeadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2, reservesSpace: true)
                if let price = Formatting.price(want.price) {
                    Text(price)
                        .font(.wwCaption)
                        .foregroundStyle(Theme.textMuted)
                }
                StatusChip(want: want, now: now, calendar: calendar)
                if let progress = want.waitProgress(now: now) {
                    WaitProgressBar(progress: progress, height: 4)
                }
            }
            .padding(14)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).strokeBorder(Theme.line))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wantCard")
    }
}

/// A quick capture (e.g. from the Share Extension) that still needs a reason and a waiting time.
struct CapturedWantRow: View {
    let want: Want
    let imageURL: URL?
    let onFinish: () -> Void

    var body: some View {
        Button(action: onFinish) {
            HStack(spacing: 16) {
                WantArtwork(imageURL: imageURL, title: want.displayTitle, sourceType: want.sourceType, maxPixelSize: 300)
                    .frame(width: 64, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(want.displayTitle)
                        .font(.wwHeadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Text("Choose how long to think")
                        .font(.wwCaption)
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(12)
            .frame(minHeight: Theme.touchTarget)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyWantsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Seen something you want?")
                .font(.wwTitle)
                .foregroundStyle(Theme.text)
            Text("Add it here and give it some thinking time. A screenshot or photo works great.")
                .font(.wwBody)
                .foregroundStyle(Theme.textMuted)
            Button(action: onAdd) {
                Label("Add a Want", systemImage: "plus")
            }
            .buttonStyle(.wwPrimary)
            .padding(.top, 8)
            .accessibilityIdentifier("addWant")
        }
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
    }
}

struct AddWantFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add a Want", systemImage: "plus")
                .font(.wwHeadline)
                .padding(.horizontal, 28)
                .frame(minHeight: Theme.touchTarget)
                .foregroundStyle(Theme.accentInk)
                .background(Theme.accent, in: Capsule())
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
        .accessibilityIdentifier("addWant")
    }
}

#if DEBUG
#Preview("Thinking about") {
    NavigationStack { WantListView() }
        .previewEnvironment(sample: true)
}

#Preview("Empty") {
    NavigationStack { WantListView() }
        .previewEnvironment(sample: false)
}
#endif
