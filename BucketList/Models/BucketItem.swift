import Foundation
import SwiftData

enum BucketStatus: String, Codable, CaseIterable, Hashable, Identifiable {
    case done
    case nearFuture
    case todo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: "DONE"
        case .nearFuture: "NEAR FUTURE"
        case .todo: "TODO"
        }
    }
}

@Model
final class BucketItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var emoji: String
    var statusRawValue: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CompletionMemory.item)
    var memory: CompletionMemory?

    var status: BucketStatus {
        get { BucketStatus(rawValue: statusRawValue) ?? .todo }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        emoji: String,
        status: BucketStatus,
        sortOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.statusRawValue = status.rawValue
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
