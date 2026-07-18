import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        HStack(spacing: 0) {
            // Left sidebar: thumbnail grid / list
            FileQueueView(
                items: viewModel.queue,
                selectedItemID: viewModel.selectedItemID,
                viewMode: viewModel.viewMode,
                isCollapsed: viewModel.isSidebarCollapsed,
                onSelect: { viewModel.selectItem($0) },
                onRemove: { viewModel.removeItem($0) }
            )
            .frame(width: viewModel.isSidebarCollapsed ? 72 : 216)
            .animation(.spring(duration: 0.25), value: viewModel.isSidebarCollapsed)

            Divider()

            // Center: before/after comparison preview
            PreviewView(viewModel: viewModel)
                .frame(maxWidth: .infinity)

            Divider()

            // Right: settings + drop zone + convert
            SettingsPanelView(viewModel: viewModel)
                .frame(width: 264)
        }
        .frame(minWidth: 860, minHeight: 540)
        .overlay(alignment: .top) {
            if !viewModel.rejectedFiles.isEmpty {
                RejectedFilesView(files: viewModel.rejectedFiles) { file in
                    viewModel.dismissRejectedFile(file)
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: viewModel.rejectedFiles.count)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        viewModel.isSidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")

                Picker("View Mode", selection: $vm.viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Switch between grid and list view")
            }
        }
    }
}

#Preview {
    ContentView()
}
