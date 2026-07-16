import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// PRD §6.1: accepts drag-and-drop onto the window, or a standard file picker.
struct DropZoneView: View {
    var onFilesSelected: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 36))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Drop images here")
                .font(.headline)
            Text("PNG, JPEG, HEIC, TIFF, GIF, or BMP")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Choose Files…", action: presentFilePicker)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35))
        )
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

#Preview {
    DropZoneView { _ in }
        .padding()
}
