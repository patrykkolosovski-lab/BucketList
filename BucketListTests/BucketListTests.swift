import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import BucketList

@MainActor
final class BucketListTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: BucketItem.self,
            CompletionMemory.self,
            MemoryPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testSeedContainsSuppliedActivitiesAndDoneItems() throws {
        let suiteName = "BucketListTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try SeedService.seedIfNeeded(in: context, defaults: defaults)
        try SeedService.seedIfNeeded(in: context, defaults: defaults)

        let items = try context.fetch(FetchDescriptor<BucketItem>())
        XCTAssertEqual(items.count, 25)
        XCTAssertEqual(items.filter { $0.status == .done }.count, 2)
        XCTAssertEqual(Set(items.map(\.id)).count, 25)
    }

    func testSavingAndMovingActivity() throws {
        let item = try BucketStore.save(
            title: "Zobaczyć zorzę",
            emoji: "🌌",
            status: .nearFuture,
            in: context
        )

        XCTAssertEqual(item.status, .nearFuture)
        try BucketStore.changeStatus(item, to: .done, in: context)
        XCTAssertEqual(item.status, .done)
    }

    func testEmptyActivityIsRejected() {
        XCTAssertThrowsError(
            try BucketStore.save(
                title: "  ",
                emoji: "✨",
                status: .todo,
                in: context
            )
        )
    }

    func testCompletionMemoryBelongsToDoneItem() throws {
        let item = try BucketStore.save(
            title: "Nurkowanie",
            emoji: "🤿",
            status: .todo,
            in: context
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let memory = try BucketStore.saveMemory(
            for: item,
            thoughts: "Niezapomniane.",
            completedOn: date,
            in: context
        )

        XCTAssertEqual(item.status, .done)
        XCTAssertEqual(item.memory?.id, memory.id)
        XCTAssertEqual(memory.thoughts, "Niezapomniane.")
        XCTAssertEqual(memory.completedOn, date)
    }

    func testManagedPhotoIsCopiedAndRemoved() throws {
        let item = try BucketStore.save(
            title: "Biwak",
            emoji: "🏕️",
            status: .done,
            in: context
        )
        let memory = try BucketStore.saveMemory(
            for: item,
            thoughts: "",
            completedOn: .now,
            in: context
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        let data = try XCTUnwrap(
            image.tiffRepresentation
                .flatMap(NSBitmapImageRep.init(data:))?
                .representation(using: .png, properties: [:])
        )

        try ManagedPhotoStore.importMedia(
            [
                PendingMedia(
                    originalFilename: "memory.png",
                    data: data,
                    mediaKind: .photo
                )
            ],
            into: memory,
            in: context,
            directory: directory
        )
        let photo = try XCTUnwrap(memory.photos.first)
        let fileURL = directory.appending(path: photo.managedFilename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try ManagedPhotoStore.remove(photo, from: context, directory: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testManagedVideoMetadataIsStoredAndRemoved() throws {
        let item = try BucketStore.save(
            title: "Lot szybowcem",
            emoji: "🛩️",
            status: .done,
            in: context
        )
        let memory = try BucketStore.saveMemory(
            for: item,
            thoughts: "Widok ponad chmurami.",
            completedOn: .now,
            in: context
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let stagedURL = try ManagedPhotoStore.makeStagingURL(fileExtension: "mov")
        try Data("test-video-payload".utf8).write(to: stagedURL, options: .atomic)

        try ManagedPhotoStore.importMedia(
            [
                PendingMedia(
                    originalFilename: "flight.mov",
                    stagedURL: stagedURL,
                    mediaKind: .video
                )
            ],
            into: memory,
            in: context,
            directory: directory
        )

        let video = try XCTUnwrap(memory.photos.first)
        XCTAssertEqual(video.mediaKind, .video)
        XCTAssertTrue(video.managedFilename.hasSuffix(".mov"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
        let fileURL = directory.appending(path: video.managedFilename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try ManagedPhotoStore.remove(video, from: context, directory: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testMainWindowRendersAtCommonSizes() throws {
        let suiteName = "BucketListRenderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try SeedService.seedIfNeeded(in: context, defaults: defaults)

        let outputDirectory = FileManager.default.temporaryDirectory
            .appending(path: "BucketListSnapshots", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for size in [NSSize(width: 900, height: 600), NSSize(width: 1200, height: 780)] {
            let rootView = ContentView()
                .modelContainer(container)
            let hostingView = NSHostingView(rootView: rootView)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.setContentSize(size)
            window.makeKeyAndOrderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            let filename = "main-\(Int(size.width))x\(Int(size.height)).png"
            try png.write(to: outputDirectory.appending(path: filename), options: .atomic)
            XCTAssertGreaterThan(png.count, 20_000)
            window.orderOut(nil)
        }
    }

    func testRecapFeedRendersFullEntryVertically() throws {
        let item = try BucketStore.save(
            title: "Skok ze spadochronem",
            emoji: "🪂",
            status: .done,
            in: context
        )
        let memory = try BucketStore.saveMemory(
            for: item,
            thoughts: "Pierwsze sekundy były pełne adrenaliny. Potem wszystko zwolniło: widok, cisza i ogromna radość. To wspomnienie chcę zachować w całości, razem ze wszystkimi drobnymi szczegółami tego dnia.",
            completedOn: Date(timeIntervalSince1970: 1_750_000_000),
            in: context
        )

        let directory = try AppDirectories.photos
        let filenames = ["test-\(UUID().uuidString).png", "test-\(UUID().uuidString).png"]
        defer {
            for filename in filenames {
                try? FileManager.default.removeItem(at: directory.appending(path: filename))
            }
        }

        for (index, filename) in filenames.enumerated() {
            let image = NSImage(size: NSSize(width: 800, height: index == 0 ? 520 : 680))
            image.lockFocus()
            (index == 0 ? NSColor.systemOrange : NSColor.systemBlue).setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.unlockFocus()
            let data = try XCTUnwrap(
                image.tiffRepresentation
                    .flatMap(NSBitmapImageRep.init(data:))?
                    .representation(using: .png, properties: [:])
            )
            try data.write(to: directory.appending(path: filename), options: .atomic)
            let media = MemoryPhoto(
                originalFilename: filename,
                managedFilename: filename,
                mediaKind: .photo,
                createdAt: Date().addingTimeInterval(Double(index)),
                memory: memory
            )
            memory.photos.append(media)
            context.insert(media)
        }
        try context.save()

        let size = NSSize(width: 900, height: 1050)
        let rootView = RecapView(items: [item], editMemory: { _ in })
            .modelContainer(container)
        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let outputDirectory = FileManager.default.temporaryDirectory
            .appending(path: "BucketListSnapshots", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try png.write(to: outputDirectory.appending(path: "recap-feed.png"), options: .atomic)
        XCTAssertGreaterThan(png.count, 20_000)
        window.orderOut(nil)
    }
}
