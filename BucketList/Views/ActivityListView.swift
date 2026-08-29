import SwiftData
import SwiftUI

struct ActivityListView: View {
    let section: AppSection
    let items: [BucketItem]
    let add: () -> Void
    let edit: (BucketItem) -> Void
    let addMemory: (BucketItem) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var itemPendingDeletion: BucketItem?
    @State private var errorMessage: String?

    private var sortedItems: [BucketItem] {
        items.sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.createdAt < $1.createdAt
                : $0.sortOrder < $1.sortOrder
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: section.symbol
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        activityRow(item, index: index)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "Delete this activity?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let itemPendingDeletion else { return }
                perform { try BucketStore.delete(itemPendingDeletion, from: modelContext) }
                self.itemPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its completion memory and managed photos and videos will also be removed.")
        }
        .alert("Unable to update activity", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack {
            Label(section.title, systemImage: section.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppPalette.color(for: section))
            Text("\(sortedItems.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: add) {
                Label("Add", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(18)
    }

    private func activityRow(_ item: BucketItem, index: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleDone(item)
            } label: {
                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        item.status == .done ? AppPalette.done : Color.secondary
                    )
            }
            .buttonStyle(.plain)
            .help(item.status == .done ? "Move to TODO" : "Mark as done")

            Text(item.emoji)
                .font(.title2)
                .frame(width: 32, height: 32)

            Text(item.title)
                .font(.body)
                .lineLimit(2)

            Spacer()

            if item.status == .done {
                Button {
                    addMemory(item)
                } label: {
                    Image(systemName: item.memory == nil ? "book.closed" : "book.fill")
                }
                .buttonStyle(.plain)
                .help(item.memory == nil ? "Add completion entry" : "Edit completion entry")
            }

            Menu {
                ForEach(BucketStatus.allCases) { status in
                    Button {
                        move(item, to: status)
                    } label: {
                        if item.status == status {
                            Label(status.title, systemImage: "checkmark")
                        } else {
                            Text(status.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help("Move to another section")

            Button {
                perform {
                    try BucketStore.move(
                        item,
                        direction: -1,
                        among: sortedItems,
                        in: modelContext
                    )
                }
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .help("Move up")

            Button {
                perform {
                    try BucketStore.move(
                        item,
                        direction: 1,
                        among: sortedItems,
                        in: modelContext
                    )
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(index == sortedItems.count - 1)
            .help("Move down")

            Button {
                edit(item)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit activity")

            Button(role: .destructive) {
                itemPendingDeletion = item
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Delete activity")
        }
        .padding(.vertical, 7)
        .contextMenu {
            Button("Edit") { edit(item) }
            if item.status == .done {
                Button(item.memory == nil ? "Add Entry" : "Edit Entry") {
                    addMemory(item)
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                itemPendingDeletion = item
            }
        }
    }

    private func toggleDone(_ item: BucketItem) {
        if item.status == .done {
            move(item, to: .todo)
        } else {
            move(item, to: .done)
        }
    }

    private func move(_ item: BucketItem, to status: BucketStatus) {
        let becameDone = item.status != .done && status == .done
        perform {
            try BucketStore.changeStatus(item, to: status, in: modelContext)
        }
        if becameDone, errorMessage == nil {
            addMemory(item)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
