import SwiftUI
import AppKit
import TinyWebPCore

private enum CompressionMode: String, CaseIterable, Identifiable {
    case lossy = "Lossy"
    case lossless = "Lossless"
    var id: String { rawValue }
}

struct SettingsPanelView: View {
    @Bindable var viewModel: ConverterViewModel

    @State private var compressionMode: CompressionMode = .lossy
    @State private var widthText: String = ""
    @State private var heightText: String = ""
    @State private var resizeEnabled = false
    @State private var aspectLocked = false
    @State private var lockedRatio: Double? = nil
    @State private var isUpdatingFromLock = false

    var body: some View {
        VStack(spacing: 0) {
            // Drop zone at the top
            DropZoneView { urls in viewModel.addFiles(urls) }
                .frame(height: 88)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // Group 1: compression settings
                    settingsGroup {
                        settingsRow("Compression") {
                            Picker("", selection: $compressionMode) {
                                ForEach(CompressionMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 96)
                            .onChange(of: compressionMode) { _, mode in
                                viewModel.settings.lossless = (mode == .lossless)
                            }
                        }

                        rowDivider

                        settingsRow("Quality") {
                            Text("\(viewModel.settings.quality)")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 26, alignment: .trailing)
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.settings.quality) },
                                    set: { viewModel.settings.quality = Int($0.rounded()) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .frame(width: 84)
                            .disabled(viewModel.settings.lossless)
                        }

                        rowDivider

                        // Resize row
                        HStack(spacing: 8) {
                            Text("Resize")
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $resizeEnabled)
                                .labelsHidden()
                                .onChange(of: resizeEnabled) { _, enabled in
                                    if !enabled {
                                        viewModel.settings.resize = .none
                                    } else {
                                        updateResize()
                                    }
                                }
                            HStack(spacing: 3) {
                                TextField("W", text: $widthText)
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                    .disabled(!resizeEnabled)
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
                                Button {
                                    aspectLocked.toggle()
                                    if aspectLocked,
                                       let w = Int(widthText), let h = Int(heightText),
                                       w > 0, h > 0 {
                                        lockedRatio = Double(w) / Double(h)
                                    }
                                } label: {
                                    Image(systemName: aspectLocked ? "lock.fill" : "lock.open")
                                        .font(.system(size: 10))
                                        .foregroundStyle(aspectLocked ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(!resizeEnabled)
                                TextField("H", text: $heightText)
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                    .disabled(!resizeEnabled)
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
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)

                        rowDivider

                        settingsRow("Keep Metadata") {
                            Toggle("", isOn: $viewModel.settings.keepMetadata)
                                .labelsHidden()
                        }
                    }

                    // Group 2: output settings
                    settingsGroup {
                        settingsRow("Output Format") {
                            Picker("", selection: $viewModel.settings.outputFormat) {
                                ForEach(OutputFormat.allCases) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 110)
                        }

                        rowDivider

                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Output Folder")
                                    .font(.system(size: 13))
                                Text(viewModel.outputDirectoryOverride?.lastPathComponent ?? "Same as source")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Choose…", action: chooseOutputFolder)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                    }

                    // Convert button
                    Button {
                        Task { await viewModel.convertAll() }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isConverting {
                                ProgressView().controlSize(.small).tint(.white)
                            }
                            Text(
                                viewModel.isConverting
                                    ? "Converting…"
                                    : "Convert \(viewModel.queue.count) Image\(viewModel.queue.count == 1 ? "" : "s")"
                            )
                            .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.queue.isEmpty || viewModel.isConverting)

                    if !viewModel.queue.isEmpty {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearQueue()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .disabled(viewModel.isConverting)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func settingsRow<Content: View>(_ label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 12)
    }

    private func updateResize() {
        guard resizeEnabled else {
            viewModel.settings.resize = .none
            return
        }
        viewModel.settings.resize = .dimensions(width: Int(widthText), height: Int(heightText))
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
