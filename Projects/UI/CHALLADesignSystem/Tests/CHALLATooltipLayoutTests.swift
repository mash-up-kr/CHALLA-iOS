@testable import CHALLADesignSystem
import SwiftUI
import Testing
import UIKit

/// 툴팁 뷰의 실제 레이아웃 치수 검증.
///
/// `frame(maxWidth:) + fixedSize` 조합이던 시절, 여러 줄 문구에서 측정 높이와 배치 높이가
/// 어긋나 글자가 배경 밖으로 넘쳤다 — 상수 비교로는 못 잡고 실제 레이아웃을 재야 보인다.
@MainActor
struct CHALLATooltipLayoutTests {

    private static let multiline =
        "사진이 모두 인화되면 알려드릴게요. 인화가 끝날 때까지 잠시만 기다려 주세요. 완성된 사진은 보관함에서 다시 볼 수 있어요."

    init() {
        // 폰트가 등록돼야 실제 화면과 같은 조건에서 잰다.
        CHALLAFontRegister.register()
    }

    @Test("짧은 문구는 최소 폭 64에 머무르고 상한까지 늘어나지 않는다")
    func shortMessageHugsMinWidth() {
        let size = measuredSize(CHALLATooltip("확인"))
        #expect(abs(size.width - 64) < 0.5)
    }

    @Test("여러 줄 문구는 측정 높이와 배치 높이가 같다 — 배경 밖 글자 넘침 회귀")
    func multilineReportedHeightMatchesPlacement() {
        for position in [CHALLATooltip.Position.top, .leading, .trailing] {
            let tooltip = CHALLATooltip(Self.multiline, position: position)
            let free = measuredSize(tooltip)
            let pinned = measuredSize(tooltip.frame(width: free.width))
            #expect(abs(free.height - pinned.height) < 0.5, "\(position)")
        }
    }

    @Test("여러 줄 문구는 폭 상한(내용 256 + 여백)을 지키고 세로로 자란다")
    func multilineWrapsAtContentMaxWidth() {
        let single = measuredSize(CHALLATooltip("확인"))
        let multi = measuredSize(CHALLATooltip(Self.multiline))
        #expect(multi.width <= 276.5)
        // 세 줄 문구 — 최소 두 줄 높이(28)만큼은 더 커야 한다.
        #expect(multi.height > single.height + 20)
    }

    /// 넉넉한 폭을 제안했을 때 뷰가 잡는 실제 크기.
    private func measuredSize(_ view: some View) -> CGSize {
        let controller = UIHostingController(rootView: view)
        let proposal = CGSize(width: 2000, height: UIView.layoutFittingExpandedSize.height)
        return controller.sizeThatFits(in: proposal)
    }
}
