import Foundation
import SwiftData

@MainActor
enum SeedService {
    private static let seedKey = "BucketList.didSeed.v2"

    static func seedIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        guard !defaults.bool(forKey: seedKey) else { return }

        let existingItems = try context.fetch(FetchDescriptor<BucketItem>())
        var existingTitles = Set(existingItems.map { normalized($0.title) })
        var nextOrders: [BucketStatus: Int] = [:]
        for status in BucketStatus.allCases {
            nextOrders[status] = existingItems
                .filter { $0.status == status }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
        }

        for seed in seeds where !existingTitles.contains(normalized(seed.title)) {
            let status: BucketStatus = seed.isDone ? .done : .todo
            context.insert(
                BucketItem(
                    title: seed.title,
                    emoji: seed.emoji,
                    status: status,
                    sortOrder: nextOrders[status] ?? 0
                )
            )
            nextOrders[status, default: 0] += 1
            existingTitles.insert(normalized(seed.title))
        }
        try context.save()
        defaults.set(true, forKey: seedKey)
    }

    private static func normalized(_ title: String) -> String {
        title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let seeds: [(emoji: String, title: String, isDone: Bool)] = [
        ("🧊", "Morsowanie", false),
        ("🪂", "Skok ze spadochronem", false),
        ("🧗", "Skok na bungee", true),
        ("🌊", "Skakanie do wody", false),
        ("🪂", "Paralotniarstwo", false),
        ("🪁", "Kitesurfing", false),
        ("🌊", "Rafting Górski", false),
        ("🧗", "Wspinaczka skałkowa z asekuracją", false),
        ("🏔️", "Wejście na wymagający szczyt", false),
        ("🎿", "Jazda na nartach", false),
        ("🏂", "Snowboarding", false),
        ("🏎️", "Jazda sportowym autem na torze", false),
        ("🏁", "Gokarty", false),
        ("🏍️", "Motocross", false),
        ("🎢", "Duży rollercoaster", true),
        ("✈️", "Lot akrobacyjny z pilotem", false),
        ("🛩️", "Lot szybowcem", false),
        ("🏄", "Wakeboarding", false),
        ("⛵", "Żeglowanie", false),
        ("🤿", "Nurkowanie", false),
        ("🌊", "Canyoning", false),
        ("🌅", "Góry", false),
        ("🏕️", "Biwak", false),
        ("🏃", "Runmageddon", false),
        ("🚤", "Jetski", false)
    ]
}
