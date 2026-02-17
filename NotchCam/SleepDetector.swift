import Foundation
import Combine
import Vision

final class SleepDetector: ObservableObject {
    struct Configuration: Equatable {
        var minimumClosedEyeSeconds: TimeInterval = 2.0
        var cooldownSeconds: TimeInterval = 12
        var processingIntervalSeconds: TimeInterval = 0.18
        var closedEyeRatioThreshold: CGFloat = 0.16
        var minimumFaceConfidence: VNConfidence = 0.4
    }

    @Published private(set) var isSleeping = false
    private var isEnabled = true

    let sleepDetected = PassthroughSubject<Void, Never>()

    private let configuration: Configuration
    private let processingQueue = DispatchQueue(label: "com.notchcam.sleepdetector", qos: .userInitiated)
    private var cancellables: Set<AnyCancellable> = []

    private var lastProcessedAt: CFAbsoluteTime = 0
    private var closedEyesSince: CFAbsoluteTime?
    private var lastNotificationAt: CFAbsoluteTime = 0
    private var hasEmittedForCurrentSleep = false
    private var isProcessing = false

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    func setEnabled(_ enabled: Bool) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            self.isEnabled = enabled
            if !enabled {
                self.closedEyesSince = nil
                self.hasEmittedForCurrentSleep = false
                DispatchQueue.main.async { [weak self] in
                    self?.isSleeping = false
                }
            }
        }
    }

    func bindFrames(from frames: AnyPublisher<CVPixelBuffer, Never>) {
        frames
            .receive(on: processingQueue)
            .sink { [weak self] pixelBuffer in
                self?.handleFrame(pixelBuffer)
            }
            .store(in: &cancellables)
    }

    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isEnabled else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard !isProcessing else { return }
        guard now - lastProcessedAt >= configuration.processingIntervalSeconds else { return }
        lastProcessedAt = now
        isProcessing = true

        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self else { return }
            defer { self.isProcessing = false }

            let faces = ((request.results as? [VNFaceObservation]) ?? [])
                .filter { $0.confidence >= self.configuration.minimumFaceConfidence }

            let anyClosed = faces.contains { self.areEyesClosed(face: $0) }
            self.updateSleepingState(anyEyesClosed: anyClosed, at: now)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            isProcessing = false
        }
    }

    private func updateSleepingState(anyEyesClosed: Bool, at now: CFAbsoluteTime) {
        if anyEyesClosed {
            closedEyesSince = closedEyesSince ?? now
        } else {
            closedEyesSince = nil
            hasEmittedForCurrentSleep = false
        }

        let closedDuration = closedEyesSince.map { now - $0 } ?? 0
        let sleepingNow = closedDuration >= configuration.minimumClosedEyeSeconds

        if !sleepingNow {
            hasEmittedForCurrentSleep = false
        }

        if sleepingNow,
           !hasEmittedForCurrentSleep,
           (now - lastNotificationAt) >= configuration.cooldownSeconds {
            lastNotificationAt = now
            hasEmittedForCurrentSleep = true
            DispatchQueue.main.async { [weak self] in
                self?.isSleeping = true
                self?.sleepDetected.send(())
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isSleeping = sleepingNow
        }
    }

    private func areEyesClosed(face: VNFaceObservation) -> Bool {
        guard let landmarks = face.landmarks else { return false }
        let left = eyeOpenRatio(landmark: landmarks.leftEye)
        let right = eyeOpenRatio(landmark: landmarks.rightEye)

        switch (left, right) {
        case let (.some(l), .some(r)):
            return ((l + r) / 2) < configuration.closedEyeRatioThreshold
        case let (.some(l), .none):
            return l < configuration.closedEyeRatioThreshold
        case let (.none, .some(r)):
            return r < configuration.closedEyeRatioThreshold
        case (.none, .none):
            return false
        }
    }

    private func eyeOpenRatio(landmark: VNFaceLandmarkRegion2D?) -> CGFloat? {
        guard let landmark else { return nil }
        let points = landmark.normalizedPoints
        guard points.count >= 4 else { return nil }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        let width = max(maxX - minX, 0.0001)
        let height = max(maxY - minY, 0)
        return height / width
    }
}
