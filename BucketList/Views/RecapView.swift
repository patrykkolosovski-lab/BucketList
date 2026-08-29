import AppKit
import SwiftUI

struct RecapView: View {
    let items: [BucketItem]
    let editMemory: (BucketItem) -> Void

    @State private var previewMedia: MediaPreview?

    private var completedItems: [BucketItem] {
        items
            .filter { $0.status == .done && $0.memory != nil }
            .sorted {
                ($0.memory?.completedOn ?? .distantPast) >
                    ($1.memory?.completedOn ?? .distantPast)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if completedItems.isEmpty {
                ContentUnavailableView(
                    "Your recap starts here",
                    systemImage: "sparkles",
                    description: Text("Completed activities with an entry will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(completedItems) { item in
                            recapPost(item)
                        }
                    }
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                }
                .background(AppPalette.recap.opacity(0.035))
            }
        }
        .sheet(item: $previewMedia) { MediaPreviewSheet(media: $0) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppPalette.recap)
            Text("RECAP")
                .font(.title2.weight(.semibold))
            Text("The moments behind the checkmarks")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(completedItems.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(18)
    }

    private func recapPost(_ item: BucketItem) -> some View {
        let memory = item.memory
        let media = (memory?.photos ?? []).sorted { $0.createdAt < $1.createdAt }

        return VStack(alignment: .leading, spacing: 0) {
            postHeader(item, memory: memory)

            if media.isEmpty {
                ZStack {
                    AppPalette.recap.opacity(0.11)
                    VStack(spacing: 10) {
                        Text(item.emoji)
                            .font(.system(size: 64))
                        Text("A completed adventure")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                VStack(spacing: 3) {
                    ForEach(media) { attachment in
                        recapMedia(attachment, title: item.title)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let thoughts = memory?.thoughts, !thoughts.isEmpty {
                    Text(thoughts)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
                    Text("A completed adventure.")
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Completed")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppPalette.recap)
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.recap.opacity(0.28))
        }
    }

    private func postHeader(
        _ item: BucketItem,
        memory: CompletionMemory?
    ) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title2)
                .frame(width: 38, height: 38)
                .background(AppPalette.recap.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                if let completedOn = memory?.completedOn {
                    Text(completedOn.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                editMemory(item)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit completion entry")
        }
        .padding(16)
    }

    @ViewBuilder
    private func recapMedia(_ media: MemoryPhoto, title: String) -> some View {
        if let url = ManagedPhotoStore.fileURL(for: media) {
            if media.mediaKind == .video {
                VideoThumbnail(url: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .shadow(radius: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previewMedia = MediaPreview(
                            url: url,
                            title: title,
                            mediaKind: .video
                        )
                    }
            } else if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.92))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previewMedia = MediaPreview(
                            url: url,
                            title: title,
                            mediaKind: .photo
                        )
                    }
            } else {
                unavailableMedia
            }
        } else {
            unavailableMedia
        }
    }

    private var unavailableMedia: some View {
        ContentUnavailableView(
            "Media unavailable",
            systemImage: "photo.badge.exclamationmark"
        )
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
