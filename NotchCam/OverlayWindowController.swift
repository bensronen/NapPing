import SwiftUI

final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private let cameraCoordinator: CameraSessionCoordinator
    private let windowStore = WindowStateStore()
    private var observationTokens: [NSObjectProtocol] = []
    private var isShielded = false

    private static let defaultContentSize = NSSize(width: 320, height: 200)

    init(cameraCoordinator: CameraSessionCoordinator) {
        self.cameraCoordinator = cameraCoordinator
        let initialFrame = windowStore.restoredFrame(defaultSize: Self.defaultContentSize)
        let panel = OverlayPanel(contentRect: initialFrame,
                                 styleMask: [.nonactivatingPanel, .borderless, .resizable],
                                 backing: .buffered,
                                 defer: false)
        panel.configureAppearance()
        panel.minSize = .zero
        panel.contentMinSize = .zero

        let rootView = OverlayRootView(cameraCoordinator: cameraCoordinator)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = panel.contentView?.bounds ?? panel.contentRect(forFrameRect: panel.frame)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        panel.contentView = hostingView

        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindLifecycleEvents() {
        let center = NotificationCenter.default
        let token = center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil,
                                       queue: .main) { [weak self] _ in
            self?.ensureVisibleInsideSafeRegion()
        }
        observationTokens.append(token)
    }

    func showWindow() {
        guard let window else { return }
        window.orderFrontRegardless()
        window.makeKey()
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func snapToPreferredPosition() {
        guard let window else { return }
        let frame = ScreenAnchor.preferredFrame(for: window.frame.size)
        window.setFrame(frame, display: true, animate: true)
        windowStore.persist(frame: frame)
    }

    @discardableResult
    func toggleShield() -> Bool {
        guard let panel = window as? OverlayPanel else { return isShielded }
        isShielded.toggle()
        panel.ignoresMouseEvents = isShielded
        return isShielded
    }

    func shutdown() {
        observationTokens.forEach(NotificationCenter.default.removeObserver)
        observationTokens.removeAll()
    }

    private func ensureVisibleInsideSafeRegion() {
        guard let window else { return }
        let frame = ScreenAnchor.clamped(frame: window.frame)
        window.setFrame(frame, display: true, animate: true)
        windowStore.persist(frame: frame)
    }

    func windowDidMove(_ notification: Notification) {
        guard let frame = window?.frame else { return }
        windowStore.persist(frame: frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let frame = window?.frame else { return }
        windowStore.persist(frame: frame)
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func configureAppearance() {
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hasShadow = true
        animationBehavior = .utilityWindow
        isMovableByWindowBackground = true
    }
}
