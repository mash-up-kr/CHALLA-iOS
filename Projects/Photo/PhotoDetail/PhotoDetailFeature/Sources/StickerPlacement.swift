import Foundation

/// 스티커 한 개의 위치. 사진 크기와 무관하게 쓰도록 비율로 저장한다.
public struct StickerPlacement: Sendable, Hashable {

    /// 사진 가로 기준 스티커 중심 위치 (0~1).
    public let xRatio: Double
    /// 사진 세로 기준 스티커 중심 위치 (0~1).
    public let yRatio: Double
    /// 기울기(도). 음수는 반시계 방향.
    public let angleDegrees: Double

    public init(xRatio: Double, yRatio: Double, angleDegrees: Double) {
        self.xRatio = xRatio
        self.yRatio = yRatio
        self.angleDegrees = angleDegrees
    }
}
