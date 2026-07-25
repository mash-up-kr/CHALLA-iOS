import SwiftUI

/// 버튼 스타일(변형). Text·Icon 버튼이 공유한다.
/// CaseIterable: 갤러리가 allCases로 전수 나열해 variant 추가 시 자동 반영되게 한다.
public enum CHALLAButtonVariant: Sendable, CaseIterable {
    /// 주요 버튼 — 밝은 배경 + 어두운 글자. 화면의 대표 액션에 사용
    case primary
    /// 보통 버튼 — 회색 배경 + 흰 글자. 부차 액션에 사용
    case neutral
    /// 투명 버튼 — 배경 없이 내용만. 배경 위에 얹는 가벼운 액션에 사용
    case transparent
}

/// 버튼 크기. Text·Icon 버튼이 공유한다.
/// CaseIterable: 갤러리가 allCases로 전수 나열해 크기 추가 시 자동 반영되게 한다.
public enum CHALLAButtonSize: Sendable, CaseIterable {
    case large, medium, small
}

// MARK: - 색 결정 (Figma textButton·iconButton 실측)

extension CHALLAButtonVariant {

    /// 배경색. transparent는 비활성이어도 배경이 생기지 않는다.
    func backgroundColor(isEnabled: Bool) -> Color? {
        switch (self, isEnabled) {
        case (.transparent, _): return nil
        case (_, false): return CHALLAColor.Background.level2
        case (.primary, true): return CHALLAColor.Label.normal
        case (.neutral, true): return CHALLAColor.Background.level3
        }
    }

    /// 글자·아이콘 색. 활성 primary의 어두운 글자색은 Figma가
    /// Label/Disabled 변수(#444549)로 지정해놓아 그대로 따른다.
    func contentColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return CHALLAColor.Label.disabled }
        switch self {
        case .primary: return CHALLAColor.Label.disabled
        case .neutral, .transparent: return CHALLAColor.Label.normal
        }
    }
}

// MARK: - 크기별 수치 (Figma 실측)

extension CHALLAButtonSize {

    /// 버튼 높이. 아이콘 버튼은 같은 값을 한 변으로 쓰는 정사각형이다.
    var height: CGFloat {
        switch self {
        case .large: 54
        case .medium: 40
        case .small: 32
        }
    }

    var radius: CGFloat {
        switch self {
        case .large: CHALLARadius.large
        case .medium: CHALLARadius.medium
        case .small: CHALLARadius.small
        }
    }

    /// 텍스트 버튼의 가로 패딩
    var horizontalPadding: CGFloat {
        switch self {
        case .large: 20
        case .medium: 16
        case .small: 10
        }
    }

    /// 텍스트 버튼의 글꼴
    var typography: CHALLATypography {
        switch self {
        case .large: .body.large.bold
        case .medium, .small: .body.xsmall.bold
        }
    }

    /// 내부 아이콘 크기. iconButton 실측(24/20/16) 기준이며,
    /// textButton은 Figma에 전 사이즈 24로 박혀 있으나 M/S 높이를 넘어가는
    /// 디자인 오류로 판단해 동일 규칙(24/20/16)을 적용한다.
    var iconSize: CHALLAIcon.Size {
        switch self {
        case .large: .size24
        case .medium: .size20
        case .small: .size16
        }
    }

    /// 터치 영역 확장량. HIG 최소 터치 타깃(44pt)에 못 미치는 크기는
    /// 시각 크기(Figma 실측)는 유지한 채 보이지 않는 히트 영역만 사방으로 넓힌다.
    var touchAreaInset: CGFloat {
        max(0, (44 - height) / 2)
    }

    /// 텍스트 버튼의 아이콘-글자 간격 (Figma 실측: 전 크기 4)
    var contentSpacing: CGFloat { 4 }
}
