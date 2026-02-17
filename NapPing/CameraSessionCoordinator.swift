import AVFoundation
import Combine

final class CameraSessionCoordinator: NSObject, ObservableObject {
    enum AuthorizationState: Equatable {
        case idle
        case requesting
        case authorized
        case denied
        case unavailable
    }

    @Published private(set) var authorization: AuthorizationState = .idle
    @Published private(set) var captureIssue: String?

    let session = AVCaptureSession()
    let frames = PassthroughSubject<CVPixelBuffer, Never>()

    private let sessionQueue = DispatchQueue(label: "com.napping.capture", qos: .userInteractive)
    private let videoOutputQueue = DispatchQueue(label: "com.napping.capture.frames", qos: .userInitiated)
    private var isConfigured = false
    private var isRequestingAccess = false
    private let videoDataOutput = AVCaptureVideoDataOutput()

    override init() {
        super.init()
        session.sessionPreset = .high
        authorization = Self.currentAuthorizationState()
    }

    func activateCapturePipeline() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            captureIssue = nil
            configureSessionIfNeeded()
        case .notDetermined:
            guard !isRequestingAccess else { return }
            isRequestingAccess = true
            authorization = .requesting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isRequestingAccess = false
                    self.authorization = granted ? .authorized : .denied
                    self.captureIssue = nil
                    if granted {
                        self.configureSessionIfNeeded()
                    }
                }
            }
        default:
            authorization = .denied
            captureIssue = nil
        }
    }

    func shutdown() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            startSessionIfNeeded()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                    ?? AVCaptureDevice.default(for: .video) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.authorization = .unavailable
                    self?.captureIssue = "No camera device is available."
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { [weak self] in
                        self?.authorization = .unavailable
                        self?.captureIssue = "Could not attach the camera input."
                    }
                    return
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.authorization = .unavailable
                    self?.captureIssue = "Camera setup failed: \(error.localizedDescription)"
                }
                return
            }

            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            DispatchQueue.main.async { [weak self] in
                self?.authorization = .authorized
                self?.captureIssue = nil
            }
            self.startSessionIfNeeded()
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private static func currentAuthorizationState() -> AuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .requesting
        default: return .denied
        }
    }
}

extension CameraSessionCoordinator: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frames.send(pixelBuffer)
    }
}
