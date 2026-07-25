import SwiftUI

/// HIG 최소 터치 타깃(44×44pt) 정책.
/// 시각 크기(Figma 실측)가 이보다 작은 컨트롤은 보이는 크기는 그대로 두고,
/// 보이지 않는 히트 영역만 이 크기까지 확장한다 (버튼·내비 슬롯 등 공용).
public enum CHALLAHitTarget {

    /// HIG 최소 터치 타깃 한 변 길이.
    public static let minimum: CGFloat = 44

    /// 시각 크기에 대해 사방으로 필요한 히트 영역 확장량. 44 이상이면 0.
    public static func inset(for visibleSize: CGFloat) -> CGFloat {
        max(0, (minimum - visibleSize) / 2)
    }
}

extension InsettableShape {

    /// 시각 크기는 그대로 두고, 히트 영역만 HIG 최소 터치 타깃(44)까지 넓힌 도형을 돌려준다.
    /// SwiftUI의 `inset(by:)`(양수 = 축소)에 음수를 넘기는 방향 반전을 이 안에 숨긴다.
    ///
    /// ```swift
    /// .contentShape(Rectangle().expandedToHitTarget(from: 40))  // 히트 영역 40 → 44
    /// ```
    func expandedToHitTarget(from visibleSize: CGFloat) -> some InsettableShape {
        inset(by: -CHALLAHitTarget.inset(for: visibleSize))
    }
}
