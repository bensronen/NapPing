import SwiftUI

struct PreferencesView: View {
    @ObservedObject var controller: AppDelegate

    var body: some View {
        Form {
            Section("Modes") {
                Toggle("Show Dock icon", isOn: $controller.showDockIcon)
                Toggle("Camera preview overlay", isOn: $controller.cameraPreviewEnabled)
                Toggle("Sleep detection", isOn: $controller.sleepDetectionEnabled)
                Toggle("Pause media when everyone sleeps (1 minute)", isOn: $controller.pauseWhenAllEyesClosedEnabled)
                Text("Sleep detection uses the camera even if preview is disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                Button("Test “Sleep detected” banner") {
                    NotificationCenter.default.post(name: .notchCamTestBanner, object: nil)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
