import SwiftUI
import TinyWebPCore

/// PRD §6.3's before/after comparison, using a native Slider to crossfade between the original
/// and the WebP-encoded-at-current-settings preview, rather than a custom drag-to-reveal control.
struct PreviewView: View {
    @Bindable var viewModel: ConverterViewModel

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.selectedItem != nil {
                ZStack {
                    if let original = viewModel.previewOriginalImage {
                        Image(nsImage: original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    if let webp = viewModel.previewWebPImage {
                        Image(nsImage: webp)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .opacity(viewModel.previewRevealAmount)
                    }
                    if viewModel.isGeneratingPreview {
                        ProgressView()
                    }
                    if let message = viewModel.previewErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Original")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.previewRevealAmount, in: 0...1)
                    Text("WebP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let original = viewModel.previewOriginalByteCount, let webp = viewModel.previewWebPByteCount {
                    Text("\(formatBytes(original)) → \(formatBytes(webp))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Image Selected",
                    systemImage: "photo",
                    description: Text("Select a file in the queue to preview it.")
                )
                .frame(minHeight: 220)
            }
        }
    }

    private func formatBytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
