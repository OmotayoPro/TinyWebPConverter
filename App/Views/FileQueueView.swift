import SwiftUI
import AppKit
import ImageIO
import TinyWebPCore

struct FileQueueView: View {
    var items: [BatchItem]
    var selectedItemIDs: Set<BatchItem.ID>
    var viewMode: ViewMode
    var isCollapsed: Bool
    var allSelected: Bool
    var onTap: (BatchItem, NSEvent.ModifierFlags) -> Void
    var onRemove: (BatchItem) -> Void
    var onDeleteSelected: () -> Void
    var onToggleSelectAll: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if items.isEmpty {
                    emptyPlaceholder
                } else if isCollapsed {
                    collapsedList
                } else if viewMode == .grid {
                    expandedGrid
                } else {
                    listLayout
                }
            }
        }
        .background(Color.clear)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onDeleteCommand { onDeleteSelected() }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if isCollapsed {
            HStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                Spacer()
                Button { onToggleSelectAll() } label: {
                    Text(allSelected ? "Desel." : "Select")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(allSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
        } else {
            HStack(alignment: .center, spacing: 4) {
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                Text("(\(items.count))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { onToggleSelectAll() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 12))
                        Text("Select All")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(allSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 48)
            .padding(.bottom, 8)
        }
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
                    isSelected: selectedItemIDs.contains(item.id),
                    thumbSize: 68,
                    showLabel: true
                )
                .onTapGesture {
                    isFocused = true
                    let mods = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
                    onTap(item, mods)
                }
            }
        }
        .padding(8)
    }

    // Single-column layout for the minimized/collapsed card
    private var collapsedList: some View {
        LazyVStack(spacing: 6) {
            ForEach(items) { item in
                ThumbnailCell(
                    item: item,
                    isSelected: selectedItemIDs.contains(item.id),
                    thumbSize: 48,
                    showLabel: false
                )
                .onTapGesture {
                    isFocused = true
                    let mods = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
                    onTap(item, mods)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var listLayout: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                ListCell(
                    item: item,
                    isSelected: selectedItemIDs.contains(item.id),
                    onRemove: { onRemove(item) }
                )
                .onTapGesture {
                    isFocused = true
                    let mods = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
                    onTap(item, mods)
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: isCollapsed ? 18 : 28))
                .foregroundStyle(.tertiary)
            if !isCollapsed {
                Text("No images")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
