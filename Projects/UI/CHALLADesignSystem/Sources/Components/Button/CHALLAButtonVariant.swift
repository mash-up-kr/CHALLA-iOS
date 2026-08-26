import SwiftUI

/// 버튼 스타일(변형). Text·Icon 버튼이 공유한다.
/// CaseIterable: 갤러리가 allCases로 전수 나열해 variant 추가 시 자동 반영되게 한다.
public enum CHALLAButtonVariant: Sendable, CaseIterable {
    /// 테마 버튼 — 테마 색 배경 + 검정 글자. 화면에서 가장 앞세우는 액션에 사용.
    /// 테마 색을 쓰는 유일한 variant다.
    /// `role: .destructive`는 무시한다 — 위험한 액션에는 `primary`를 쓴다.
    case theme
    /// 주요 버튼 — 밝은 배경 + 어두운 글자. 화면의 대표 액션에 사용
    case primary
    /// 보통 버튼 — 회색 배경 + 흰 글자. 부차 액션에 사용
    case neutral
    /// 투명 버튼 — 배경 없이 내용만. 배경 위에 얹는 가벼운 액션에 사용
    case transparent
}

// MARK: - 색 결정 (Figma textButton·iconButton 실측)

extension CHALLAButtonVariant {

    /// 배경색. transparent는 비활성이어도 배경이 생기지 않는다.
    /// destructive 비활성 디자인은 Figma에 없어 공통 비활성 팔레트로 떨어뜨린다.
    ///
    /// `themeColor`를 인자로 받는 이유: 이건 View가 아니라 값 계산 함수라
    /// `@Environment`를 직접 읽을 수 없다. 호출부(`CHALLAButtonBackgroundModifier`)가 읽어 넘긴다.
    func backgroundColor(
        role: CHALLAButtonRole? = nil,
        isEnabled: Bool,
        themeColor: Color
    ) -> Color? {
        switch (self, isEnabled) {
        case (.transparent, _): return nil
        case (_, false): return CHALLAColor.Background.level2
        // theme은 role을 따르지 않는다 — 앞세우는 액션 전용이라 destructive 조합이 없다.
        case (.theme, true): return themeColor
        case (.primary, true):
            return role == .destructive ? CHALLAColor.Status.destructive : CHALLAColor.Label.normal
        case (.neutral, true): return CHALLAColor.Background.level3
        }
    }

    /// 글자·아이콘 색.
    func contentColor(role: CHALLAButtonRole? = nil, isEnabled: Bool) -> Color {
        guard isEnabled else { return CHALLAColor.Label.disabled }
        switch (self, role) {
        case (.theme, _): return CHALLAColor.Static.black
        case (.primary, .destructive): return CHALLAColor.Label.normal
        case (.primary, nil): return CHALLAColor.Label.disabled
        case (.neutral, .destructive), (.transparent, .destructive): return CHALLAColor.Status.destructive
        case (.neutral, nil), (.transparent, nil): return CHALLAColor.Label.normal
        }
    }
}
