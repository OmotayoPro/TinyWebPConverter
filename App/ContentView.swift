import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    var body: some View {
        @Bindable var vm = viewModel

        HStack(spacing: 0) {
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

            PreviewView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        // ZStack gets .ignoresSafeArea(edges: .top) so the entire container — background
        // and panel alike — expands to fill from window top (behind the toolbar) to bottom.
        .overlay(alignment: .trailing) {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                SettingsPanelView(viewModel: viewModel)
                    .padding(8)
            }
            .frame(width: 288)
            .ignoresSafeArea(edges: .top)
        }
        .frame(minWidth: 860, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
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
