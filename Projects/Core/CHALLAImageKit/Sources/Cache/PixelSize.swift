import CoreGraphics
import Foundation

/// 캐시 키·다운샘플링에 쓰이는 정수 픽셀 크기.
///
/// SwiftUI/UIKit의 포인트(pt)와 디스플레이 배율(scale)을 실제 픽셀로 환산해 보관한다.
/// 같은 100pt 뷰라도 @2x 기기는 200px, @3x 기기는 300px가 필요하므로,
/// 캐시 키에는 pt가 아니라 픽셀이 들어가야 기기별로 올바른 이미지가 구분된다.
public struct PixelSize: Hashable, Sendable {

    public let width: Int
    public let height: Int

    /// 정수 픽셀 값으로 직접 생성한다. 음수는 0으로 보정한다.
    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    /// 포인트 크기와 배율로부터 픽셀 크기를 계산한다.
    /// 부족하면 이미지가 뿌옇게 보이므로 올림(`ceil`)한다.
    public init(pointSize: CGSize, scale: CGFloat) {
        self.init(
            width: Int(ceil(pointSize.width * scale)),
            height: Int(ceil(pointSize.height * scale))
        )
    }
}
