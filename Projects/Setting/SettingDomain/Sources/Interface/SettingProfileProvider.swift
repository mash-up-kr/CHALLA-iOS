import Foundation

/// 설정 화면 헤더에 띄울 프로필을 가져오는 창구.
///
/// **`SettingsRepository`와 분리한 이유** — 프로필은 설정(테마·알림)과 다른 aggregate다.
/// `.claude/rules/architecture.md`는 "Domain·Data는 화면 단위가 아니라 aggregate 단위로 1벌만
/// 만든다"고 정하고 있고, 사용자 프로필의 정본은 이슈 #33이 만드는 `UserRepository`다.
/// 여기서 조회를 또 구현하면 같은 서버 계약이 두 곳에 생긴다.
///
/// 그래서 설정 쪽은 **필요한 모양만 protocol로 선언**하고, 무엇으로 채울지는 합성 지점이 정한다.
/// #33이 머지되면 `UserRepository`를 이 protocol에 맞춰주는 어댑터만 `CompositionRoot`에 두면 되고,
/// Domain·Feature는 손댈 게 없다.
///
/// 구현체는 실패를 `SettingError`로 정규화해 던져야 한다.
public protocol SettingProfileProvider: Sendable {
    func fetchProfile() async throws -> SettingProfile
}
