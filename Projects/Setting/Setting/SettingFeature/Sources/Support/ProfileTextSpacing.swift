import CHALLADesignSystem
import SwiftUI

/// 프로필 닉네임과 이메일 사이 간격 — 시안 4.
///
/// `challaFont`가 두 글자 상자에 각각 `lineBoxInset`을 더하므로 그만큼 빼야 화면에서 4로 보인다.
/// 설정 메인 헤더와 계정 관리 요약이 같은 값을 쓴다.
enum ProfileTextSpacing {

    static let nicknameToEmail: CGFloat = max(
        0,
        4 - CHALLATypography.body.medium.bold.lineBoxInset
            - CHALLATypography.body.medium.regular.lineBoxInset
    )
}
