import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// PRD §6.1: accepts drag-and-drop or a standard file picker. Compact layout for embedding
/// inside the settings panel.
struct DropZoneView: View {
    var onFilesSelected: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]),
                    antialiased: true
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35))

            if isTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.07))
            }

            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 20))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Drop images here")
                        .font(.system(size: 13, weight: .medium))
                    Text("PNG · JPEG · HEIC · TIFF · GIF · BMP")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Browse", action: presentFilePicker)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let relevant = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !relevant.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in relevant {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            onFilesSelected(urls)
        }
        return true
    }

    private func presentFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif, .bmp]
        guard panel.runModal() == .OK else { return }
        onFilesSelected(panel.urls)
    }
}
