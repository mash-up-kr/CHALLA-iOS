@testable import CHALLADesignSystem
import SwiftUI
import Testing
import UIKit

/// 섹션 카드의 세로 치수 검증.
///
/// 헤더 높이를 `challaFont` 패딩 합으로 만들던 시절, 코드는 44를 의도했지만 화면에는 45.7이 나왔다 —
/// SwiftUI `Text`가 시안의 줄 높이(16)가 아니라 폰트 고유 줄 높이(SUIT 14pt ≈ 17.7)로 그려지기 때문이다.
/// 눈으로는 카드 한 장에 1.7 차이라 놓치기 쉽고 카드를 쌓을수록 누적되므로, 수치로 잡아둔다.
@MainActor
struct CHALLAListSectionLayoutTests {

    /// 시안 카드 폭 (화면 390 - 좌우 16씩).
    private static let cardWidth: CGFloat = 358

    init() {
        // 폰트가 등록돼야 실제 화면과 같은 조건에서 잰다.
        // (등록 전에는 시스템 폰트로 대체돼 글자 상자 높이가 달라진다)
        CHALLAFontRegister.register()
    }

    @Test("헤더 블록 높이는 폰트 렌더링과 무관하게 시안값 44다")
    func headerBlockHeightMatchesDesign() {
        let withHeader = measuredHeight {
            CHALLAListSection("앱 설정") { CHALLAListRow("테마", icon: .palette) {} }
        }
        let withoutHeader = measuredHeight {
            CHALLAListSection { CHALLAListRow("테마", icon: .palette) {} }
        }

        // 두 카드는 헤더 유무만 다르므로 차이가 곧 헤더 블록 높이다.
        #expect(abs(withHeader - withoutHeader - 44) < 0.5)
    }

    @Test("설정 화면 첫 카드 높이는 시안 168이다")
    func settingScreenFirstCardMatchesDesign() {
        // 10(카드 위 여백) + 44(헤더) + 52 + 52(행 두 개) + 10(카드 아래 여백)
        let height = measuredHeight {
            CHALLAListSection("앱 설정") {
                CHALLAListRow("테마", icon: .palette, accessory: .arrow(value: "레몬에이드")) {}
                CHALLAListRow("알림", icon: .bellSimple) {}
            }
        }

        #expect(abs(height - 168) < 0.5)
    }

    @Test("헤더 없는 카드는 여백과 행 높이의 합뿐이다")
    func cardWithoutHeaderMatchesDesign() {
        let height = measuredHeight {
            CHALLAListSection { CHALLAListRow("텍스트", icon: .setting) {} }
        }

        #expect(abs(height - (10 + 52 + 10)) < 0.5)
    }

    @Test("헤더 높이는 제목 글자 수에 흔들리지 않는다")
    func headerHeightIsIndependentOfTitleLength() {
        let short = measuredHeight { CHALLAListSection("계정") { CHALLAListRow("텍스트") {} } }
        let long = measuredHeight {
            CHALLAListSection("카메라 및 마이크 접근 권한 설정 화면으로 이동") { CHALLAListRow("텍스트") {} }
        }

        #expect(abs(short - long) < 0.5)
    }

    /// 시안 카드 폭을 제안했을 때 뷰가 잡는 실제 높이.
    private func measuredHeight(@ViewBuilder _ content: () -> some View) -> CGFloat {
        let controller = UIHostingController(rootView: content().frame(width: Self.cardWidth))
        let proposal = CGSize(width: Self.cardWidth, height: UIView.layoutFittingExpandedSize.height)
        return controller.sizeThatFits(in: proposal).height
    }
}
