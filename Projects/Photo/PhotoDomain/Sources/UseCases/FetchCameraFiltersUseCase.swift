import Dependencies
import DependenciesMacros

/// 서버가 제공하는 카메라 필터 목록. 카메라 진입 시 필터 띠의 재료가 된다.
///
/// `liveValue`가 없는 것은 의도다 — 실 구현에 `PhotoData`의 저장소가 필요해 Domain이 Data를
/// import하게 된다. 조립은 실행 앱의 `CompositionRoot`가 맡는다 (Room의 UseCase들과 같다).
@DependencyClient
public struct FetchCameraFiltersUseCase: Sendable {
    public var run: @Sendable () async throws -> [CameraFilter]
}

extension FetchCameraFiltersUseCase: TestDependencyKey {

    public static func live(repository: any CameraFilterRepository) -> FetchCameraFiltersUseCase {
        FetchCameraFiltersUseCase(run: { try await repository.filters() })
    }

    public static let testValue = FetchCameraFiltersUseCase()

    public static let previewValue = FetchCameraFiltersUseCase(
        run: { CameraFilter.previewFilters }
    )
}

public extension DependencyValues {
    var fetchCameraFiltersUseCase: FetchCameraFiltersUseCase {
        get { self[FetchCameraFiltersUseCase.self] }
        set { self[FetchCameraFiltersUseCase.self] = newValue }
    }
}
