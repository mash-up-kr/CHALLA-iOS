import Foundation

/// 앱 전반의 포인트 색을 결정하는 테마.
///
/// 여섯 종은 기획이 정한 고정 집합이다 — 사용자가 새로 만들 수 없다.
/// `displayName`은 제품에서 부르는 이름이라 여기에 둔다.
///
/// 색은 여기 없다 — Domain은 UI를 import 하지 않는다.
/// `AppTheme` → `CHALLAColor.Primary` 매핑은 `SettingFeature/Sources/Support/AppTheme+ThemeColor.swift`에 있다.
public enum AppTheme: String, Sendable, Equatable, CaseIterable, Codable {
    case lemonade
    case raspberry
    case orange
    case cider
    case blueberry
    case acaiBowl

    /// 설정 화면의 테마 행에 값으로 표시되는 이름.
    public var displayName: String {
        switch self {
        case .lemonade: "레몬에이드"
        case .raspberry: "라즈베리"
        case .orange: "오렌지"
        case .cider: "사이다"
        case .blueberry: "블루베리"
        case .acaiBowl: "아사이볼"
        }
    }

    /// 한 번도 고른 적 없는 사용자에게 적용되는 테마.
    public static let `default`: AppTheme = .lemonade
}
