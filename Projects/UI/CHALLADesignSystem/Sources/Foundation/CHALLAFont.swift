import SwiftUI

// MARK: - CHALLAFont (토큰)

/// CHALLA 디자인 시스템의 타이포 토큰. Figma Typography 구조를 그대로 반영한다. (총 13개)
/// 폰트: 본문 SUIT(Bold/SemiBold/Regular), 앱 로고 폰트 Dirtyline(heading.xlarge)
public enum CHALLAFont {

    /// Weight — 굵기 견본 (15/20)
    public enum Weight {
        public static let bold = token(.bold, size: 15, lineHeight: 20)
        public static let medium = token(.semiBold, size: 15, lineHeight: 20)
        public static let regular = token(.regular, size: 15, lineHeight: 20)
    }

    /// Heading — 제목
    public enum Heading {
        /// Dirtyline 60 / 42 (CHALLA 로고 등 포인트 전용)
        public static let xlarge = token(.dirtyline, size: 60, lineHeight: 42)
        public static let large = token(.bold, size: 28, lineHeight: 36)
        public static let medium = token(.bold, size: 24, lineHeight: 32)
        public static let small = token(.bold, size: 20, lineHeight: 28)
    }

    /// Body — 본문
    public enum Body {
        public static let large = token(.semiBold, size: 18, lineHeight: 24)
        public static let medium = token(.semiBold, size: 16, lineHeight: 20)
        public static let small = token(.semiBold, size: 14, lineHeight: 16)
    }

    /// Description — 보조 설명
    public enum Description {
        public static let large = token(.semiBold, size: 12, lineHeight: 14)
        public static let medium = token(.semiBold, size: 11, lineHeight: 13)
        public static let small = token(.semiBold, size: 10, lineHeight: 12)
    }
}

// MARK: - 내부 헬퍼

private extension CHALLAFont {
    
    /// 폰트 파일 종류. Tuist 자동 생성 폰트 접근자로 매핑된다.
    /// (Figma의 'medium'은 실제 SemiBold(600)에 매핑됨)
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
