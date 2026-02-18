import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    private weak var controller: AppDelegate?

    init(controller: AppDelegate) {
        self.controller = controller

        let view = PreferencesView(controller: controller)
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 290),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = "NapPing Settings"
        window.isReleasedWhenClosed = false
        window.center()

        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        window.contentView = container

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
