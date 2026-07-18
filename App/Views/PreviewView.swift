import SwiftUI
import TinyWebPCore

/// PRD §6.3: horizontal split clip-reveal comparison. `splitPosition` is pure local @State —
/// dragging the knob never touches the ViewModel, so it never triggers a re-encode.
struct PreviewView: View {
    @Bindable var viewModel: ConverterViewModel
    @State private var splitPosition: Double = 0.5

    var body: some View {
        Group {
            if viewModel.selectedItem != nil {
                GeometryReader { geo in
                    splitView(size: geo.size)
                }
            } else {
                emptyState
            }
        }
        .background(Color.black.opacity(0.88))
    }

    // MARK: - Split view

    private func splitView(size: CGSize) -> some View {
        let divY = size.height * splitPosition

        return ZStack {
            // Base: encoded (WebP/AVIF) image — shown in the lower portion
            if let encoded = viewModel.previewEncodedImage {
                Image(nsImage: encoded)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            }

            // Top: original image, clipped to reveal only the top portion
            if let original = viewModel.previewOriginalImage {
                Image(nsImage: original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .mask {
                        VStack(spacing: 0) {
                            Color.white.frame(height: divY)
                            Color.clear
                        }
                        .frame(width: size.width, height: size.height)
                    }
            }

            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size.width, height: 1)
                .position(x: size.width / 2, y: divY)

            // Drag knob — local gesture, no ViewModel involvement
            dragKnob
                .position(x: size.width / 2, y: divY)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            splitPosition = min(max(value.location.y / size.height, 0), 1)
                        }
                )
        }
        .overlay(alignment: .center) {
            if viewModel.isGeneratingPreview {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if let msg = viewModel.previewErrorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            formatBadges
                .padding(12)
        }
    }

    // MARK: - Knob

    private var dragKnob: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        }
    }

    // MARK: - Badges

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
            description: Text("Drop images into the panel on the right, then select one from the sidebar.")
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
