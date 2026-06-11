import SwiftUI

/// Full-screen root of the Launchpad overlay: blurred wallpaper + paged grid
/// that zooms/fades in and out like the original.
struct LaunchpadRootView: View {
    @ObservedObject var state: OverlayState
    var onDismiss: () -> Void

    @ObservedObject private var library = AppLibrary.shared
    @ObservedObject private var viewModel = LaunchpadViewModel.shared

    var body: some View {
        ZStack {
            BlurBackgroundView()
                .ignoresSafeArea()
                .opacity(state.isPresented ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search arrives in M2; keep the original Launchpad top margin.
                Spacer().frame(height: 90)
                pager
                pageDots
                    .padding(.bottom, 28)
            }
            .scaleEffect(state.isPresented ? 1.0 : 1.15)
            .opacity(state.isPresented ? 1 : 0)
        }
    }

    private var pager: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width
            HStack(spacing: 0) {
                ForEach(Array(library.layout.pages.enumerated()), id: \.offset) { _, page in
                    PageGridView(slots: page, grid: library.grid)
                        .padding(.horizontal, pageWidth * 0.08)
                        .frame(width: pageWidth)
                }
            }
            .offset(x: -CGFloat(viewModel.currentPage) * pageWidth)
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
