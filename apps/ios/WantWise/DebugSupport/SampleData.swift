#if DEBUG
import Foundation
import SwiftData
import WantWiseCore

/// Realistic sample Wants for the Simulator and previews. DEBUG builds only; the sample images
/// (`debug-sample-*.png`) are excluded from Release builds (project.yml, D-027).
///
/// Load with the `-WantWiseSampleData` launch argument or the ladybug menu on the home screen.
@MainActor
enum SampleData {
    struct Sample {
        var title: String
        var image: String?
        var sourceType: SourceType = .screenshot
        var priceMinor: Int?
        var reason: String?
        var similar: SimilarItemAnswer?
        var productURL: String?
        var createdDaysAgo: Int
        /// Days from today's revisit slot; negative = already past; nil = still `captured`.
        var revisitInDays: Int?
        /// (decision, days ago), applied in order.
        var decisions: [(DecisionKind, Int)] = []
        var isVisibleOnDisplay = true
    }

    static let samples: [Sample] = [
        Sample(title: "Wireless headphones", image: "debug-sample-headphones", priceMinor: 4900,
               reason: "Mine hurt my ears", similar: .yes, createdDaysAgo: 2, revisitInDays: 5),
        Sample(title: "NeeDoh Nice Cube", image: "debug-sample-squish-cube", priceMinor: 1200,
               reason: "I love this design", similar: .no, createdDaysAgo: 6, revisitInDays: 1),
        Sample(title: "Alcohol marker art set", image: "debug-sample-art-set", priceMinor: 3200,
               reason: "I want better markers for my comics", similar: .yes, createdDaysAgo: 18, revisitInDays: 12),
        Sample(title: "Kart racing game", image: "debug-sample-kart-game", priceMinor: 7999,
               reason: "My friends play it online after school", similar: .no, createdDaysAgo: 7, revisitInDays: -1),
        Sample(title: "Cruiser skateboard", image: "debug-sample-skateboard-photo", sourceType: .photo, priceMinor: 7499,
               reason: "To ride to the park with Jordan", similar: .notSure, createdDaysAgo: 4, revisitInDays: 26),
        Sample(title: "Glow-in-the-dark star projector", image: "debug-sample-star-projector-link", sourceType: .sharedURL,
               priceMinor: 2999, productURL: "https://starnight-shop.example/projector", createdDaysAgo: 0, revisitInDays: nil),
        Sample(title: "Space station building set", image: "debug-sample-building-set", priceMinor: 8999,
               reason: "I could build it on the weekend", similar: .no, createdDaysAgo: 3, revisitInDays: 0),
        Sample(title: "Birthday surprise for Mom", sourceType: .manual, priceMinor: 2500, reason: "It's a secret!",
               createdDaysAgo: 1, revisitInDays: 9, isVisibleOnDisplay: false),
        Sample(title: "Light-up sneakers", sourceType: .manual, priceMinor: 6500, reason: "They look cool",
               similar: .yes, createdDaysAgo: 20, revisitInDays: -13, decisions: [(.waitLonger, 13), (.noLongerWant, 9)]),
        Sample(title: "Drawing tablet", sourceType: .manual, priceMinor: 12999, reason: "To draw digital comics",
               similar: .no, createdDaysAgo: 30, revisitInDays: -16, decisions: [(.stillWant, 16)]),
        Sample(title: "Sticker water bottle", sourceType: .manual, priceMinor: 2400, reason: "Mine leaks",
               similar: .yes, createdDaysAgo: 25, revisitInDays: -15, decisions: [(.stillWant, 15), (.purchased, 12)]),
    ]

    static func loadIfEmpty(into store: WantStore) {
        guard (try? store.liveWants().isEmpty) == true else { return }
        load(into: store)
    }

    static func load(into store: WantStore) {
        for sample in samples {
            do {
                try store.debugInsert(sample)
            } catch {
                print("SampleData: couldn't insert \(sample.title): \(error)")
            }
        }
        store.syncReminders()
    }
}

extension WantStore {
    /// Inserts a sample directly, back-dating it. Bypasses the "revisit must be in the future" rule on purpose.
    func debugInsert(_ sample: SampleData.Sample) throws {
        let now = clock()
        let child = try currentChild()
        let id = UUID()
        let createdAt = calendar.date(byAdding: .day, value: -sample.createdDaysAgo, to: now)!.addingTimeInterval(-2 * 3600)

        var imageFilename: String?
        if let name = sample.image,
           let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            imageFilename = try images.save(data, for: id)
        }

        let revisitAt = sample.revisitInDays.map { policy.revisitDate(afterDays: $0, from: now, calendar: calendar) }
        var want = Want(
            id: id,
            childId: child.id,
            title: sample.title,
            productURL: sample.productURL,
            imageFilename: imageFilename,
            sourceType: sample.sourceType,
            priceMinor: sample.priceMinor,
            currency: child.defaultCurrency,
            reason: sample.reason,
            similarItemAnswer: sample.similar,
            status: revisitAt == nil ? .captured : .waiting,
            revisitAt: revisitAt,
            waitStartedAt: revisitAt == nil ? nil : createdAt,
            isVisibleOnDisplay: sample.isVisibleOnDisplay,
            createdAt: createdAt
        )
        let entity = WantEntity(want)
        context.insert(entity)

        for (kind, daysAgo) in sample.decisions {
            let at = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let newRevisit = kind == .waitLonger ? policy.revisitDate(afterDays: 4, from: at, calendar: calendar) : nil
            let outcome = try want.deciding(kind, newRevisitAt: newRevisit, now: at)
            want = outcome.want
            context.insert(WantDecisionEntity(outcome.decision, want: entity))
        }
        entity.apply(want)
        try context.save()
    }

    /// Makes the soonest waiting Want ready to reconsider right now.
    func debugMakeOneReady() {
        guard let entity = try? liveWants()
            .filter({ $0.snapshot.phase(now: clock()) == .waiting })
            .min(by: { ($0.revisitAt ?? .distantFuture) < ($1.revisitAt ?? .distantFuture) }) else { return }
        entity.revisitAt = clock().addingTimeInterval(-60)
        entity.updatedAt = clock()
        try? context.save()
        appBecameActive()
    }

    /// Schedules a real reminder 10 seconds from now for the soonest waiting Want. Background the app to see it.
    func debugReminderSoon() async {
        guard let want = try? liveWants().map(\.snapshot).first(where: { $0.status == .waiting }) else { return }
        await reminders.requestPermissionIfNeeded()
        let reminder = PlannedReminder(
            id: "debug-\(want.id.uuidString)",
            wantId: want.id,
            fireAt: clock().addingTimeInterval(10),
            title: "Still thinking about this?",
            body: "You added “\(want.displayTitle)” a while ago. Take another look."
        )
        try? await SystemNotificationCenter().add(reminder, calendar: calendar)
    }

    /// Hard-deletes every Want, decision and image. DEBUG only; the real app only soft-deletes.
    func debugDeleteEverything() {
        if let wants = try? context.fetch(FetchDescriptor<WantEntity>()) {
            for want in wants {
                if let name = want.imageFilename { try? images.delete(name) }
                context.delete(want)
            }
        }
        try? context.save()
        syncReminders()
    }
}
#endif
