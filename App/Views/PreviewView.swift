import SwiftUI
import TinyWebPCore

struct PreviewView: View {
    @Bindable var viewModel: ConverterViewModel

    // Shimmer shows for as long as an encode is actually in flight
    private var isEncoding: Bool {
        viewModel.isGeneratingPreview || viewModel.isConverting
    }

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
                styledImage(encoded)
            } else if let original = viewModel.previewOriginalImage {
                styledImage(original)
                    .opacity(viewModel.isGeneratingPreview ? 0.52 : 0.85)
            }

            if !isEncoding, let msg = viewModel.previewErrorMessage {
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
        // Clicking the preview minimizes the sidebar so the full image is visible
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                viewModel.isSidebarCollapsed = true
            }
        }
    }

    // Fitted image with rounded corners and shadows that track the image's own frame.
    // The shimmer overlays the image before clipping, so it stays inside its bounds.
    private func styledImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                if isEncoding {
                    RainbowShimmerView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 4)
            .shadow(color: .black.opacity(0.15), radius: 15, x: -2, y: 0)
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

    // MARK: - Empty state (same upload zone as the inspector panel, centered)

    private var emptyState: some View {
        DropZoneView { urls in viewModel.addFiles(urls) }
            .frame(width: 256, height: 174)
            .background(sectionFill, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Rainbow shimmer (conversion feedback)

// Vertical rainbow band that sweeps top-to-bottom on a loop; it lives as an
// overlay on the previewed image, so it repeats until the encode finishes and
// the view is removed.
private struct RainbowShimmerView: View {
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .red, .orange, .yellow, .green, .blue, .purple, .pink, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geo.size.height * 0.6)
            .offset(y: sweep ? geo.size.height : -geo.size.height * 0.6)
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
        }
        .opacity(0.4)
        .blendMode(.screen)
        .allowsHitTesting(false)
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
