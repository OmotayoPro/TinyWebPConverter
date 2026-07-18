import SwiftUI
import AppKit
import ImageIO
import TinyWebPCore

struct FileQueueView: View {
    var items: [BatchItem]
    var selectedItemID: BatchItem.ID?
    var viewMode: ViewMode
    var isCollapsed: Bool
    var onSelect: (BatchItem) -> Void
    var onRemove: (BatchItem) -> Void

    var body: some View {
        ScrollView {
            if items.isEmpty {
                emptyPlaceholder
            } else if isCollapsed {
                collapsedGrid
            } else if viewMode == .grid {
                expandedGrid
            } else {
                listLayout
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Layouts

    private var expandedGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(items) { item in
                ThumbnailCell(
                    item: item,
                    isSelected: item.id == selectedItemID,
                    thumbSize: 68,
                    showLabel: true
                )
                .onTapGesture { onSelect(item) }
            }
        }
        .padding(8)
    }

    private var collapsedGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(items) { item in
                ThumbnailCell(
                    item: item,
                    isSelected: item.id == selectedItemID,
                    thumbSize: 48,
                    showLabel: false
                )
                .onTapGesture { onSelect(item) }
            }
        }
        .padding(8)
    }

    private var listLayout: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                ListCell(
                    item: item,
                    isSelected: item.id == selectedItemID,
                    onRemove: { onRemove(item) }
                )
                .onTapGesture { onSelect(item) }

                if item.id != items.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No images")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Thumbnail Cell (grid)

private struct ThumbnailCell: View {
    let item: BatchItem
    let isSelected: Bool
    let thumbSize: CGFloat
    let showLabel: Bool

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(width: thumbSize, height: thumbSize)

                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbSize, height: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: thumbSize * 0.28))
                }

                statusOverlay
            }
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.15 : 0.06), radius: 2, y: 1)

            if showLabel {
                Text(item.sourceURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .task(id: item.sourceURL) {
            thumbnail = await loadThumbnail(url: item.sourceURL, size: thumbSize)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch item.status {
        case .converting:
            RoundedRectangle(cornerRadius: 7)
                .fill(.black.opacity(0.45))
                .frame(width: thumbSize, height: thumbSize)
            ProgressView().tint(.white).controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, Color.green)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(4)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white, Color.orange)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(4)
        case .pending:
            EmptyView()
        }
    }
}

// MARK: - List Cell

private struct ListCell: View {
    let item: BatchItem
    let isSelected: Bool
    let onRemove: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(width: 36, height: 36)
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.sourceURL.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                listStatusText
            }

            Spacer()

            if case .pending = item.status {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            } else if case .done(let result) = item.status {
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .task(id: item.sourceURL) {
            thumbnail = await loadThumbnail(url: item.sourceURL, size: 36)
        }
    }

    @ViewBuilder
    private var listStatusText: some View {
        switch item.status {
        case .pending:
            EmptyView()
        case .converting:
            Text("Converting…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .done(let result):
            Text(ByteCountFormatter.string(fromByteCount: Int64(result.outputByteCount), countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let error):
            Text(error.errorDescription ?? "Failed")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Shared thumbnail loader

private func loadThumbnail(url: URL, size: CGFloat) async -> NSImage? {
    await Task.detached(priority: .background) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size * 2)
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }.value
}
