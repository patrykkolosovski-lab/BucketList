import SwiftData
import SwiftUI

@main
struct BucketListApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            BucketItem.self,
            CompletionMemory.self,
            MemoryPhoto.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema)
            try SeedService.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            fatalError("Unable to start BucketList: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        Window("BucketList", id: "main") {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
    }
}
