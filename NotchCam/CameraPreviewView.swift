import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.videoGravity = .resizeAspectFill
        view.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewLayerView, context: Context) {
        nsView.session = session
    }

    final class PreviewLayerView: NSView {
        var session: AVCaptureSession? {
            didSet {
                previewLayer.session = session
            }
        }

        var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
            didSet { previewLayer.videoGravity = videoGravity }
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func makeBackingLayer() -> CALayer {
            let layer = AVCaptureVideoPreviewLayer()
            layer.videoGravity = videoGravity
            return layer
        }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                let newLayer = AVCaptureVideoPreviewLayer()
                self.layer = newLayer
                return newLayer
            }
            return layer
        }
    }
}
