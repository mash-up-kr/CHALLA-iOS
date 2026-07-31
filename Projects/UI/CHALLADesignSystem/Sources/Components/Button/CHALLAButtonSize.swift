import SwiftUI

/// 버튼 크기. Text·Icon 버튼이 공유한다.
/// CaseIterable: 갤러리가 allCases로 전수 나열해 크기 추가 시 자동 반영되게 한다.
public enum CHALLAButtonSize: Sendable, CaseIterable {
    case large, medium, small
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

    /// 텍스트 버튼의 아이콘-글자 간격 (Figma 실측: 전 크기 4)
    var contentSpacing: CGFloat {
        4
    }
}
