import AppKit

final class WindowStateStore {
    private let defaults = UserDefaults.standard
    private let frameKey = "com.napping.overlay.frame"

    func restoredFrame(defaultSize: NSSize) -> NSRect {
        guard let stored = defaults.string(forKey: frameKey) else {
            return ScreenAnchor.preferredFrame(for: defaultSize)
        }

        let rect = NSRectFromString(stored)
        let safeRect = ScreenAnchor.clamped(frame: rect)
        return safeRect.size == .zero ? ScreenAnchor.preferredFrame(for: defaultSize) : safeRect
    }

    func persist(frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: frameKey)
    }
}

enum ScreenAnchor {
    private static let notchPadding: CGFloat = 12

    static func preferredFrame(for size: NSSize) -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(x: 40, y: 40, width: size.width, height: size.height)
        }
        let safeFrame = screen.visibleFrame
        let x = safeFrame.midX - (size.width / 2)
        let y = min(safeFrame.maxY - notchPadding - size.height, safeFrame.maxY - size.height)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    static func clamped(frame: NSRect) -> NSRect {
        guard let screen = frame.containingScreen else { return frame }
        let safeFrame = screen.visibleFrame
        var rect = frame
        rect.origin.x = max(safeFrame.minX, min(rect.origin.x, safeFrame.maxX - rect.size.width))
        rect.origin.y = max(safeFrame.minY, min(rect.origin.y, safeFrame.maxY - rect.size.height))
        return rect
    }
}

private extension NSRect {
    var containingScreen: NSScreen? {
        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(self) { return screen }
        }
        return NSScreen.main
    }
}
