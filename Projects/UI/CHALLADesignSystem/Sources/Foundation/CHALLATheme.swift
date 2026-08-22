import SwiftUI

/// 사용자가 설정에서 고른 테마의 색.
///
/// 색이 둘인 이유는 `glow`가 `accent`의 투명도 변형이 아니라 별도 hex이기 때문이다
/// (accent `#D5F700`, glow `#EAFF00`). 다른 강조 색은 `accent.opacity(_:)`로 만든다.
///
/// 앱 루트가 `\.challaTheme`에 주입하고 컴포넌트는 `@Environment`로 읽는다.
public struct CHALLATheme: Equatable, Sendable {

    /// 강조 색. 값 글자·스위치 켜짐·포커스 테두리·배지가 이 색을 쓴다.
    public let accent: Color

    /// 화면 하단에 번지는 색 — `challaMainBackground()` 전용.
    /// 앱은 테마와 무관하게 브랜드 색 하나를 쓴다.
    public let glow: Color

    /// - Parameters:
    ///   - accent: 강조 색.
    ///   - glow: 하단 번짐 색. 생략하면 accent를 쓴다.
    public init(accent: Color, glow: Color? = nil) {
        self.accent = accent
        self.glow = glow ?? accent
    }

    /// 테마를 고르기 전 기본값 (시안의 첫 테마).
    public static let lemonade = CHALLATheme(
        accent: CHALLAColor.Primary.yellow,
        glow: CHALLAColor.Background.brand
    )
}

// MARK: - challaTheme

public extension EnvironmentValues {

    /// 현재 적용된 테마 색. 앱 루트에서 한 번 주입한다.
    ///
    /// ```swift
    /// AppView(store: store)
    ///     .environment(\.challaTheme, theme.palette)
    /// ```
    ///
    /// 주입이 없으면 `lemonade`라서 프리뷰·검수앱·데모앱은 따로 주입하지 않아도 된다.
    @Entry var challaTheme: CHALLATheme = .lemonade
}
