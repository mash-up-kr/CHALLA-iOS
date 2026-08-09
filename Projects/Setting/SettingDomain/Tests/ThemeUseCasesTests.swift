@testable import SettingDomain
import Testing

// 읽기(`LoadThemeUseCase`)는 `LoadProfileUseCaseTests.swift`에서 프로필 분리와 함께 고정한다.

struct SelectThemeUseCaseTests {

    @Test("고른 테마를 저장소에 그대로 넘긴다")
    func savesSelectedTheme() async {
        let repository = MockSettingsRepository()
        let useCase = SelectThemeUseCase.live(settings: repository)

        await useCase.run(.blueberry)

        #expect(repository.updatedThemes == [.blueberry])
    }
}
