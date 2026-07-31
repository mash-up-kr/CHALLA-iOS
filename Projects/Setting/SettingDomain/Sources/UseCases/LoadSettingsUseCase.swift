import Dependencies
import DependenciesMacros

/// 설정 화면 진입 시 프로필과 테마를 함께 불러온다.
@DependencyClient
public struct LoadSettingsUseCase: Sendable {
    public var run: @Sendable () async throws -> SettingsSnapshot
}

extension LoadSettingsUseCase: TestDependencyKey {

    /// `liveValue`를 정의하지 않는 이유: Domain이 구현체(`SettingData`)를 알면 의존 방향이 뒤집힌다.
    /// 조립은 실행 앱의 `CompositionRoot`가 맡는다 (아키텍처 규칙 2).
    ///
    /// 의존성을 인터페이스로만 받아 조립하는 형태는 `LoginUseCase.live(social:repository:tokenStore:)`와 같다.
    public static func live(
        settings: any SettingsRepository,
        profile: any SettingProfileProvider
    ) -> LoadSettingsUseCase {
        LoadSettingsUseCase(run: {
            // 테마는 로컬이라 즉시 돌아온다. 프로필만 기다리면 되므로 순차로 둔다.
            let loadedProfile = try await profile.fetchProfile()
            let theme = await settings.fetchTheme()
            return SettingsSnapshot(profile: loadedProfile, theme: theme)
        })
    }

    public static let testValue = LoadSettingsUseCase()

    public static let previewValue = LoadSettingsUseCase(
        run: {
            SettingsSnapshot(
                profile: SettingProfile(
                    nickname: "나는야멋쟁이토마토",
                    email: "juy***@naver,com",
                    avatarURL: nil
                ),
                theme: .lemonade
            )
        }
    )
}

public extension DependencyValues {
    var loadSettingsUseCase: LoadSettingsUseCase {
        get { self[LoadSettingsUseCase.self] }
        set { self[LoadSettingsUseCase.self] = newValue }
    }
}
