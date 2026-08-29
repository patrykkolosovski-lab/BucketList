import Foundation
import SwiftData

enum MemoryMediaKind: String, Codable, CaseIterable {
    case photo
    case video
}

@Model
final class MemoryPhoto {
    @Attribute(.unique) var id: UUID
    var originalFilename: String
    var managedFilename: String
    var mediaKindRawValue: String = MemoryMediaKind.photo.rawValue
    var createdAt: Date
    var memory: CompletionMemory?

    var mediaKind: MemoryMediaKind {
        get { MemoryMediaKind(rawValue: mediaKindRawValue) ?? .photo }
        set { mediaKindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        originalFilename: String,
        managedFilename: String,
        mediaKind: MemoryMediaKind = .photo,
        createdAt: Date = .now,
        memory: CompletionMemory? = nil
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.managedFilename = managedFilename
        self.mediaKindRawValue = mediaKind.rawValue
        self.createdAt = createdAt
        self.memory = memory
    }
}
