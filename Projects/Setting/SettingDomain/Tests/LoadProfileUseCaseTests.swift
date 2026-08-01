@testable import SettingDomain
import Testing

struct LoadProfileUseCaseTests {

    @Test("공급자가 준 프로필을 그대로 돌려준다")
    func returnsProfile() async throws {
        let useCase = LoadProfileUseCase.live(profile: MockProfileProvider())

        let profile = try await useCase.run()

        #expect(profile == .stub)
    }

    @Test("프로필 조회가 실패하면 그 오류를 그대로 던진다")
    func propagatesProfileFailure() async {
        let useCase = LoadProfileUseCase.live(
            profile: MockProfileProvider(result: .failure(.network))
        )

        await #expect(throws: SettingError.network) {
            try await useCase.run()
        }
    }

    @Test("프로필을 한 번만 조회한다")
    func fetchesProfileOnce() async throws {
        let provider = MockProfileProvider()
        let useCase = LoadProfileUseCase.live(profile: provider)

        _ = try await useCase.run()

        #expect(provider.callCount == 1)
    }
}

/// 테마는 프로필과 분리돼 있어 프로필 실패의 영향을 받지 않는다 — 분리의 핵심이라 여기서 함께 고정한다.
struct LoadThemeUseCaseTests {

    @Test("저장된 테마를 돌려준다")
    func returnsStoredTheme() async {
        let useCase = LoadThemeUseCase.live(settings: MockSettingsRepository(storedTheme: .blueberry))

        #expect(await useCase.run() == .blueberry)
    }

    @Test("고른 적이 없으면 기본 테마를 돌려준다")
    func fallsBackToDefaultTheme() async {
        let useCase = LoadThemeUseCase.live(settings: MockSettingsRepository(storedTheme: .default))

        #expect(await useCase.run() == .lemonade)
    }
}
