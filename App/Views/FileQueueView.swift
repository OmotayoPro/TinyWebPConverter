import SwiftUI
import AppKit
import TinyWebPCore

/// PRD §6.4: per-image status indicator (pending / converting / done / failed), plus
/// PRD §6.5's "reveal the output in Finder" for completed items.
struct FileQueueView: View {
    var items: [BatchItem]
    var selectedItemID: BatchItem.ID?
    var onRemove: (BatchItem) -> Void
    var onSelect: (BatchItem) -> Void

    var body: some View {
        List(items) { item in
            HStack(spacing: 10) {
                statusIcon(for: item.status)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.sourceURL.lastPathComponent)
                        .lineLimit(1)
                    if case .failed(let error) = item.status {
                        Text(error.errorDescription ?? "Conversion failed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if case .done(let result) = item.status {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                    }
                    .buttonStyle(.link)
                } else if case .pending = item.status {
                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .listRowBackground(item.id == selectedItemID ? Color.accentColor.opacity(0.15) : Color.clear)
            .onTapGesture {
                onSelect(item)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: BatchItemStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        case .converting:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
