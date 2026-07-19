import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    // Height of the minimized card: proportional to item count, capped at 380pt.
    // Each collapsed cell is 54pt (48pt thumb + 6pt spacing); header + padding ≈ 46pt.
    private var collapsedCardHeight: CGFloat {
        let perItem: CGFloat = 54
        let overhead: CGFloat = 46
        return min(CGFloat(viewModel.queue.count) * perItem + overhead, 380)
    }

    var body: some View {
        @Bindable var vm = viewModel

        PreviewView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Sidebar ─────────────────────────────────────────────────────
            .overlay(alignment: .leading) {
                if viewModel.isSidebarCollapsed {
                    // Minimized: naturally-sized card centred vertically
                    VStack {
                        Spacer()
                        sidebarView
                            .frame(height: collapsedCardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8)
                        Spacer()
                    }
                    .frame(width: 104)
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88, anchor: .leading).combined(with: .opacity),
                        removal:   .scale(scale: 0.88, anchor: .leading).combined(with: .opacity)
                    ))
                } else {
                    // Expanded: full-height card (extends behind toolbar)
                    sidebarView
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(8)
                        .frame(width: 232)
                        .ignoresSafeArea(edges: .top)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.2), value: viewModel.isSidebarCollapsed)

            // ── Inspector (unchanged) ────────────────────────────────────────
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
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
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
            .toolbarBackground(.hidden, for: .windowToolbar)
    }

    // Shared FileQueueView instance configured for current state
    private var sidebarView: some View {
        FileQueueView(
            items: viewModel.queue,
            selectedItemIDs: viewModel.selectedItemIDs,
            viewMode: viewModel.viewMode,
            isCollapsed: viewModel.isSidebarCollapsed,
            allSelected: viewModel.allSelected,
            onTap: { item, mods in viewModel.selectItem(item, modifiers: mods) },
            onRemove: { viewModel.removeItem($0) },
            onDeleteSelected: { viewModel.removeSelectedItems() },
            onToggleSelectAll: { viewModel.toggleSelectAll() }
        )
    }
}

#Preview {
    ContentView()
}
