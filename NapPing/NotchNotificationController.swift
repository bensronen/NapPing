import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class NotchNotificationController {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func showSleepDetected() {
        show(title: "Sleep detected",
             message: "Eyes closed for a few seconds.",
             actionTitle: nil,
             action: nil)
    }

    func show(title: String,
              message: String,
              actionTitle: String?,
              action: (() -> Void)?) {
        let content = NotchNotificationView(
            title: title,
            message: message,
            actionTitle: actionTitle,
            onAction: { [weak self] in
                action?()
                self?.dismiss(animated: true)
            },
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let containerView = NSView(frame: NSRect(origin: .zero, size: NotchNotificationLayout.preferredSize))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)

        let panel = ensurePanel()
        panel.contentView = containerView
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        showPanel(panel, animated: true)
        scheduleAutoDismiss()
    }

    func dismiss(animated: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let panel else { return }
        hidePanel(panel, animated: animated)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let size = NotchNotificationLayout.preferredSize
        let initial = NotchNotificationLayout.offscreenFrame(for: size)

        let panel = NotchToastPanel(contentRect: initial,
                                    styleMask: [.nonactivatingPanel, .borderless],
                                    backing: .buffered,
                                    defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        self.panel = panel
        return panel
    }

    private func showPanel(_ panel: NSPanel, animated: Bool) {
        let size = NotchNotificationLayout.preferredSize
        let target = NotchNotificationLayout.onscreenFrame(for: size)
        let start = NotchNotificationLayout.offscreenFrame(for: size)
        panel.setFrame(start, display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        guard animated else {
            panel.setFrame(target, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = NotchNotificationLayout.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }

    private func hidePanel(_ panel: NSPanel, animated: Bool) {
        let size = NotchNotificationLayout.preferredSize
        let target = NotchNotificationLayout.offscreenFrame(for: size)

        let performHide = {
            panel.orderOut(nil)
        }

        guard animated else {
            panel.setFrame(target, display: false)
            performHide()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NotchNotificationLayout.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: performHide)
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.dismiss(animated: true)
            }
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + NotchNotificationLayout.autoDismissSeconds, execute: item)
    }
}

private enum NotchNotificationLayout {
    static let preferredSize = NSSize(width: 360, height: 72)
    static let notchPadding: CGFloat = 10
    static let animationDuration: TimeInterval = 0.22
    static let autoDismissSeconds: TimeInterval = 7

    static func onscreenFrame(for size: NSSize) -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(x: 40, y: 40, width: size.width, height: size.height)
        }
        let safe = screen.visibleFrame
        let x = safe.midX - (size.width / 2)
        let y = safe.maxY - notchPadding - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    static func offscreenFrame(for size: NSSize) -> NSRect {
        var rect = onscreenFrame(for: size)
        rect.origin.y += (size.height + 18)
        return rect
    }
}

private final class NotchToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct NotchNotificationView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if let actionTitle {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: NotchNotificationLayout.preferredSize.width,
               height: NotchNotificationLayout.preferredSize.height)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
