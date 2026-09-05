import CoreGraphics
import SwiftUI

/// 인화 완료 안내에서 "여기를 당기세요"를 알리는 움직임.
///
/// 필름이 조금 더 나왔다 들어가기를 두 번 한다. 손이 닿으면 멈추고 다시 시작하지 않는다.
@MainActor
@Observable
final class PrintNoticeHint {

    /// 지금 이동량. 화면이 이 값을 필름과 툴팁에 함께 더한다.
    private(set) var offset: CGFloat = 0

    private var isStopped = false
    private var didStart = false

    /// 움직임을 시작한다. 사진 로딩과 시간제한 중 먼저 온 쪽이 부르므로 한 번만 걸린다.
    func start(delay: TimeInterval) {
        guard !didStart, !isStopped else { return }
        didStart = true
        bob(remaining: Const.count, delay: delay)
    }

    /// 손이 닿으면 멈춘다 — 손가락을 따라가는 동안 필름이 혼자 움직이면 안 된다.
    func stop() {
        isStopped = true
        guard offset != 0 else { return }
        withAnimation(.easeOut(duration: Const.stopDuration)) {
            offset = 0
        }
    }

    /// 내려갔다 올라오기를 `remaining`번 반복한다.
    ///
    /// `repeatCount(autoreverses:)`를 쓰지 않는다 — 그쪽은 반복이 끝나도 값이 목표치에 남아 있어,
    /// 도중에 다른 이유로 다시 그려지면 필름이 튄다. 한 번씩 이어 붙이면 항상 0에서 끝난다.
    private func bob(remaining: Int, delay: TimeInterval = 0) {
        guard remaining > 0, !isStopped else { return }

        // 내려갈 때만 튕긴다. 올라올 때 제자리를 넘어서면 필름이 출구 안으로 들어가 보인다.
        withAnimation(.spring(duration: Const.pullDuration, bounce: Const.bounce).delay(delay)) {
            offset = PrintNoticeMetric.hintDistance
        } completion: {
            withAnimation(.spring(duration: Const.returnDuration, bounce: 0)) {
                self.offset = 0
            } completion: {
                self.bob(remaining: remaining - 1)
            }
        }
    }

    private enum Const {
        /// 내려갔다 올라오기를 두 번.
        static let count = 2
        /// 내려갈 때. 튕김을 줘서 조금 더 당기고 싶게 만든다.
        static let pullDuration: TimeInterval = 0.42
        static let bounce: CGFloat = 0.45
        /// 올라올 때. 제자리를 넘지 않도록 튕김 없이 돌아온다.
        static let returnDuration: TimeInterval = 0.5
        static let stopDuration: TimeInterval = 0.15
    }
}
