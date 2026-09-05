import CoreGraphics
import SwiftUI

/// 인화 완료 안내에서 "여기를 당기세요"를 알리는 움직임.
///
/// 툴팁이 아래로 두 번 튕긴다. 필름은 움직이지 않는다 — 함께 움직이면
/// 출구에서 밀려 나왔다 들어가는 것처럼 보여 무겁다. 손이 닿으면 멈추고 다시 시작하지 않는다.
@MainActor
@Observable
final class PrintNoticeHint {

    /// 지금 이동량. 화면이 이 값을 툴팁에 더한다.
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

        // 짧게 챈 뒤 감쇠가 낮은 스프링으로 놓는다. 놓을 때 제자리를 여러 번 넘나들며 잦아드는데,
        // 그 오르내림이 "튕긴다"로 보인다. 감쇠를 높이면(bounce가 낮으면) 튕김이 아니라 밀림이 된다.
        //
        // 제자리를 넘어가도 툴팁이 살짝 올라갈 뿐이라 가려지는 것이 없다.
        withAnimation(.spring(duration: Const.pullDuration, bounce: Const.pullBounce).delay(delay)) {
            offset = PrintNoticeMetric.hintDistance
        } completion: {
            withAnimation(.spring(duration: Const.returnDuration, bounce: Const.returnBounce)) {
                self.offset = 0
            } completion: {
                self.bob(remaining: remaining - 1)
            }
        }
    }

    private enum Const {
        /// 내려갔다 올라오기를 두 번.
        static let count = 2
        /// 챌 때 — 짧게. 튕김은 놓을 때 나오므로 여기서는 거의 주지 않는다.
        static let pullDuration: TimeInterval = 0.14
        static let pullBounce: CGFloat = 0.3
        /// 놓을 때 — 감쇠가 낮아 제자리를 여러 번 넘나들며 잦아든다.
        static let returnDuration: TimeInterval = 0.3
        static let returnBounce: CGFloat = 0.7
        static let stopDuration: TimeInterval = 0.15
    }
}
