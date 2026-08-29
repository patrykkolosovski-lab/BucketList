import AppKit
import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct PendingMedia: Identifiable {
    let id = UUID()
    let originalFilename: String
    let mediaKind: MemoryMediaKind
    let data: Data?
    let stagedURL: URL?

    init(
        originalFilename: String,
        data: Data,
        mediaKind: MemoryMediaKind
    ) {
        self.originalFilename = originalFilename
        self.mediaKind = mediaKind
        self.data = data
        self.stagedURL = nil
    }

    init(
        originalFilename: String,
        stagedURL: URL,
        mediaKind: MemoryMediaKind
    ) {
        self.originalFilename = originalFilename
        self.mediaKind = mediaKind
        self.data = nil
        self.stagedURL = stagedURL
    }

    var image: NSImage? {
        if let data { return NSImage(data: data) }
        if let stagedURL { return NSImage(contentsOf: stagedURL) }
        return nil
    }

    var isEmpty: Bool {
        if let data { return data.isEmpty }
        guard let stagedURL,
              let values = try? stagedURL.resourceValues(forKeys: [.fileSizeKey]) else {
            return true
        }
        return (values.fileSize ?? 0) == 0
    }

    func write(to targetURL: URL) throws {
        if let data {
            try data.write(to: targetURL, options: [.atomic])
        } else if let stagedURL {
            try FileManager.default.copyItem(at: stagedURL, to: targetURL)
        } else {
            throw ManagedPhotoError.unreadable(originalFilename)
        }
    }

    func removeStagedFile() {
        guard let stagedURL,
              FileManager.default.fileExists(atPath: stagedURL.path) else { return }
        try? FileManager.default.removeItem(at: stagedURL)
    }
}

struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let target = try ManagedPhotoStore.makeStagingURL(
                fileExtension: received.file.pathExtension.isEmpty
                    ? "mov"
                    : received.file.pathExtension
            )
            try FileManager.default.copyItem(at: received.file, to: target)
            return PickedVideoFile(url: target)
        }
    }
}

enum ManagedPhotoError: LocalizedError {
    case unreadable(String)
    case unsupported(String)
    case invalidMedia(String)

    var errorDescription: String? {
        switch self {
        case let .unreadable(filename): "Could not read \(filename)."
        case let .unsupported(filename): "\(filename) is not a supported photo or video."
        case let .invalidMedia(filename): "\(filename) could not be opened as media."
        }
    }
}

@MainActor
enum ManagedPhotoStore {
    static func payload(from url: URL) throws -> PendingMedia {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                ?? UTType(filenameExtension: url.pathExtension)
            let mediaKind: MemoryMediaKind
            if contentType?.conforms(to: .image) == true {
                mediaKind = .photo
            } else if contentType?.conforms(to: .movie) == true {
                mediaKind = .video
            } else {
                throw ManagedPhotoError.unsupported(url.lastPathComponent)
            }

            let target = try makeStagingURL(
                fileExtension: url.pathExtension.isEmpty
                    ? (mediaKind == .video ? "mov" : "jpg")
                    : url.pathExtension
            )
            try FileManager.default.copyItem(at: url, to: target)
            return PendingMedia(
                originalFilename: url.lastPathComponent,
                stagedURL: target,
                mediaKind: mediaKind
            )
        } catch let error as ManagedPhotoError {
            throw error
        } catch {
            throw ManagedPhotoError.unreadable(url.lastPathComponent)
        }
    }

    static func importMedia(
        _ payloads: [PendingMedia],
        into memory: CompletionMemory,
        in context: ModelContext,
        directory: URL? = nil
    ) throws {
        guard !payloads.isEmpty else { return }
        let targetDirectory: URL
        if let directory {
            targetDirectory = directory
        } else {
            targetDirectory = try AppDirectories.photos
        }
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        var writtenURLs: [URL] = []

        do {
            for payload in payloads {
                if payload.mediaKind == .photo, payload.image == nil {
                    throw ManagedPhotoError.invalidMedia(payload.originalFilename)
                }
                if payload.mediaKind == .video, payload.isEmpty {
                    throw ManagedPhotoError.invalidMedia(payload.originalFilename)
                }
                let fileExtension = preferredExtension(for: payload)
                let managedFilename = "\(UUID().uuidString).\(fileExtension)"
                let targetURL = targetDirectory.appending(path: managedFilename)
                try payload.write(to: targetURL)
                writtenURLs.append(targetURL)
                let photo = MemoryPhoto(
                    originalFilename: payload.originalFilename,
                    managedFilename: managedFilename,
                    mediaKind: payload.mediaKind,
                    memory: memory
                )
                memory.photos.append(photo)
                context.insert(photo)
            }
            try context.save()
            payloads.forEach { $0.removeStagedFile() }
        } catch {
            writtenURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            context.rollback()
            throw error
        }
    }

    static func remove(
        _ photo: MemoryPhoto,
        from context: ModelContext,
        directory: URL? = nil
    ) throws {
        let targetDirectory: URL
        if let directory {
            targetDirectory = directory
        } else {
            targetDirectory = try AppDirectories.photos
        }
        let fileURL = targetDirectory.appending(path: photo.managedFilename)
        context.delete(photo)
        try context.save()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    static func fileURL(for photo: MemoryPhoto) -> URL? {
        guard let directory = try? AppDirectories.photos else { return nil }
        let url = directory.appending(path: photo.managedFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func importPhotos(
        _ payloads: [PendingMedia],
        into memory: CompletionMemory,
        in context: ModelContext,
        directory: URL? = nil
    ) throws {
        try importMedia(payloads, into: memory, in: context, directory: directory)
    }

    private static func preferredExtension(for payload: PendingMedia) -> String {
        let sourceExtension = URL(fileURLWithPath: payload.originalFilename).pathExtension
        if !sourceExtension.isEmpty { return sourceExtension.lowercased() }
        return payload.mediaKind == .video ? "mov" : "png"
    }

    nonisolated static func makeStagingURL(fileExtension: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BucketListMediaImports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appending(path: "\(UUID().uuidString).\(fileExtension.lowercased())")
    }
}
