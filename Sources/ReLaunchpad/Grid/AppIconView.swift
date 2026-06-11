import SwiftUI

struct AppIconView: View {
    let app: AppItem
    let iconSide: CGFloat
    var isSelected = false
    var isHovered = false
    var showsLabel = true

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: IconCache.shared.icon(forAppAt: app.url))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSide, height: iconSide)
                .scaleEffect(isHovered ? 1.18 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
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
        .onTapGesture {
            AppLibrary.shared.launch(app.id)
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
