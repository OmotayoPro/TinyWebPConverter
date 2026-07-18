import SwiftUI
import TinyWebPCore

struct PreviewView: View {
    @Bindable var viewModel: ConverterViewModel

    var body: some View {
        Group {
            if viewModel.selectedItem != nil {
                imagePreview
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Image preview (encoded output, falls back to original while generating)

    private var imagePreview: some View {
        ZStack {
            if let encoded = viewModel.previewEncodedImage {
                Image(nsImage: encoded)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let original = viewModel.previewOriginalImage {
                Image(nsImage: original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(viewModel.isGeneratingPreview ? 0.4 : 0.85)
            }

            if viewModel.isGeneratingPreview {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if let msg = viewModel.previewErrorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            formatBadges.padding(12)
        }
    }

    // MARK: - Format badges

    private var formatBadges: some View {
        HStack {
            if let origBytes = viewModel.previewOriginalByteCount {
                FormatBadge(
                    label: viewModel.selectedItem?.sourceURL.pathExtension.uppercased() ?? "ORIG",
                    bytes: origBytes,
                    isOutput: false
                )
            }
            Spacer()
            if let encBytes = viewModel.previewEncodedByteCount {
                FormatBadge(
                    label: viewModel.settings.outputFormat.rawValue,
                    bytes: encBytes,
                    isOutput: true
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Image Selected",
            systemImage: "photo",
            description: Text("Select an image from the sidebar or upload files using the panel on the right.")
        )
    }
}

// MARK: - Badge

private struct FormatBadge: View {
    let label: String
    let bytes: Int
    let isOutput: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.semibold)
            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
        }
        .font(.system(size: 10))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isOutput ? Color.green.opacity(0.85) : Color.black.opacity(0.6),
            in: Capsule()
        )
    }
}
