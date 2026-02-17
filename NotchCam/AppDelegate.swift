import SwiftUI
import Combine
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var showDockIcon: Bool = false
    @Published private(set) var overlayVisible = true
    @Published private(set) var overlayAcceptsInteraction = true
    @Published private(set) var cameraAuthorization: CameraSessionCoordinator.AuthorizationState = .idle
    @Published var cameraPreviewEnabled: Bool = true
    @Published var sleepDetectionEnabled: Bool = true

    private let cameraCoordinator = CameraSessionCoordinator()
    private let sleepDetector = SleepDetector()
    private var notchNotification: NotchNotificationController?
    private lazy var overlayController = OverlayWindowController(cameraCoordinator: cameraCoordinator)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []
    private var isTemporaryActivationPolicy = false

    private let statusHeaderItem = NSMenuItem(title: "Capture status: …", action: nil, keyEquivalent: "")
    private let preferencesItem = NSMenuItem(title: "Settings…", action: #selector(openPreferencesFromMenu), keyEquivalent: ",")
    private let togglePreviewEnabledItem = NSMenuItem(title: "Enable camera preview", action: #selector(togglePreviewEnabledFromMenu), keyEquivalent: "")
    private let toggleSleepDetectionItem = NSMenuItem(title: "Enable sleep detection", action: #selector(toggleSleepDetectionFromMenu), keyEquivalent: "")
    private let toggleOverlayItem = NSMenuItem(title: "Hide overlay", action: #selector(toggleOverlayFromMenu), keyEquivalent: "")
    private let recenterItem = NSMenuItem(title: "Re-center by notch", action: #selector(recenterFromMenu), keyEquivalent: "")
    private let toggleInteractionItem = NSMenuItem(title: "Lock overlay (ignore clicks)", action: #selector(toggleInteractionFromMenu), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit NotchCam", action: #selector(quitFromMenu), keyEquivalent: "q")
    private let preferences = PreferencesStore()
    @MainActor private lazy var preferencesWindowController = PreferencesWindowController(controller: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        showDockIcon = preferences.showDockIcon
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        cameraPreviewEnabled = preferences.cameraPreviewEnabled
        sleepDetectionEnabled = preferences.sleepDetectionEnabled
        configureStatusItem()

        NotificationCenter.default.addObserver(self,
                                              selector: #selector(openPreferencesFromNotification),
                                              name: .notchCamOpenPreferences,
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(testBannerFromNotification),
                                              name: .notchCamTestBanner,
                                              object: nil)

        cameraCoordinator.$authorization
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.cameraAuthorization = state
                self?.refreshStatusMenu()
                guard let self else { return }
                if self.isTemporaryActivationPolicy,
                   !self.showDockIcon,
                   state != .requesting {
                    self.isTemporaryActivationPolicy = false
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            .store(in: &cancellables)

        sleepDetector.bindFrames(from: cameraCoordinator.frames.eraseToAnyPublisher())
        sleepDetector.sleepDetected
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    let controller = self.notchNotification ?? {
                        let created = NotchNotificationController()
                        self.notchNotification = created
                        return created
                    }()
                    controller.showSleepDetected()
                }
            }
            .store(in: &cancellables)

        $cameraPreviewEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.preferences.cameraPreviewEnabled = enabled
                self?.applyPreviewVisibility()
                self?.applyCapturePipelineState()
                self?.refreshStatusMenu()
            }
            .store(in: &cancellables)

        $sleepDetectionEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.preferences.sleepDetectionEnabled = enabled
                self?.sleepDetector.setEnabled(enabled)
                self?.applyCapturePipelineState()
                self?.refreshStatusMenu()
            }
            .store(in: &cancellables)

        $showDockIcon
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.preferences.showDockIcon = enabled
                NSApp.setActivationPolicy(enabled ? .regular : .accessory)
            }
            .store(in: &cancellables)

        sleepDetector.setEnabled(sleepDetectionEnabled)
        applyPreviewVisibility()
        overlayController.bindLifecycleEvents()
        applyCapturePipelineState()

#if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.statusItem.button?.window == nil {
                NSApp.setActivationPolicy(.regular)
                Task { @MainActor in
                    self.preferencesWindowController.show()
                }
            }
        }
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayController.shutdown()
        cameraCoordinator.shutdown()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let modesHeader = NSMenuItem(title: "Modes", action: nil, keyEquivalent: "")
        modesHeader.isEnabled = false
        menu.addItem(modesHeader)

        menu.addItem(makeDockItem(title: "Notifications only", selector: #selector(setNotificationsOnlyMode), isActive: sleepDetectionEnabled && !cameraPreviewEnabled))
        menu.addItem(makeDockItem(title: "Camera only", selector: #selector(setCameraOnlyMode), isActive: cameraPreviewEnabled && !sleepDetectionEnabled))
        menu.addItem(makeDockItem(title: "Camera + notifications", selector: #selector(setBothMode), isActive: cameraPreviewEnabled && sleepDetectionEnabled))
        menu.addItem(makeDockItem(title: "Off", selector: #selector(setOffMode), isActive: !cameraPreviewEnabled && !sleepDetectionEnabled))

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openPreferencesFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit NotchCam", action: #selector(quitFromMenu), keyEquivalent: "")

        menu.items.forEach { $0.target = self }
        return menu
    }

    func toggleOverlayVisibility() {
        guard cameraPreviewEnabled else { return }
        overlayVisible.toggle()
        overlayVisible ? overlayController.showWindow() : overlayController.hideWindow()
        refreshStatusMenu()
    }

    func recenterOverlayNearNotch() {
        guard cameraPreviewEnabled else { return }
        overlayController.snapToPreferredPosition()
    }

    func toggleOverlayInteractionLock() {
        guard cameraPreviewEnabled else { return }
        overlayAcceptsInteraction = !overlayController.toggleShield()
        refreshStatusMenu()
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.toolTip = "NotchCam"
            if let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "NotchCam") {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "NC"
            }
        }
        statusItem.isVisible = true
        statusHeaderItem.isEnabled = false
        preferencesItem.target = self
        togglePreviewEnabledItem.target = self
        toggleSleepDetectionItem.target = self
        toggleOverlayItem.target = self
        recenterItem.target = self
        toggleInteractionItem.target = self
        quitItem.target = self

        statusMenu.addItem(statusHeaderItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(preferencesItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(togglePreviewEnabledItem)
        statusMenu.addItem(toggleSleepDetectionItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(toggleOverlayItem)
        statusMenu.addItem(recenterItem)
        statusMenu.addItem(toggleInteractionItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)
        statusItem.menu = statusMenu
        refreshStatusMenu()
    }

    private func refreshStatusMenu() {
        statusHeaderItem.title = "Capture status: \(cameraStatusLabel)"
        togglePreviewEnabledItem.title = cameraPreviewEnabled ? "Disable camera preview" : "Enable camera preview"
        togglePreviewEnabledItem.state = cameraPreviewEnabled ? .on : .off

        toggleSleepDetectionItem.title = sleepDetectionEnabled ? "Disable sleep detection" : "Enable sleep detection"
        toggleSleepDetectionItem.state = sleepDetectionEnabled ? .on : .off

        toggleOverlayItem.title = overlayVisible ? "Hide overlay" : "Show overlay"
        toggleOverlayItem.isEnabled = cameraPreviewEnabled
        recenterItem.isEnabled = cameraPreviewEnabled
        toggleInteractionItem.isEnabled = cameraPreviewEnabled
        toggleInteractionItem.title = overlayAcceptsInteraction ? "Lock overlay (ignore clicks)" : "Unlock overlay"
    }

    private var cameraStatusLabel: String {
        guard cameraPreviewEnabled || sleepDetectionEnabled else { return "Off" }
        switch cameraAuthorization {
        case .authorized: return "Live"
        case .requesting: return "Waiting on permission"
        case .denied: return "Camera blocked"
        case .unavailable: return "Camera unavailable"
        case .idle: return "Idle"
        }
    }

    @objc private func toggleOverlayFromMenu() {
        toggleOverlayVisibility()
    }

    @objc private func recenterFromMenu() {
        recenterOverlayNearNotch()
    }

    @objc private func toggleInteractionFromMenu() {
        toggleOverlayInteractionLock()
    }

    @objc private func quitFromMenu() {
        quitApp()
    }

    @objc private func openPreferencesFromMenu() {
        Task { @MainActor in
            preferencesWindowController.show()
        }
    }

    @objc private func openPreferencesFromNotification(_ notification: Notification) {
        openPreferencesFromMenu()
    }

    @objc private func testBannerFromNotification(_ notification: Notification) {
        Task { @MainActor in
            let controller = notchNotification ?? {
                let created = NotchNotificationController()
                notchNotification = created
                return created
            }()
            controller.showSleepDetected()
        }
    }

    @objc private func togglePreviewEnabledFromMenu() {
        cameraPreviewEnabled.toggle()
    }

    @objc private func toggleSleepDetectionFromMenu() {
        sleepDetectionEnabled.toggle()
    }

    @objc private func setNotificationsOnlyMode() {
        setMode(cameraPreview: false, sleepDetection: true)
    }

    @objc private func setCameraOnlyMode() {
        setMode(cameraPreview: true, sleepDetection: false)
    }

    @objc private func setBothMode() {
        setMode(cameraPreview: true, sleepDetection: true)
    }

    @objc private func setOffMode() {
        setMode(cameraPreview: false, sleepDetection: false)
    }

    private func setMode(cameraPreview: Bool, sleepDetection: Bool) {
        cameraPreviewEnabled = cameraPreview
        sleepDetectionEnabled = sleepDetection
    }

    private func applyPreviewVisibility() {
        if cameraPreviewEnabled {
            overlayVisible = true
            overlayController.showWindow()
        } else {
            overlayVisible = false
            overlayController.hideWindow()
        }
    }

    private func applyCapturePipelineState() {
        let shouldCapture = cameraPreviewEnabled || sleepDetectionEnabled
        if shouldCapture {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                if !showDockIcon {
                    isTemporaryActivationPolicy = true
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            cameraCoordinator.activateCapturePipeline()
        } else {
            cameraCoordinator.shutdown()
        }
    }

    private func makeDockItem(title: String,
                              selector: Selector,
                              isActive: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.state = isActive ? .on : .off
        return item
    }
}
