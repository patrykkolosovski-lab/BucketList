import Foundation
import SwiftData

enum BucketStoreError: LocalizedError {
    case emptyTitle
    case emptyEmoji

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Enter something you want to do."
        case .emptyEmoji: "Add an emoji for this activity."
        }
    }
}

@MainActor
enum BucketStore {
    static func save(
        existing item: BucketItem? = nil,
        title: String,
        emoji: String,
        status: BucketStatus,
        in context: ModelContext
    ) throws -> BucketItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw BucketStoreError.emptyTitle }
        guard !cleanEmoji.isEmpty else { throw BucketStoreError.emptyEmoji }

        let bucketItem: BucketItem
        if let item {
            bucketItem = item
        } else {
            let nextOrder = try context.fetch(FetchDescriptor<BucketItem>())
                .filter { $0.status == status }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
            bucketItem = BucketItem(
                title: cleanTitle,
                emoji: cleanEmoji,
                status: status,
                sortOrder: nextOrder
            )
            context.insert(bucketItem)
        }

        let previousStatus = bucketItem.status
        bucketItem.title = cleanTitle
        bucketItem.emoji = cleanEmoji
        bucketItem.status = status
        if previousStatus != status {
            bucketItem.sortOrder = try nextOrder(for: status, in: context)
        }
        try context.save()
        return bucketItem
    }

    static func changeStatus(
        _ item: BucketItem,
        to status: BucketStatus,
        in context: ModelContext
    ) throws {
        guard item.status != status else { return }
        item.status = status
        item.sortOrder = try nextOrder(for: status, in: context)
        try context.save()
    }

    static func move(
        _ item: BucketItem,
        direction: Int,
        among items: [BucketItem],
        in context: ModelContext
    ) throws {
        let sorted = items.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.createdAt < $1.createdAt
                : $0.sortOrder < $1.sortOrder
        }
        guard let index = sorted.firstIndex(where: { $0.id == item.id }) else { return }
        let targetIndex = index + direction
        guard sorted.indices.contains(targetIndex) else { return }
        let target = sorted[targetIndex]
        let oldOrder = item.sortOrder
        item.sortOrder = target.sortOrder
        target.sortOrder = oldOrder
        try context.save()
    }

    static func saveMemory(
        for item: BucketItem,
        thoughts: String,
        completedOn: Date,
        in context: ModelContext
    ) throws -> CompletionMemory {
        let memory = item.memory ?? CompletionMemory(
            thoughts: "",
            completedOn: completedOn,
            item: item
        )
        memory.thoughts = thoughts.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.completedOn = completedOn
        memory.item = item
        item.memory = memory
        item.status = .done
        if memory.modelContext == nil {
            context.insert(memory)
        }
        try context.save()
        return memory
    }

    static func delete(_ item: BucketItem, from context: ModelContext) throws {
        let filenames = item.memory?.photos.map(\.managedFilename) ?? []
        context.delete(item)
        try context.save()
        try removeManagedFiles(filenames)
    }

    static func deleteMemory(
        _ memory: CompletionMemory,
        from context: ModelContext
    ) throws {
        let filenames = memory.photos.map(\.managedFilename)
        memory.item?.memory = nil
        context.delete(memory)
        try context.save()
        try removeManagedFiles(filenames)
    }

    private static func nextOrder(
        for status: BucketStatus,
        in context: ModelContext
    ) throws -> Int {
        try context.fetch(FetchDescriptor<BucketItem>())
            .filter { $0.status == status }
            .map(\.sortOrder)
            .max()
            .map { $0 + 1 } ?? 0
    }

    private static func removeManagedFiles(_ filenames: [String]) throws {
        guard !filenames.isEmpty else { return }
        let directory = try AppDirectories.photos
        for filename in filenames {
            let url = directory.appending(path: filename)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
