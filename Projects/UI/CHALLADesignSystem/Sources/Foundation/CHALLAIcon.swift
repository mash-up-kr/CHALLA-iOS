import SwiftUI

/// CHALLA 디자인 시스템의 아이콘 토큰.
/// Figma 아이콘 인벤토리와 1:1 대응하며, 케이스 rawValue가 에셋 카탈로그 이름이다.
/// 에셋은 template 렌더링이라 color 파라미터로 어떤 색이든 입힐 수 있다.
public enum CHALLAIcon: String, CaseIterable, Sendable {
    case apple = "Apple"
    case arrowsCounterClockwise = "ArrowsCounterClockwise"
    case bellSimple = "BellSimple"
    case camera = "Camera"
    case caretLeft = "CaretLeft"
    case caretRight = "CaretRight"
    case carrot = "Carrot"
    case chatTeardropDots = "ChatTeardropDots"
    case check = "Check"
    case circle = "Circle"
    case close = "Close"
    case error = "Error"
    case kakaoTalk = "KakaoTalk"
    case lightningOff = "LightningOff"
    case lightningOn = "LightningOn"
    case palette = "Palette"
    case profile = "Profile"
    case setting = "Setting"
    case signOut = "SignOut"
    case unfoldMore = "UnfoldMore"

    /// 아이콘 크기 토큰(pt). Figma 아이콘 사이즈 프레임(16~32) 기준.
    public enum Size: CGFloat, CaseIterable, Sendable {
        case size16 = 16
        case size18 = 18
        case size20 = 20
        case size22 = 22
        case size24 = 24
        case size28 = 28
        case size32 = 32
    }

    /// 아이콘을 지정 크기·색으로 그린다.
    /// 기본 색은 Figma 아이콘 인벤토리 원본과 같은 Label.neutral.
    ///
    /// ```swift
    /// CHALLAIcon.check.image(size: .size24, color: CHALLAColor.Label.normal)
    /// ```
    public func image(size: Size = .size24, color: Color = CHALLAColor.Label.neutral) -> some View {
        Image(rawValue, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: size.rawValue, height: size.rawValue)
            .foregroundStyle(color)
    }
}
