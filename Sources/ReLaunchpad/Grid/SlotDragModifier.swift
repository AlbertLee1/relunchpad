import SwiftUI

/// Hold-to-drag: long-press 0.25s, then drag in the shared "launchpad" space.
/// Quick clicks still reach .onTapGesture on the same view.
struct SlotDragModifier: ViewModifier {
    let slot: Slot
    let origin: () -> DragOrigin

    func body(content: Content) -> some View {
        content.gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("launchpad")))
                .onChanged { value in
                    guard case .second(true, let drag?) = value else { return }
                    let controller = DragController.shared
                    if controller.session == nil {
                        controller.begin(item: slot, origin: origin(), location: drag.location)
                    } else {
                        controller.update(location: drag.location)
                    }
                }
                .onEnded { value in
                    guard case .second = value else { return }
                    DragController.shared.end()
                }
        )
    }
}

extension View {
    func slotDrag(_ slot: Slot, origin: @escaping () -> DragOrigin) -> some View {
        modifier(SlotDragModifier(slot: slot, origin: origin))
    }
}
