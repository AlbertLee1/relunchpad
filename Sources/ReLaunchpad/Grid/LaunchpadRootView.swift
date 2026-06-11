import SwiftUI

/// Full-screen root of the Launchpad overlay: blurred wallpaper + content
/// that zooms/fades in and out like the original.
struct LaunchpadRootView: View {
    @ObservedObject var state: OverlayState
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            BlurBackgroundView()
                .ignoresSafeArea()
                .opacity(state.isPresented ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            Text("ReLaunchpad")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
                .scaleEffect(state.isPresented ? 1.0 : 1.15)
                .opacity(state.isPresented ? 1 : 0)
        }
    }
}
