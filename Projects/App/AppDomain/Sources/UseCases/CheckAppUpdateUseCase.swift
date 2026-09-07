import Dependencies
import DependenciesMacros

/// 앱 실행 직후 1회, 현재 버전으로 계속 써도 되는지 확인한다.
///
/// `liveValue`가 없는 이유: live 조립에 Repository와 현재 버전이 필요해
/// `CompositionRoot`가 `live(repository:currentVersion:)`으로 만든다.
@DependencyClient
public struct CheckAppUpdateUseCase: Sendable {
    public var run: @Sendable () async throws -> AppUpdateRequirement
}

extension CheckAppUpdateUseCase: TestDependencyKey {

    /// `currentVersion`은 조립 시점에 Bundle에서 읽어 넘긴다 — Domain은 Bundle을 모른다.
    public static func live(
        repository: any AppVersionRepository,
        currentVersion: String
    ) -> CheckAppUpdateUseCase {
        CheckAppUpdateUseCase(run: {
            try await repository.checkUpdateRequirement(currentVersion: currentVersion)
        })
    }

    public static let testValue = CheckAppUpdateUseCase()

    public static let previewValue = CheckAppUpdateUseCase(
        run: { .notRequired }
    )
}

public extension DependencyValues {
    var checkAppUpdateUseCase: CheckAppUpdateUseCase {
        get { self[CheckAppUpdateUseCase.self] }
        set { self[CheckAppUpdateUseCase.self] = newValue }
    }
}
