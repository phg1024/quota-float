import Cocoa
import SwiftUI

// Mouse handling note: title dragging is handled in three overlapping places (the panel's `sendEvent`, the hosting
// view's first-mouse/background drag, and `WindowDragHandle`). They were added together to fix a panel that ignored
// the mouse; verify dragging, first click and the refresh/hide buttons before simplifying them.

let positionAutosaveName = "QuotaFloatPosition"

/// Floating panel that moves when the title area (top 48 pt, left of the buttons) is dragged.
final class QuotaPanel: NSPanel {
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        let point = event.locationInWindow
        if event.type == .leftMouseDown, point.y >= frame.height - 48, point.x >= 0, point.x < frame.width - 70 {
            dragStart = (convertPoint(toScreen: point), frame.origin)
            return
        }
        if let start = dragStart {
            if event.type == .leftMouseDragged {
                let mouse = convertPoint(toScreen: point)
                setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
                return
            }
            if event.type == .leftMouseUp {
                dragStart = nil
                saveFrame(usingName: positionAutosaveName)
                return
            }
        }
        super.sendEvent(event)
    }
}

final class QuotaHostingView: NSHostingView<QuotaView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
}

struct WindowDragHandle: NSViewRepresentable {
    final class Handle: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }

    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ nsView: Handle, context: Context) {}
}
