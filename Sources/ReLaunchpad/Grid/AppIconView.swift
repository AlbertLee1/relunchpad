import SwiftUI

struct AppIconView: View {
    let app: AppItem
    let iconSide: CGFloat
    var isSelected = false
    var isHovered = false
    var showsLabel = true
    var isJiggling = false

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: IconCache.shared.icon(forAppAt: app.url))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSide, height: iconSide)
                .scaleEffect(isHovered ? 1.18 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .overlay(alignment: .topLeading) { deleteBadge }
            if showsLabel {
                Text(app.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(isSelected ? 0.22 : 0))
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .jiggle(isJiggling, seed: app.id)
        .onTapGesture {
            AppLibrary.shared.launch(app.id)
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
            if AppUninstaller.canTrash(app) {
                Divider()
                Button("移到废纸篓", role: .destructive) {
                    AppUninstaller.trash(app)
                }
            }
        }
    }

    @ViewBuilder
    private var deleteBadge: some View {
        if isJiggling, AppUninstaller.canTrash(app) {
            Button {
                AppUninstaller.trash(app)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.95)))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: -8, y: -8)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// Original Launchpad jiggle: a small rotation oscillation, phase varied per
/// icon so the grid doesn't wobble in lockstep.
struct JiggleModifier: ViewModifier {
    let active: Bool
    let seed: String

    func body(content: Content) -> some View {
        let phase = Double(abs(seed.hashValue) % 100) / 100
        content
            .rotationEffect(.degrees(active ? 1.7 : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true).delay(phase * 0.13)
                    : .easeOut(duration: 0.1),
                value: active
            )
    }
}

extension View {
    func jiggle(_ active: Bool, seed: String) -> some View {
        modifier(JiggleModifier(active: active, seed: seed))
    }
}
