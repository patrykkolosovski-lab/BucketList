import SwiftData
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case done
    case nearFuture
    case todo
    case recap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: "DONE"
        case .nearFuture: "NEAR FUTURE"
        case .todo: "TODO"
        case .recap: "RECAP"
        }
    }

    var symbol: String {
        switch self {
        case .done: "checkmark.circle.fill"
        case .nearFuture: "clock.fill"
        case .todo: "list.bullet"
        case .recap: "sparkles"
        }
    }

    var status: BucketStatus? {
        switch self {
        case .done: .done
        case .nearFuture: .nearFuture
        case .todo: .todo
        case .recap: nil
        }
    }
}

struct ActivityEditorRequest: Identifiable {
    let id = UUID()
    let item: BucketItem?
    let initialStatus: BucketStatus
}

struct ContentView: View {
    @Query private var items: [BucketItem]

    @State private var selectedSection: AppSection? = .todo
    @State private var editorRequest: ActivityEditorRequest?
    @State private var completionItem: BucketItem?

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label {
                    HStack {
                        Text(section.title)
                        Spacer()
                        Text("\(count(for: section))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: section.symbol)
                        .foregroundStyle(AppPalette.color(for: section))
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            switch selectedSection ?? .todo {
            case .recap:
                RecapView(
                    items: items,
                    editMemory: { completionItem = $0 }
                )
            case let section:
                ActivityListView(
                    section: section,
                    items: items.filter { $0.status == (section.status ?? .todo) },
                    add: {
                        editorRequest = ActivityEditorRequest(
                            item: nil,
                            initialStatus: section.status ?? .todo
                        )
                    },
                    edit: {
                        editorRequest = ActivityEditorRequest(
                            item: $0,
                            initialStatus: $0.status
                        )
                    },
                    addMemory: { completionItem = $0 }
                )
            }
        }
        .sheet(item: $editorRequest) { request in
            ActivityEditorSheet(request: request) { item, becameDone in
                if becameDone {
                    Task { @MainActor in completionItem = item }
                }
            }
        }
        .sheet(item: $completionItem) { item in
            CompletionEditorSheet(item: item)
        }
    }

    private func count(for section: AppSection) -> Int {
        switch section {
        case .recap:
            items.filter { $0.status == .done && $0.memory != nil }.count
        default:
            items.filter { $0.status == (section.status ?? .todo) }.count
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [BucketItem.self, CompletionMemory.self, MemoryPhoto.self],
            inMemory: true
        )
        .frame(width: 1080, height: 720)
}
