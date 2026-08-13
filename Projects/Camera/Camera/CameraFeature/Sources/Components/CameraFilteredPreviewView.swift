import CoreImage
import MetalKit
import os
import SwiftUI

/// 실시간 프리뷰 프레임 공급자. 실 구현(카메라 세션)은 앱 조립 지점이 소유한다 —
/// 이 모듈은 하드웨어를 모르고, 조립 지점이 LUT를 입힌 프레임을 이 통로로 흘려보낸다.
public protocol CameraPreviewFrameSource: AnyObject {
    /// 표시할 프레임 콜백. 공급자의 프레임 큐에서 불린다 — 소비자가 스레드를 넘긴다.
    var onPreviewImage: (@Sendable (CIImage) -> Void)? { get set }
}

/// LUT가 입혀진 프리뷰 프레임(`CIImage`)을 Metal로 그리는 뷰. `CameraView`의 `preview` 슬롯에 넣는다.
/// `AVCaptureVideoPreviewLayer`는 원본 피드 전용이라 실시간 필터를 못 얹어서 직접 그린다.
public struct CameraFilteredPreviewView: UIViewRepresentable {

    private let source: CameraPreviewFrameSource

    /// - Parameters:
    ///   - source: 프레임 공급자. 콜백은 이 뷰가 걸고, 뷰가 사라지면 끊는다.
    public init(source: CameraPreviewFrameSource) {
        self.source = source
    }

    public func makeCoordinator() -> Renderer {
        Renderer()
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.framebufferOnly = false // CIContext가 드로어블 텍스처에 직접 쓴다
        view.backgroundColor = .black
        view.delegate = context.coordinator

        let renderer = context.coordinator
        renderer.source = source
        source.onPreviewImage = { image in
            renderer.enqueue(image)
        }
        return view
    }

    public func updateUIView(_: MTKView, context _: Context) {}

    public static func dismantleUIView(_: MTKView, coordinator: Renderer) {
        // 사라진 뷰의 렌더러가 프레임을 계속 받지 않게 끊는다
        coordinator.source?.onPreviewImage = nil
    }

    /// 카메라 프레임을 드로어블에 aspect-fill로 그린다. 프레임 수신(공급자 큐)과
    /// 그리기(MTKView 드로우 루프)가 스레드가 달라 최신 프레임을 락으로 주고받는다.
    public final class Renderer: NSObject, MTKViewDelegate, @unchecked Sendable {

        weak var source: CameraPreviewFrameSource?

        let device = MTLCreateSystemDefaultDevice()

        private lazy var commandQueue = device?.makeCommandQueue()
        private lazy var ciContext = device.map { CIContext(mtlDevice: $0) }
        /// CIImage는 불변 객체라 스레드 간 전달이 안전하지만, 구 SDK(CI의 Xcode)에는 Sendable 표기가
        /// 없어 unchecked 계열 API를 쓴다 — 최신 SDK에서만 통과하는 코드를 만들지 않는다.
        private let latestImage = OSAllocatedUnfairLock<CIImage?>(uncheckedState: nil)

        func enqueue(_ image: CIImage) {
            latestImage.withLockUnchecked { $0 = image }
        }

        public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

        public func draw(in view: MTKView) {
            guard let image = latestImage.withLockUnchecked({ $0 }),
                  let ciContext,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer()
            else { return }

            let drawableSize = view.drawableSize
            guard image.extent.width > 0, image.extent.height > 0,
                  drawableSize.width > 0, drawableSize.height > 0
            else { return }

            // aspect-fill: 짧은 변을 드로어블에 맞추고 긴 변은 중앙 크롭
            let scale = max(
                drawableSize.width / image.extent.width,
                drawableSize.height / image.extent.height
            )
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let cropOrigin = CGPoint(
                x: scaled.extent.midX - drawableSize.width / 2,
                y: scaled.extent.midY - drawableSize.height / 2
            )

            ciContext.render(
                scaled,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: cropOrigin, size: drawableSize),
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
