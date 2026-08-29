import AppKit
import AVFoundation
import AVKit
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CompletionEditorSheet: View {
    let item: BucketItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var thoughts: String
    @State private var completedOn: Date
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var pendingMedia: [PendingMedia] = []
    @State private var isImporting = false
    @State private var showsFileImporter = false
    @State private var mediaPendingRemoval: MemoryPhoto?
    @State private var previewMedia: MediaPreview?
    @State private var errorMessage: String?

    init(item: BucketItem) {
        self.item = item
        _thoughts = State(initialValue: item.memory?.thoughts ?? "")
        _completedOn = State(initialValue: item.memory?.completedOn ?? .now)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    activityHeader

                    DatePicker(
                        "Completed on",
                        selection: $completedOn,
                        displayedComponents: .date
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your thoughts")
                            .font(.headline)
                        TextEditor(text: $thoughts)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 150)
                            .background(
                                Color(nsColor: .textBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor))
                            }
                    }

                    mediaSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 580, idealHeight: 700)
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                pendingMedia.append(contentsOf: try urls.map(ManagedPhotoStore.payload))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPickerItems) { _, newItems in
            Task { await loadPickerItems(newItems) }
        }
        .onDisappear {
            pendingMedia.forEach { $0.removeStagedFile() }
        }
        .confirmationDialog(
            "Remove this \(mediaPendingRemoval?.mediaKind == .video ? "video" : "photo")?",
            isPresented: Binding(
                get: { mediaPendingRemoval != nil },
                set: { if !$0 { mediaPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { removeSelectedMedia() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app's managed copy will be deleted.")
        }
        .sheet(item: $previewMedia) { MediaPreviewSheet(media: $0) }
        .alert("Unable to save entry", isPresented: Binding(
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
            Label(
                item.memory == nil ? "Add Completion Entry" : "Edit Completion Entry",
                systemImage: "book.pages"
            )
            .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(isImporting)
        }
        .padding(16)
    }

    private var activityHeader: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 38))
                .frame(width: 52, height: 52)
                .background(
                    AppPalette.done.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                Text("A moment worth remembering")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos & Videos")
                    .font(.headline)
                Text("\(existingMedia.count + pendingMedia.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                PhotosPicker(
                    selection: $selectedPickerItems,
                    maxSelectionCount: nil,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("Media Library", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    showsFileImporter = true
                } label: {
                    Label("Choose Files", systemImage: "folder")
                }
            }

            if existingMedia.isEmpty && pendingMedia.isEmpty {
                ContentUnavailableView(
                    "No media yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Add any number of photos and videos.")
                )
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 142), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(existingMedia) { media in
                        ZStack(alignment: .topTrailing) {
                            ManagedMediaThumbnail(media: media)
                                .onTapGesture { openPreview(for: media) }
                            removeButton { mediaPendingRemoval = media }
                        }
                    }
                    ForEach(pendingMedia) { media in
                        ZStack(alignment: .topTrailing) {
                            PendingMediaThumbnail(media: media)
                            removeButton {
                                media.removeStagedFile()
                                pendingMedia.removeAll { $0.id == media.id }
                            }
                        }
                    }
                }
            }

            if isImporting {
                ProgressView("Preparing selected media...")
                    .controlSize(.small)
            }
        }
    }

    private var existingMedia: [MemoryPhoto] {
        (item.memory?.photos ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.68))
                .font(.title3)
        }
        .buttonStyle(.plain)
        .padding(6)
        .help("Remove media")
    }

    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isImporting = true
        defer {
            isImporting = false
            selectedPickerItems = []
        }

        do {
            for (index, pickerItem) in items.enumerated() {
                let contentType = pickerItem.supportedContentTypes.first
                let kind: MemoryMediaKind = contentType?.conforms(to: .movie) == true
                    ? .video
                    : .photo
                let fileExtension = contentType?.preferredFilenameExtension
                    ?? (kind == .video ? "mov" : "jpg")
                if kind == .video {
                    guard let video = try await pickerItem.loadTransferable(
                        type: PickedVideoFile.self
                    ) else {
                        throw ManagedPhotoError.unreadable("Video \(index + 1)")
                    }
                    pendingMedia.append(
                        PendingMedia(
                            originalFilename: "Video-\(UUID().uuidString).\(fileExtension)",
                            stagedURL: video.url,
                            mediaKind: .video
                        )
                    )
                } else {
                    guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                        throw ManagedPhotoError.unreadable("Photo \(index + 1)")
                    }
                    pendingMedia.append(
                        PendingMedia(
                            originalFilename: "Photo-\(UUID().uuidString).\(fileExtension)",
                            data: data,
                            mediaKind: .photo
                        )
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            let memory = try BucketStore.saveMemory(
                for: item,
                thoughts: thoughts,
                completedOn: completedOn,
                in: modelContext
            )
            try ManagedPhotoStore.importMedia(
                pendingMedia,
                into: memory,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSelectedMedia() {
        guard let mediaPendingRemoval else { return }
        do {
            try ManagedPhotoStore.remove(mediaPendingRemoval, from: modelContext)
            self.mediaPendingRemoval = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openPreview(for media: MemoryPhoto) {
        guard let url = ManagedPhotoStore.fileURL(for: media) else { return }
        previewMedia = MediaPreview(
            url: url,
            title: item.title,
            mediaKind: media.mediaKind
        )
    }
}

struct ManagedMediaThumbnail: View {
    let media: MemoryPhoto

    var body: some View {
        Group {
            if let url = ManagedPhotoStore.fileURL(for: media) {
                if media.mediaKind == .video {
                    VideoThumbnail(url: url)
                } else if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    unavailableMedia
                }
            } else {
                unavailableMedia
            }
        }
        .frame(height: 108)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottomLeading) {
            if media.mediaKind == .video {
                mediaBadge("Video", symbol: "play.fill")
            }
        }
    }

    private var unavailableMedia: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                Text("Unavailable")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct PendingMediaThumbnail: View {
    let media: PendingMedia

    var body: some View {
        ZStack {
            if media.mediaKind == .photo, let image = media.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(nsColor: .controlBackgroundColor)
                Image(systemName: "video.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 108)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottomLeading) {
            if media.mediaKind == .video {
                mediaBadge("Video", symbol: "play.fill")
            }
        }
    }
}

struct VideoThumbnail: View {
    let url: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .task(id: url) {
            thumbnail = await makeVideoThumbnail(url: url)
        }
    }
}

struct MediaPreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let mediaKind: MemoryMediaKind
}

struct MediaPreviewSheet: View {
    let media: MediaPreview

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(media.title)
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(14)
            Divider()

            if media.mediaKind == .video {
                ManagedVideoPlayer(url: media.url)
                    .padding(20)
            } else if let image = NSImage(contentsOf: media.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            } else {
                ContentUnavailableView(
                    "Media unavailable",
                    systemImage: "photo.badge.exclamationmark"
                )
            }
        }
        .frame(minWidth: 680, minHeight: 500)
    }
}

struct ManagedVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(Color.black)
            .onDisappear { player.pause() }
    }
}

@MainActor
private func makeVideoThumbnail(url: URL) async -> NSImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    do {
        let (image, _) = try await generator.image(at: .zero)
        return NSImage(cgImage: image, size: .zero)
    } catch {
        return nil
    }
}

private func mediaBadge(_ text: String, symbol: String) -> some View {
    Label(text, systemImage: symbol)
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7), in: Capsule())
        .foregroundStyle(.white)
        .padding(7)
}
