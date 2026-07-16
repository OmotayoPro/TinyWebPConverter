import SwiftUI
import AppKit
import TinyWebPCore

private enum ResizeMode: String, CaseIterable, Identifiable {
    case none = "None"
    case percentage = "Percentage"
    case dimensions = "Dimensions"
    var id: String { rawValue }
}

/// PRD §6.2: all native SwiftUI controls with tint styling - no custom-built controls here
/// (that's reserved for the before/after preview, and even that uses a native Slider for now).
struct SettingsPanelView: View {
    @Bindable var viewModel: ConverterViewModel

    @State private var resizeMode: ResizeMode = .none
    @State private var percentage: Double = 100
    @State private var widthText: String = ""
    @State private var heightText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Quality")
                    Spacer()
                    Text("\(viewModel.settings.quality)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.quality) },
                        set: { viewModel.settings.quality = Int($0.rounded()) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .disabled(viewModel.settings.lossless)
            }

            Toggle("Lossless", isOn: $viewModel.settings.lossless)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Resize")
                    .font(.subheadline)

                Picker("Resize Mode", selection: $resizeMode) {
                    ForEach(ResizeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch resizeMode {
                case .none:
                    EmptyView()
                case .percentage:
                    HStack {
                        Slider(value: $percentage, in: 1...100, step: 1)
                        Text("\(Int(percentage))%")
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                case .dimensions:
                    HStack {
                        TextField("Width", text: $widthText)
                            .frame(width: 70)
                        Text("×")
                        TextField("Height", text: $heightText)
                            .frame(width: 70)
                        Text("px")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: resizeMode) { _, _ in updateResize() }
            .onChange(of: percentage) { _, _ in updateResize() }
            .onChange(of: widthText) { _, _ in updateResize() }
            .onChange(of: heightText) { _, _ in updateResize() }

            Divider()

            Toggle("Keep Metadata", isOn: $viewModel.settings.keepMetadata)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Output Location")
                    .font(.subheadline)
                HStack {
                    Text(viewModel.outputDirectoryOverride?.path ?? "Same folder as source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…", action: chooseOutputFolder)
                    if viewModel.outputDirectoryOverride != nil {
                        Button("Reset") {
                            viewModel.outputDirectoryOverride = nil
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func updateResize() {
        switch resizeMode {
        case .none:
            viewModel.settings.resize = .none
        case .percentage:
            viewModel.settings.resize = .percentage(percentage)
        case .dimensions:
            viewModel.settings.resize = .dimensions(width: Int(widthText), height: Int(heightText))
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
