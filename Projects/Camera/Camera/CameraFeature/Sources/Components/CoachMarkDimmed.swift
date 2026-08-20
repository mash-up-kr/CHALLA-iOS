import SwiftUI

extension View {

    /// 안내 스낵바가 떠 있는 동안 조연으로 물러나는 영역.
    /// 시안은 밝기만 20%로 낮추는데(딤 레이어 아님), 그 상태로 눌리면 보이지 않는 버튼을 누르는 셈이라
    /// 조작도 함께 막는다.
    ///
    /// 조작 차단에 `.disabled`를 쓰면 SwiftUI가 비활성 렌더링을 덧입혀 밝기가 20%보다 더 떨어진다.
    /// 그리기는 건드리지 않는 `allowsHitTesting`으로 막는다.
    func coachMarkDimmed(_ isDimmed: Bool) -> some View {
        opacity(isDimmed ? CoachMarkDimmedMetric.opacity : 1)
            .allowsHitTesting(!isDimmed)
            .accessibilityHidden(isDimmed)
            .animation(.easeInOut(duration: CoachMarkDimmedMetric.animationDuration), value: isDimmed)
    }
}

// MARK: - Figma 실측값

private enum CoachMarkDimmedMetric {
    /// 필터 띠 · 하단 블록에 걸리는 밝기 (시안 opacity 0.2)
    static let opacity: Double = 0.2
    static let animationDuration: TimeInterval = 0.25
}
