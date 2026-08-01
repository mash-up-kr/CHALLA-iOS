import Dependencies
import DependenciesMacros

// 테마 선택 화면이 쓰는 UseCase 2종. 파일을 화면 단위로 묶는 이유는 MODULE.md 참고.

// MARK: - 불러오기

/// 저장된 테마를 읽는다. 설정 메인이 호출하고, 하위 화면에는 그 값을 시드로 내려준다.
@DependencyClient
public struct LoadThemeUseCase: Sendable {
    /// 로컬 저장이라 실패 개념이 없다 — 던지지 않는다.
    public var run: @Sendable () async -> AppTheme = { .default }
}

extension LoadThemeUseCase: TestDependencyKey {

    /// `liveValue`를 두지 않는 이유는 `LoadProfileUseCase` 주석 참고 (아키텍처 규칙 2).
    public static func live(settings: any SettingsRepository) -> LoadThemeUseCase {
        LoadThemeUseCase(run: {
            await settings.fetchTheme()
        })
    }

    public static let testValue = LoadThemeUseCase()

    public static let previewValue = LoadThemeUseCase(run: { .lemonade })
}

public extension DependencyValues {
    var loadThemeUseCase: LoadThemeUseCase {
        get { self[LoadThemeUseCase.self] }
        set { self[LoadThemeUseCase.self] = newValue }
    }
}

// MARK: - 선택

/// 고른 테마를 저장한다.
@DependencyClient
public struct SelectThemeUseCase: Sendable {
    public var run: @Sendable (AppTheme) async -> Void
}

extension SelectThemeUseCase: TestDependencyKey {

    public static func live(settings: any SettingsRepository) -> SelectThemeUseCase {
        SelectThemeUseCase(run: { theme in
            await settings.updateTheme(theme)
        })
    }

    public static let testValue = SelectThemeUseCase()

    public static let previewValue = SelectThemeUseCase(run: { _ in })
}

public extension DependencyValues {
    var selectThemeUseCase: SelectThemeUseCase {
        get { self[SelectThemeUseCase.self] }
        set { self[SelectThemeUseCase.self] = newValue }
    }
}
