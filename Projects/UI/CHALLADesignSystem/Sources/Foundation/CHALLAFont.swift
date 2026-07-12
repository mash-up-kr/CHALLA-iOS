import SwiftUI

// MARK: - CHALLAFont (토큰)

/// CHALLA 디자인 시스템의 타이포 토큰. Figma Typography 구조(크기 × 굵기 매트릭스)를 그대로 반영한다.
/// - 폰트: 본문 SUIT(Bold/SemiBold/Regular), 포인트 Dirtyline(Heading.home / Heading.xlarge)
/// - Figma에 존재하는 조합만 노출한다: 단일 토큰(home, xlarge)은 CHALLATypography,
///   3굵기 토큰은 WeightSet(bold/medium/regular)으로 표현
///
/// 사용 예시:
/// ```swift
/// Text("제목").challaFont(CHALLAFont.Heading.large.bold)
/// Text("본문").challaFont(CHALLAFont.Body.medium.regular)
/// ```
public enum CHALLAFont {

    /// 한 크기(size/lineHeight)의 3굵기 묶음. 같은 크기 안에서 굵기만 달라진다.
    public struct WeightSet: Sendable {
        public let bold: CHALLATypography
        public let medium: CHALLATypography
        public let regular: CHALLATypography

        init(size: CGFloat, lineHeight: CGFloat) {
            bold = token(.bold, size: size, lineHeight: lineHeight)
            medium = token(.semiBold, size: size, lineHeight: lineHeight)
            regular = token(.regular, size: size, lineHeight: lineHeight)
        }
    }

    /// Heading — 제목
    public enum Heading {
        /// Dirtyline 36/60 (홈 화면 로고 타이틀 전용, 굵기 변형 없음)
        public static let home = token(.dirtyline, size: 36, lineHeight: 60)
        /// Dirtyline 60/42 (포인트 전용, bold 단일)
        public static let xlarge = token(.dirtyline, size: 60, lineHeight: 42)
        public static let large = WeightSet(size: 28, lineHeight: 36)
        public static let medium = WeightSet(size: 24, lineHeight: 32)
        public static let small = WeightSet(size: 20, lineHeight: 28)
    }

    /// Body — 본문
    public enum Body {
        public static let large = WeightSet(size: 18, lineHeight: 24)
        public static let medium = WeightSet(size: 16, lineHeight: 20)
        public static let small = WeightSet(size: 14, lineHeight: 16)
    }

    /// Description — 보조 설명
    public enum Description {
        public static let large = WeightSet(size: 12, lineHeight: 14)
        public static let medium = WeightSet(size: 11, lineHeight: 13)
        public static let small = WeightSet(size: 10, lineHeight: 13)
    }
}

// MARK: - 내부 헬퍼

private extension CHALLAFont {

    /// 폰트 파일 종류. Tuist 자동 생성 폰트 접근자로 매핑된다.
    /// (Figma의 'medium'은 실제 SUIT SemiBold(600)에 매핑됨)
    enum FontFace {
        case bold, semiBold, regular, dirtyline
    }

    /// 굵기 + 크기 + 행간으로 타이포 토큰을 만든다.
    static func token(_ weight: FontFace, size: CGFloat, lineHeight: CGFloat) -> CHALLATypography {
        let font: Font
        switch weight {
        case .bold:
            font = CHALLADesignSystemFontFamily.Suit.bold.swiftUIFont(size: size)
        case .semiBold:
            font = CHALLADesignSystemFontFamily.Suit.semiBold.swiftUIFont(size: size)
        case .regular:
            font = CHALLADesignSystemFontFamily.Suit.regular.swiftUIFont(size: size)
        case .dirtyline:
            font = CHALLADesignSystemFontFamily.Dirtyline36Daysoftype2022.regular.swiftUIFont(size: size)
        }
        return CHALLATypography(font: font, size: size, lineHeight: lineHeight)
    }
}
