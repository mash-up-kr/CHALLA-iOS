import SwiftUI

/// CHALLA 디자인 시스템의 아이콘 토큰.
/// Figma 아이콘 인벤토리와 1:1 대응하며, 케이스 rawValue가 에셋 카탈로그 이름이다.
/// 에셋은 template 렌더링이라 color 파라미터로 어떤 색이든 입힐 수 있다.
public enum CHALLAIcon: String, CaseIterable, Sendable {
    case apple = "Apple"
    case arrowsCounterClockwise = "ArrowsCounterClockwise"
    case bellSimple = "BellSimple"
    case camera = "Camera"
    case cameraRoll = "CameraRoll"
    case caretLeft = "CaretLeft"
    case caretRight = "CaretRight"
    case carrot = "Carrot"
    case chatTeardropDots = "ChatTeardropDots"
    case check = "Check"
    case circle = "Circle"
    case clock = "Clock"
    case close = "Close"
    case copy = "Copy"
    case downloadSimple = "DownloadSimple"
    case error = "Error"
    case kakaoTalk = "KakaoTalk"
    case lightningOff = "LightningOff"
    case lightningOn = "LightningOn"
    case palette = "Palette"
    case pencilSimple = "PencilSimple"
    case person = "Person"
    /// Figma 컴포넌트 이름은 `add`지만 다른 아이콘들과 같은 Phosphor 이름을 쓴다.
    case plus = "Plus"
    case profile = "Profile"
    case setting = "Setting"
    case signOut = "SignOut"
    case unfoldMore = "UnfoldMore"

    /// 아이콘 크기 토큰(pt). Figma 아이콘 사이즈 프레임(16~32) 기준.
    /// size14는 프레임 밖 예외 — 방 카드 인원 표시의 person 아이콘 실측값.
    public enum Size: CGFloat, CaseIterable, Sendable {
        case size14 = 14
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
    /// **VoiceOver에는 읽히지 않는다(장식용).** 아이콘 자체가 뜻을 가지는 자리라면
    /// 호출부에서 `.accessibilityLabel(_:)`을 붙여 이름을 준다
    /// (`CHALLAIconButton`·`CHALLATopNavigation`이 그렇게 한다).
    /// 그러지 않으면 에셋 이름("CaretRight")이 그대로 낭독된다.
    ///
    /// ```swift
    /// CHALLAIcon.check.image(size: .size24, color: CHALLAColor.Label.normal)
    /// ```
    public func image(size: Size = .size24, color: Color = CHALLAColor.Label.neutral) -> some View {
        Image(decorative: rawValue, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: size.rawValue, height: size.rawValue)
            .foregroundStyle(color)
    }
}
