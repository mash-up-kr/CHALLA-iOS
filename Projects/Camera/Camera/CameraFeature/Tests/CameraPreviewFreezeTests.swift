@testable import CameraFeature
import CoreImage
import Testing

/// 셔터를 누른 순간 프리뷰가 멈춰야 한다 — 스틸 촬영이 끝나기까지의 텀 동안에도 찍은 장면이 남게 하는 장치다.
@Suite("CameraFilteredPreviewView — 프리뷰 정지")
struct CameraPreviewFreezeTests {

    private static func frame(brightness: CGFloat) -> CIImage {
        CIImage(color: CIColor(red: brightness, green: brightness, blue: brightness))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    @Test("얼어 있는 동안 들어온 프레임은 버리고 직전 프레임을 그대로 둔다")
    func frozenRendererKeepsLastFrame() {
        let renderer = CameraFilteredPreviewView.Renderer()
        let captured = Self.frame(brightness: 0.2)
        renderer.enqueue(captured)

        renderer.setFrozen(true)
        renderer.enqueue(Self.frame(brightness: 0.9))

        #expect(renderer.latestPreviewImage == captured)
    }

    @Test("정지를 풀면 다시 새 프레임을 받는다 — 촬영이 실패해 화면으로 돌아온 경우")
    func unfrozenRendererResumes() {
        let renderer = CameraFilteredPreviewView.Renderer()
        renderer.setFrozen(true)
        renderer.enqueue(Self.frame(brightness: 0.2))

        renderer.setFrozen(false)
        let resumed = Self.frame(brightness: 0.9)
        renderer.enqueue(resumed)

        #expect(renderer.latestPreviewImage == resumed)
    }
}
