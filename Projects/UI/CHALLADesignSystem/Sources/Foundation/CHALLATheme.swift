import SwiftUI

/// 사용자가 설정에서 고른 테마의 색.
///
/// 앱 루트가 `\.challaTheme`에 주입하고 컴포넌트는 `@Environment`로 읽는다.
public struct CHALLATheme: Equatable, Sendable {

    /// 강조 색. 값 글자·스위치 켜짐·포커스 테두리·배지·화면 하단 번짐이 이 색을 쓴다.
    public let accent: Color

    public init(accent: Color) {
        self.accent = accent
    }

    /// 테마를 고르기 전 기본값 (시안의 첫 테마).
    public static let lemonade = CHALLATheme(accent: CHALLAColor.Primary.yellow)
}

// MARK: - challaTheme

public extension EnvironmentValues {

    /// 현재 적용된 테마 색. 앱 루트에서 한 번 주입한다.
    ///
    /// ```swift
    /// AppView(store: store)
    ///     .environment(\.challaTheme, CHALLATheme(accent: theme.themeColor))
    /// ```
    ///
    /// 주입이 없으면 `lemonade`라서 프리뷰·검수앱·데모앱은 따로 주입하지 않아도 된다.
    @Entry var challaTheme: CHALLATheme = .lemonade
}
