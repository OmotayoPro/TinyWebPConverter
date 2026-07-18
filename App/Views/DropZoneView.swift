import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Upload zone — vertical centered layout matching Figma node 217:6387.
struct DropZoneView: View {
    var onFilesSelected: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [5, 3]),
                    antialiased: true
                )
                .foregroundStyle(
                    isTargeted ? Color.accentColor : Color.primary.opacity(0.1)
                )

            if isTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.07))
            }

            VStack(spacing: 16) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.primary.opacity(0.85))

                VStack(spacing: 8) {
                    Text("Upload Images")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.85))

                    Text("PNG, JPEG, HEIC, TIFF, GIF & BMP")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                Button("Upload Files", action: presentFilePicker)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
            .padding(.vertical, 24)
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
