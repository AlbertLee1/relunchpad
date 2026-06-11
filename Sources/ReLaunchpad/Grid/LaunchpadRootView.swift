import SwiftUI

/// Full-screen root of the Launchpad overlay: blurred wallpaper + search bar
/// + paged grid that zooms/fades in and out like the original.
struct LaunchpadRootView: View {
    @ObservedObject var state: OverlayState
    var onDismiss: () -> Void

    @ObservedObject private var library = AppLibrary.shared
    @ObservedObject private var viewModel = LaunchpadViewModel.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            BlurBackgroundView()
                .ignoresSafeArea()
                .opacity(state.isPresented ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

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
        }
        .onChange(of: state.isPresented) { _, presented in
            if presented { searchFocused = true }
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
    }

    private var pager: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width
            let pages = viewModel.displayPages
            let slotsPerPage = library.grid.slotsPerPage

            HStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, page in
                    PageGridView(
                        slots: page,
                        grid: library.grid,
                        selectedIndex: selectedIndexOnPage(pageIndex, slotsPerPage: slotsPerPage)
                    )
                    .padding(.horizontal, pageWidth * 0.08)
                    .frame(width: pageWidth)
                }
            }
            .offset(x: -CGFloat(min(viewModel.currentPage, pages.count - 1)) * pageWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.predictedEndTranslation.width < -80 {
                            viewModel.goToPage(viewModel.currentPage + 1)
                        } else if value.predictedEndTranslation.width > 80 {
                            viewModel.goToPage(viewModel.currentPage - 1)
                        }
                    }
            )
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
    }
}
