import SwiftUI
import AppKit
import Foundation

struct OverlayRootView: View {
    @ObservedObject var cameraCoordinator: CameraSessionCoordinator
    private let mirrorScale: CGFloat = -1

    var body: some View {
        ZStack(alignment: .top) {
            previewLayer
            overlayChrome
        }
        .frame(minWidth: 1, idealWidth: 320, minHeight: 1, idealHeight: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var previewLayer: some View {
        switch cameraCoordinator.authorization {
        case .authorized:
            CameraPreviewView(session: cameraCoordinator.session)
                .scaleEffect(x: mirrorScale, y: 1)
                .overlay(GradientOverlay(), alignment: .bottom)
        case .requesting, .idle:
            VStack(spacing: 8) {
                ProgressView()
                Text("Waiting for camera permission…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            VStack(spacing: 10) {
                Image(systemName: "lock.slash")
                    .imageScale(.large)
                Text("Grant camera access in System Settings → Privacy & Security → Camera.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Button("Open Camera Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                Button("Check Again") {
                    cameraCoordinator.activateCapturePipeline()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable:
            VStack(spacing: 10) {
                Image(systemName: "video.slash")
                    .imageScale(.large)
                Text("Camera access is allowed, but capture couldn’t start.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if let issue = cameraCoordinator.captureIssue {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var overlayChrome: some View {
        HStack {
            Spacer()
            Button {
                NotificationCenter.default.post(name: .notchCamOpenPreferences, object: nil)
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(OverlayButtonStyle())
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(OverlayButtonStyle())
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

}

private struct GradientOverlay: View {
    var body: some View {
        LinearGradient(colors: [Color.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(.thinMaterial, in: Circle())
            .symbolVariant(configuration.isPressed ? .fill : .none)
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}
