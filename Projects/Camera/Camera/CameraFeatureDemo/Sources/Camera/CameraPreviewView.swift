@preconcurrency import AVFoundation
import SwiftUI

/// `AVCaptureVideoPreviewLayer`를 SwiftUI에 얹는다. SwiftUI에 대응 API가 없어 UIKit을 빌린다.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context _: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_: PreviewUIView, context _: Context) {}

    final class PreviewUIView: UIView {

        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        /// layerClass가 항상 AVCaptureVideoPreviewLayer를 만든다.
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("layerClass가 AVCaptureVideoPreviewLayer.self를 반환하지 않음")
            }
            return previewLayer
        }
    }
}
