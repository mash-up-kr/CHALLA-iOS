@testable import CHALLADesignSystem
import SwiftUI
import Testing

/// HIG 최소 터치 타깃(44pt) 인셋 계산 검증.
/// 히트 영역은 화면에 보이지 않아 계산이 틀려도 눈으로는 잡을 수 없고
/// 터치만 어긋나므로, 경계값과 확장 후 최종 크기를 테스트로 고정한다.
struct CHALLAHitTargetTests {

    /// 40은 버튼 small 시각 높이, 43은 홀수 부족분(0.5pt 인셋) 확인용이다.
    @Test("44 미만이면 모자란 만큼의 절반씩 인셋한다", arguments: zip(
        [28, 36, 40, 43] as [CGFloat],
        [8, 4, 2, 0.5] as [CGFloat]
    ))
    func insetIsHalfOfDeficit(visibleSize: CGFloat, expected: CGFloat) {
        #expect(CHALLAHitTarget.inset(for: visibleSize) == expected)
    }

    @Test("44 미만이면 사방 인셋을 더한 최종 크기가 정확히 44다", arguments: [28, 36, 40, 43] as [CGFloat])
    func expandedSizeReachesMinimum(visibleSize: CGFloat) {
        let expanded = visibleSize + CHALLAHitTarget.inset(for: visibleSize) * 2
        #expect(expanded == CHALLAHitTarget.minimum)
    }

    @Test("44 이상이면 인셋이 0이다 — 음수 인셋으로 히트 영역이 줄지 않는다", arguments: [44, 48, 100] as [CGFloat])
    func noInsetAtOrAboveMinimum(visibleSize: CGFloat) {
        #expect(CHALLAHitTarget.inset(for: visibleSize) == 0)
    }
}
