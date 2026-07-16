import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Tiny WebP Converter")
                    .font(.title2)
                    .bold()

                if !viewModel.rejectedFiles.isEmpty {
                    RejectedFilesView(files: viewModel.rejectedFiles) { file in
                        viewModel.dismissRejectedFile(file)
                    }
                }

                PreviewView(viewModel: viewModel)

                SettingsPanelView(viewModel: viewModel)

                if viewModel.queue.isEmpty {
                    DropZoneView { urls in
                        viewModel.addFiles(urls)
                    }
                } else {
                    FileQueueView(
                        items: viewModel.queue,
                        selectedItemID: viewModel.selectedItemID,
                        onRemove: { viewModel.removeItem($0) },
                        onSelect: { viewModel.selectItem($0) }
                    )
                    .frame(minHeight: 160)

                    DropZoneView { urls in
                        viewModel.addFiles(urls)
                    }
                    .frame(height: 90)

                    HStack {
                        Button("Clear", role: .destructive) {
                            viewModel.clearQueue()
                        }
                        .disabled(viewModel.isConverting)

                        Spacer()

                        Button {
                            Task { await viewModel.convertAll() }
                        } label: {
                            if viewModel.isConverting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Convert \(viewModel.queue.count) Image\(viewModel.queue.count == 1 ? "" : "s")")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isConverting)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 700)
    }
}

#Preview {
    ContentView()
}
