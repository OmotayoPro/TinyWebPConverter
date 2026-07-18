import SwiftUI
import AppKit
import ImageIO
import TinyWebPCore

private enum CompressionMode: String, CaseIterable, Identifiable {
    case lossy = "Lossy"
    case lossless = "Lossless"
    var id: String { rawValue }
}

/// Inspector panel — Figma node 217:6385. Width 272, fills height, floating card with
/// cornerRadius 16. Sections top-aligned, Convert button pinned to bottom.
struct SettingsPanelView: View {
    @Bindable var viewModel: ConverterViewModel

    @State private var compressionMode: CompressionMode = .lossy
    @State private var widthText: String = ""
    @State private var heightText: String = ""
    @State private var aspectLocked = false
    @State private var lockedRatio: Double? = nil
    @State private var isUpdatingFromLock = false
    @State private var imageDimensions: CGSize? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: stacked sections
            VStack(alignment: .leading, spacing: 16) {
                uploadSection
                propertiesGroup
                outputGroup
            }

            Spacer(minLength: 16)

            // Bottom: Convert button pinned to bottom
            convertButton
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { loadDimensions() }
        .onChange(of: viewModel.selectedItemID) { _, _ in loadDimensions() }
        .onChange(of: compressionMode) { _, mode in
            viewModel.settings.lossless = (mode == .lossless)
        }
    }

    // MARK: - Upload section (Figma 217:6387) — fixed 174px height

    private var uploadSection: some View {
        DropZoneView { urls in viewModel.addFiles(urls) }
            .frame(maxWidth: .infinity)
            .frame(height: 174)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Properties group (Figma 217:6393)

    private var propertiesGroup: some View {
        VStack(spacing: 0) {
            compressionRow
            rowDivider
            qualityRow
            rowDivider
            resizeRow
            rowDivider
            metadataRow
        }
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var compressionRow: some View {
        HStack {
            rowLabel("Compression")
            Spacer()
            Picker("", selection: $compressionMode) {
                ForEach(CompressionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .frame(height: 44)
    }

    private var qualityRow: some View {
        HStack(spacing: 24) {
            rowLabel("Quality")
            HStack(spacing: 16) {
                QualitySlider(
                    value: Binding(
                        get: { Double(viewModel.settings.quality) },
                        set: { viewModel.settings.quality = Int($0.rounded()) }
                    ),
                    range: 0...100,
                    isDisabled: viewModel.settings.lossless
                )

                Text("\(viewModel.settings.quality)%")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .frame(height: 44)
    }

    private var resizeRow: some View {
        HStack {
            rowLabel("Resize")
            Spacer()
            HStack(spacing: 8) {
                DimensionField(prefix: "W", text: $widthText)
                    .onChange(of: widthText) { _, _ in
                        guard !isUpdatingFromLock else { return }
                        if aspectLocked, let ratio = lockedRatio,
                           let w = Int(widthText), w > 0 {
                            isUpdatingFromLock = true
                            heightText = "\(Int((Double(w) / ratio).rounded()))"
                            isUpdatingFromLock = false
                        }
                        updateResize()
                    }

                Text("x")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.85))

                DimensionField(prefix: "H", text: $heightText)
                    .onChange(of: heightText) { _, _ in
                        guard !isUpdatingFromLock else { return }
                        if aspectLocked, let ratio = lockedRatio,
                           let h = Int(heightText), h > 0 {
                            isUpdatingFromLock = true
                            widthText = "\(Int((Double(h) * ratio).rounded()))"
                            isUpdatingFromLock = false
                        }
                        updateResize()
                    }

                // Aspect ratio lock icon (Figma 217:6789)
                Button {
                    aspectLocked.toggle()
                    if aspectLocked,
                       let w = Int(widthText), let h = Int(heightText),
                       w > 0, h > 0 {
                        lockedRatio = Double(w) / Double(h)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.19))
                            .frame(width: 16, height: 16)
                        Image(systemName: aspectLocked ? "lock.fill" : "aspectratio")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(aspectLocked ? Color.accentColor : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
    }

    private var metadataRow: some View {
        HStack {
            rowLabel("Keep Metadata")
            Spacer()
            Toggle("", isOn: $viewModel.settings.keepMetadata)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(height: 44)
    }

    // MARK: - Output group (Figma 217:6417)

    private var outputGroup: some View {
        VStack(spacing: 0) {
            outputFormatRow
            rowDivider
            outputFolderRow
        }
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var outputFormatRow: some View {
        HStack {
            rowLabel("Output Format")
            Spacer()
            Picker("", selection: $viewModel.settings.outputFormat) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .frame(height: 44)
    }

    private var outputFolderRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    rowLabel("Output Folder")
                    Text(
                        viewModel.outputDirectoryOverride.map { "~/.../\($0.lastPathComponent)" }
                            ?? "~/...WebP Converter"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                Spacer()
                Button("Choose...", action: chooseOutputFolder)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Convert button (Figma 217:6426)

    private var convertButton: some View {
        Button {
            Task { await viewModel.convertAll() }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isConverting {
                    ProgressView().controlSize(.small).tint(.white)
                }
                Text(viewModel.isConverting ? "Converting…" : "Convert Images")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .background(
            viewModel.queue.isEmpty || viewModel.isConverting
                ? Color.accentColor.opacity(0.4)
                : Color.accentColor,
            in: Capsule()
        )
        .disabled(viewModel.queue.isEmpty || viewModel.isConverting)
    }

    // MARK: - Helpers

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.85))
    }

    private var rowDivider: some View {
        Divider()
            .foregroundStyle(Color.primary.opacity(0.1))
    }

    private func updateResize() {
        guard let w = Int(widthText), let h = Int(heightText), w > 0, h > 0 else {
            viewModel.settings.resize = .none
            return
        }
        if let dims = imageDimensions, Int(dims.width) == w, Int(dims.height) == h {
            viewModel.settings.resize = .none
        } else {
            viewModel.settings.resize = .dimensions(width: w, height: h)
        }
    }

    private func loadDimensions() {
        guard let url = viewModel.selectedItem?.sourceURL else {
            imageDimensions = nil
            return
        }
        Task.detached(priority: .background) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int,
                  let h = props[kCGImagePropertyPixelHeight] as? Int
            else { return }
            await MainActor.run {
                self.imageDimensions = CGSize(width: w, height: h)
                self.widthText = "\(w)"
                self.heightText = "\(h)"
            }
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.outputDirectoryOverride = url
    }
}

// MARK: - Custom quality slider (avoids the native NSSlider white underline track)

private struct QualitySlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var isDisabled: Bool = false

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobCenterX = fraction * (trackWidth - knobSize) + knobSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(isDisabled ? Color.primary.opacity(0.15) : Color.accentColor)
                    .frame(width: max(knobCenterX, 0), height: trackHeight)

                Circle()
                    .fill(isDisabled ? Color.primary.opacity(0.25) : Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .offset(x: knobCenterX - knobSize / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard !isDisabled else { return }
                    let raw = (drag.location.x - knobSize / 2) / max(trackWidth - knobSize, 1)
                    value = min(max(raw, 0), 1) * (range.upperBound - range.lowerBound) + range.lowerBound
                }
            )
        }
        .frame(height: knobSize)
    }
}

// MARK: - W/H Dimension Field (Figma 217:6782/6786)

private struct DimensionField: View {
    let prefix: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.25))
                .padding(.leading, 4)
                .padding(.trailing, 2)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.primary.opacity(0.85))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 8)
        }
        .frame(width: 65)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
    }
}
