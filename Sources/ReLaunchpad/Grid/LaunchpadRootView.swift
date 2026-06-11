import SwiftUI

/// Full-screen root of the Launchpad overlay: blurred wallpaper + search bar
/// + paged grid + folder panel + drag ghost, zooming/fading like the original.
struct LaunchpadRootView: View {
    @ObservedObject var state: OverlayState
    var onDismiss: () -> Void

    @ObservedObject private var library = AppLibrary.shared
    @ObservedObject private var viewModel = LaunchpadViewModel.shared
    @ObservedObject private var drag = DragController.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { rootGeo in
            ZStack {
                background
                    .ignoresSafeArea()
                    .opacity(state.isPresented ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { handleBackgroundTap() }

                VStack(spacing: 0) {
                    searchBar
                        .padding(.top, 40)
                    pager
                        .padding(.top, 24)
                    pageDots
                        .padding(.bottom, 28)
                }
                .scaleEffect(state.isPresented ? 1.0 : 1.15)
                .opacity(state.isPresented ? 1 : 0)

                folderOverlay
                dragGhost
            }
            .onChange(of: rootGeo.size, initial: true) { _, size in
                drag.rootBounds = CGRect(origin: .zero, size: size)
            }
        }
        .coordinateSpace(name: "launchpad")
        .onChange(of: state.isPresented) { _, presented in
            if presented { searchFocused = true }
        }
    }

    private func handleBackgroundTap() {
        if viewModel.openFolder != nil {
            withAnimation(.easeOut(duration: 0.18)) { viewModel.openFolder = nil }
        } else if viewModel.isJiggling {
            viewModel.isJiggling = false
        } else {
            onDismiss()
        }
    }

    // MARK: - Pieces

    /// Blurred wallpaper like the original Launchpad; falls back to a
    /// behind-window material when the wallpaper can't be read.
    @ViewBuilder
    private var background: some View {
        if let wallpaper = state.wallpaper {
            GeometryReader { geo in
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.32))
            }
        } else {
            BlurBackgroundView()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("搜索", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($searchFocused)
        }
        .font(.system(size: 15))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 260)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        )
        .opacity(viewModel.openFolder == nil ? 1 : 0)
    }

    private var pager: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width
            let pages = viewModel.displayPages
            let slotsPerPage = library.grid.slotsPerPage

            HStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, page in
                    PageGridView(
                        pageIndex: pageIndex,
                        slots: page,
                        grid: library.grid,
                        selectedIndex: selectedIndexOnPage(pageIndex, slotsPerPage: slotsPerPage),
                        isInteractive: !viewModel.isSearching
                    )
                    .padding(.horizontal, pageWidth * 0.08)
                    .frame(width: pageWidth)
                }
            }
            .offset(x: -CGFloat(min(viewModel.currentPage, pages.count - 1)) * pageWidth)
            .contentShape(Rectangle())
            // Clicks on empty space dismiss, like the original Launchpad.
            // Icon taps win automatically — child gestures take precedence.
            .onTapGesture { handleBackgroundTap() }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard !drag.isDragging else { return }
                        if value.predictedEndTranslation.width < -80 {
                            viewModel.goToPage(viewModel.currentPage + 1)
                        } else if value.predictedEndTranslation.width > 80 {
                            viewModel.goToPage(viewModel.currentPage - 1)
                        }
                    }
            )
        }
        .blur(radius: viewModel.openFolder == nil ? 0 : 12)
        .allowsHitTesting(viewModel.openFolder == nil)
    }

    @ViewBuilder
    private var folderOverlay: some View {
        if let folderID = viewModel.openFolder, let folder = library.folder(folderID) {
            Color.black.opacity(0.001) // catch outside taps without dimming
                .ignoresSafeArea()
                .onTapGesture { handleBackgroundTap() }
            FolderOpenView(folder: folder)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var dragGhost: some View {
        if let session = drag.session {
            ghostView(for: session.item)
                .position(session.location)
                .scaleEffect(1.12)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                .allowsHitTesting(false)
                .zIndex(100)
        }
    }

    @ViewBuilder
    private func ghostView(for slot: Slot) -> some View {
        switch slot {
        case .app(let bundleID):
            if let app = library.app(for: bundleID) {
                AppIconView(app: app, iconSide: 72, showsLabel: false)
            }
        case .folder(let folder):
            FolderIconView(folder: folder, iconSide: 72)
        }
    }

    private func selectedIndexOnPage(_ pageIndex: Int, slotsPerPage: Int) -> Int? {
        guard viewModel.isSearching, let selected = viewModel.selectedIndex else { return nil }
        let page = selected / slotsPerPage
        return page == pageIndex ? selected % slotsPerPage : nil
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(viewModel.pageCount, 1), id: \.self) { page in
                Circle()
                    .fill(.white.opacity(page == viewModel.currentPage ? 0.95 : 0.35))
                    .frame(width: 7, height: 7)
                    .contentShape(Circle().scale(2.5))
                    .onTapGesture { viewModel.goToPage(page) }
            }
        }
        .padding(.top, 18)
        .opacity(viewModel.openFolder == nil ? 1 : 0)
    }
}
