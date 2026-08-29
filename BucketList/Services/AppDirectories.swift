import Foundation

enum AppDirectories {
    static var photos: URL {
        get throws {
            let root = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = root
                .appending(path: "BucketList", directoryHint: .isDirectory)
                .appending(path: "Photos", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        }
    }
}
