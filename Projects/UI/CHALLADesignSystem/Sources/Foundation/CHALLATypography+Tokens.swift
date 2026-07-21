import SwiftUI

// MARK: - 타이포 토큰

/// CHALLA 디자인 시스템의 타이포 토큰. Figma Typography 구조를 그대로 반영한다.
/// 본문은 SUIT, 포인트(heading.home / xlarge)는 Dirtyline.
///
/// ```swift
/// Text("제목").challaFont(.heading.large.bold)
/// ```
public extension CHALLATypography {

    /// 한 크기의 3굵기(bold/medium/regular) 묶음.
    struct WeightSet: Sendable {
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
    struct Heading: Sendable {
        /// Dirtyline 36/60 (홈 화면 로고 타이틀 전용, 굵기 변형 없음)
        public let home = token(.dirtyline, size: 36, lineHeight: 60)
        /// Dirtyline 60/42 (포인트 전용, bold 단일)
        public let xlarge = token(.dirtyline, size: 60, lineHeight: 42)
        public let large = WeightSet(size: 28, lineHeight: 36)
        public let medium = WeightSet(size: 24, lineHeight: 32)
        public let small = WeightSet(size: 22, lineHeight: 30)
        public let xsmall = WeightSet(size: 20, lineHeight: 28)
    }

    /// Body — 본문
    struct Body: Sendable {
        public let large = WeightSet(size: 18, lineHeight: 24)
        public let medium = WeightSet(size: 16, lineHeight: 20)
        public let small = WeightSet(size: 15, lineHeight: 18)
        public let xsmall = WeightSet(size: 14, lineHeight: 16)
    }

    /// Description — 보조 설명
    struct Description: Sendable {
        public let large = WeightSet(size: 12, lineHeight: 14)
        public let medium = WeightSet(size: 11, lineHeight: 13)
        public let small = WeightSet(size: 10, lineHeight: 13)
    }

    /// 호출부에서 타입 이름 없이 `.heading.large.bold`처럼 접근한다.
    static let heading = Heading()
    static let body = Body()
    static let description = Description()
}

// MARK: - 내부 헬퍼

private extension CHALLATypography {

    /// 폰트 파일 종류. (Figma의 'medium'은 SUIT SemiBold에 매핑)
    enum FontFace {
        case bold, semiBold, regular, dirtyline
    }

    /// 굵기 + 크기 + 행간으로 타이포 토큰을 만든다.
    static func token(_ weight: FontFace, size: CGFloat, lineHeight: CGFloat) -> CHALLATypography {
        let font: Font = switch weight {
        case .bold:
            CHALLADesignSystemFontFamily.Suit.bold.swiftUIFont(size: size)
        case .semiBold:
            CHALLADesignSystemFontFamily.Suit.semiBold.swiftUIFont(size: size)
        case .regular:
            CHALLADesignSystemFontFamily.Suit.regular.swiftUIFont(size: size)
        case .dirtyline:
            CHALLADesignSystemFontFamily.Dirtyline36Daysoftype2022.regular.swiftUIFont(size: size)
        }
        return CHALLATypography(font: font, size: size, lineHeight: lineHeight)
    }
}
