import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Tiny WebP Converter")
                .font(.title2)
                .bold()

            if !viewModel.rejectedFiles.isEmpty {
                RejectedFilesView(files: viewModel.rejectedFiles) { file in
                    viewModel.dismissRejectedFile(file)
                }
            }

            if viewModel.queue.isEmpty {
                DropZoneView { urls in
                    viewModel.addFiles(urls)
                }
            } else {
                FileQueueView(items: viewModel.queue) { item in
                    viewModel.removeItem(item)
                }
                .frame(minHeight: 200)

                DropZoneView { urls in
                    viewModel.addFiles(urls)
                }
                .frame(height: 100)

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
        .frame(minWidth: 480, minHeight: 420)
    }
}

#Preview {
    ContentView()
}
