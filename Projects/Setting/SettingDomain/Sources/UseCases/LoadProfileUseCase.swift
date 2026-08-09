import Dependencies
import DependenciesMacros

/// 설정 화면 헤더에 띄울 프로필을 불러온다.
///
/// 테마는 여기 없다 — 로컬이라 실패하지 않는 값을 네트워크로 실패하는 프로필과 한 묶음으로 두면
/// 프로필이 실패할 때 테마까지 함께 사라진다. 테마는 `LoadThemeUseCase`로 따로 읽는다.
@DependencyClient
public struct LoadProfileUseCase: Sendable {
    public var run: @Sendable () async throws -> SettingProfile
}

extension LoadProfileUseCase: TestDependencyKey {

    /// `liveValue`를 정의하지 않는 이유: Domain이 구현체(`SettingData`)를 알면 의존 방향이 뒤집힌다.
    /// 조립은 실행 앱의 `CompositionRoot`가 맡는다 (아키텍처 규칙 2).
    ///
    /// 의존성을 인터페이스로만 받아 조립하는 형태는 `LoginUseCase.live(social:repository:tokenStore:)`와 같다.
    public static func live(profile: any SettingProfileProvider) -> LoadProfileUseCase {
        LoadProfileUseCase(run: {
            try await profile.fetchProfile()
        })
    }

    public static let testValue = LoadProfileUseCase()

    public static let previewValue = LoadProfileUseCase(
        run: {
            SettingProfile(
                nickname: "나는야멋쟁이토마토",
                email: "hap****@naver.com",
                avatarURL: nil
            )
        }
    )
}

public extension DependencyValues {
    var loadProfileUseCase: LoadProfileUseCase {
        get { self[LoadProfileUseCase.self] }
        set { self[LoadProfileUseCase.self] = newValue }
    }
}
