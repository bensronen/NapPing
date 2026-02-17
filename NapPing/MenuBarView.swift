import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow
            Divider()
            Button(controller.overlayVisible ? "Hide overlay" : "Show overlay") {
                controller.toggleOverlayVisibility()
            }
            Button("Re-center by notch") {
                controller.recenterOverlayNearNotch()
            }
            Button(controllerTextForShield) {
                controller.toggleOverlayInteractionLock()
            }
            Divider()
            Button(role: .destructive) {
                controller.quitApp()
            } label: {
                Label("Quit NapPing", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .padding(12)
        .frame(width: 220)
    }

    private var statusRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.callout)
            }
        }
    }

    private var statusText: String {
        switch controller.cameraAuthorization {
        case .authorized: return "Live"
        case .requesting: return "Waiting on permission"
        case .denied: return "Camera blocked"
        case .unavailable: return "Camera unavailable"
        case .idle: return "Idle"
        }
    }

    private var controllerTextForShield: String {
        controller.overlayAcceptsInteraction ? "Lock overlay (ignore clicks)" : "Unlock overlay"
    }
}
