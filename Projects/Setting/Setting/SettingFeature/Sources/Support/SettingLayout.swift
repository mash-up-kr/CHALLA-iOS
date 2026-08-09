import CHALLADesignSystem
import SwiftUI

/// 설정 화면군(메인 + 하위 3화면)이 공유하는 레이아웃 값.
///
/// 네 화면이 같은 시안 그리드를 쓴다 — 여기 없는 값만 각 화면의 `Metric`에 둔다.
enum SettingLayout {

    /// 카드 좌우 여백 — 390 기준 카드 폭 358.
    static let horizontalPadding: CGFloat = 16

    /// 탑 내비 아래 첫 요소까지 — 시안 실측 8.
    static let contentTopPadding: CGFloat = 8

    /// 카드 사이 세로 간격 — 시안 실측 16.
    static let cardSpacing: CGFloat = 16

    static let bottomPadding: CGFloat = 24

    /// 행 leading 아이콘 색.
    ///
    /// Zeplin `List / Arrow` 컴포넌트 정의는 `Label.neutral`(#AEAFB4)인데 설정 화면 인스턴스는
    /// `Label.alternative`(#74767B)다. 시안 대조가 화면 기준이라 화면을 따른다.
    /// TODO: 어느 쪽이 맞는지 디자이너 확정 필요.
    static let rowIconColor = CHALLAColor.Label.alternative

    /// 지원하는 접근성 글꼴 상한.
    ///
    /// 시안이 픽셀 고정 명세라 행·프로필 블록 높이가 상수다. 그 이상 키우면 글자가 잘린다
    /// (`MODULE.md`의 "시안 대비 알려진 차이").
    static let maxDynamicTypeSize: DynamicTypeSize = .accessibility1
}
