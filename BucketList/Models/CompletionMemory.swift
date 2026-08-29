import Foundation
import SwiftData

@Model
final class CompletionMemory {
    @Attribute(.unique) var id: UUID
    var thoughts: String
    var completedOn: Date
    var createdAt: Date
    var item: BucketItem?

    @Relationship(deleteRule: .cascade, inverse: \MemoryPhoto.memory)
    var photos: [MemoryPhoto]

    init(
        id: UUID = UUID(),
        thoughts: String,
        completedOn: Date,
        createdAt: Date = .now,
        item: BucketItem? = nil
    ) {
        self.id = id
        self.thoughts = thoughts
        self.completedOn = completedOn
        self.createdAt = createdAt
        self.item = item
        self.photos = []
    }
}
