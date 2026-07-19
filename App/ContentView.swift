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
            .padding(16)
            // Inset the preview so it ends at the inspector's leading edge (288pt panel)
            .padding(.trailing, 280)

            // ── Sidebar ─────────────────────────────────────────────────────
            .overlay(alignment: .leading) {
                // Sidebar stays hidden entirely until files have been uploaded.
                // A single card whose frame morphs between expanded (236pt, full
                // height) and minimized (64pt, centred) so the spring animates one
                // view instead of cross-fading two differently-shaped ones.
                if !viewModel.queue.isEmpty {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        sidebarView
                            .frame(width: viewModel.isSidebarCollapsed ? 64 : 236)
                            .frame(maxHeight: viewModel.isSidebarCollapsed ? collapsedCardHeight : .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.15), radius: 15, x: -2, y: 0)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .ignoresSafeArea(edges: .top)
                    .transition(.move(edge: .leading).combined(with: .opacity))
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
            .background {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    DotGridBackground()
                }
                .ignoresSafeArea()
            }
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

// MARK: - Dotted particle grid background

private struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            let dotSize: CGFloat = 1.5
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.05)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

#Preview {
    ContentView()
}
