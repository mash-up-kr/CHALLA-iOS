import CoreGraphics
import Foundation

/// 뷰파인더 배율. 두 손가락 핀치(연속)와 배율 버튼 탭(순환) 두 경로로 바뀐다.
public struct CameraZoom: Equatable, Sendable {

    public static let range: ClosedRange<CGFloat> = 1 ... 8

    /// 배율 버튼을 탭할 때 순환하는 값. 실기기 렌즈 구성이 붙으면 그 값으로 교체한다.
    static let tapCycle: [CGFloat] = [1, 2, 3]

    public private(set) var factor: CGFloat

    /// 핀치 시작 시점의 배율. 제스처 중 누적 배율(magnification)의 기준점이 된다.
    private var pinchBaseFactor: CGFloat

    public init(factor: CGFloat = range.lowerBound) {
        let clamped = Self.clamp(factor)
        self.factor = clamped
        self.pinchBaseFactor = clamped
    }

    /// 배율 버튼에 표시할 문구. 정수 배율은 소수점을 떼고(`2x`), 그 외는 한 자리까지(`1.5x`).
    public var label: String {
        let rounded = (factor * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))x"
            : "\(rounded)x"
    }

    mutating func magnify(by magnification: CGFloat) {
        factor = Self.clamp(pinchBaseFactor * magnification)
    }

    /// 제스처가 끝나면 다음 핀치가 지금 배율에서 이어지도록 기준점을 옮긴다.
    mutating func endMagnifying() {
        pinchBaseFactor = factor
    }

    mutating func cycle() {
        let next = Self.tapCycle.first { $0 > factor } ?? Self.tapCycle[0]
        factor = Self.clamp(next)
        pinchBaseFactor = factor
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
