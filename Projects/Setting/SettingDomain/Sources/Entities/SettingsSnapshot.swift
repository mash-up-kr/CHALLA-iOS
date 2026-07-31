import Foundation

/// 설정 화면이 한 번에 필요로 하는 값 묶음.
///
/// 프로필(서버)과 테마(로컬)를 각각 불러오면 화면이 두 번 갱신되어 깜빡인다.
/// 한 번에 모아 돌려주고 화면은 한 번만 그린다.
public struct SettingsSnapshot: Sendable, Equatable {

    public let profile: SettingProfile
    public let theme: AppTheme

    public init(profile: SettingProfile, theme: AppTheme) {
        self.profile = profile
        self.theme = theme
    }
}
