import SwiftData
import SwiftUI

struct ActivityEditorSheet: View {
    let request: ActivityEditorRequest
    let didSave: (BucketItem, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var emoji: String
    @State private var status: BucketStatus
    @State private var errorMessage: String?

    init(
        request: ActivityEditorRequest,
        didSave: @escaping (BucketItem, Bool) -> Void
    ) {
        self.request = request
        self.didSave = didSave
        _title = State(initialValue: request.item?.title ?? "")
        _emoji = State(initialValue: request.item?.emoji ?? "✨")
        _status = State(initialValue: request.item?.status ?? request.initialStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    request.item == nil ? "Add Activity" : "Edit Activity",
                    systemImage: "square.and.pencil"
                )
                .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            Divider()

            Form {
                Section("Activity") {
                    TextField("Emoji", text: $emoji)
                    TextField("What do you want to do?", text: $title)
                }
                Section("Section") {
                    Picker("Section", selection: $status) {
                        ForEach(BucketStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 340)
    }

    private func save() {
        do {
            let previousStatus = request.item?.status
            let item = try BucketStore.save(
                existing: request.item,
                title: title,
                emoji: emoji,
                status: status,
                in: modelContext
            )
            didSave(item, previousStatus != .done && status == .done)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
