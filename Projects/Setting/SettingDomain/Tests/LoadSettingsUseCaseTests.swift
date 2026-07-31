@testable import SettingDomain
import Testing

struct LoadSettingsUseCaseTests {

    @Test("프로필과 저장된 테마를 한 묶음으로 돌려준다")
    func combinesProfileAndTheme() async throws {
        let useCase = LoadSettingsUseCase.live(
            settings: MockSettingsRepository(storedTheme: .blueberry),
            profile: MockProfileProvider()
        )

        let snapshot = try await useCase.run()

        #expect(snapshot.profile == .stub)
        #expect(snapshot.theme == .blueberry)
    }

    @Test("고른 테마가 없으면 기본 테마가 실린다")
    func fallsBackToDefaultTheme() async throws {
        let useCase = LoadSettingsUseCase.live(
            settings: MockSettingsRepository(storedTheme: .default),
            profile: MockProfileProvider()
        )

        let snapshot = try await useCase.run()

        #expect(snapshot.theme == .lemonade)
    }

    @Test("프로필 조회가 실패하면 그 오류를 그대로 던진다")
    func propagatesProfileFailure() async {
        let useCase = LoadSettingsUseCase.live(
            settings: MockSettingsRepository(),
            profile: MockProfileProvider(result: .failure(.network))
        )

        await #expect(throws: SettingError.network) {
            try await useCase.run()
        }
    }

    @Test("프로필을 한 번만 조회한다")
    func fetchesProfileOnce() async throws {
        let provider = MockProfileProvider()
        let useCase = LoadSettingsUseCase.live(
            settings: MockSettingsRepository(),
            profile: provider
        )

        _ = try await useCase.run()

        #expect(provider.callCount == 1)
    }
}
