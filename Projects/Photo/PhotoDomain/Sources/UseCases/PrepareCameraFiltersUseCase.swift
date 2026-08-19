import Dependencies
import DependenciesMacros
import Foundation

/// 필터들의 LUT(.cube)를 한꺼번에 내려받아 촬영에 쓸 수 있는 상태로 만든다.
///
/// 하나라도 실패하면 던진다 — 카메라 진입 버튼이 이 결과로 진입 여부를 정하기 때문이다.
/// 일부만 준비된 채로 들어가면 그 필터만 색이 안 먹는데, 사용자에게는 앱이 고장 난 것으로 보인다.
///
/// LUT 파싱·등록은 Domain이 모르는 색 변환 영역이라 `register`로 주입받는다 —
/// 조립 지점이 `CameraFilterCatalog.register`를 넘긴다.
/// `liveValue`가 없는 이유는 `FetchCameraFiltersUseCase` 주석 참고.
@DependencyClient
public struct PrepareCameraFiltersUseCase: Sendable {
    public var run: @Sendable ([CameraFilter]) async throws -> Void
}

extension PrepareCameraFiltersUseCase: TestDependencyKey {

    /// - Parameter register: 내려받은 .cube 원본을 화면이 쓸 수 있는 형태로 등록한다. 실패하면 `false`.
    public static func live(
        repository: any CameraFilterRepository,
        register: @escaping @Sendable (Data, CameraFilter.ID) -> Bool
    ) -> PrepareCameraFiltersUseCase {
        PrepareCameraFiltersUseCase(
            run: { filters in
                // 파일이 10개 남짓이라 순차로 받으면 진입이 그만큼 늦어진다 — 전부 동시에 건다.
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for filter in filters {
                        group.addTask {
                            let cubeData = try await repository.lutData(for: filter)
                            guard register(cubeData, filter.id) else { throw PhotoError.unknown }
                        }
                    }
                    try await group.waitForAll()
                }
            }
        )
    }

    public static let testValue = PrepareCameraFiltersUseCase()

    /// 프리뷰는 LUT 없이 무필터로 그린다 — 준비할 것이 없다.
    public static let previewValue = PrepareCameraFiltersUseCase(
        run: { _ in }
    )
}

public extension DependencyValues {
    var prepareCameraFiltersUseCase: PrepareCameraFiltersUseCase {
        get { self[PrepareCameraFiltersUseCase.self] }
        set { self[PrepareCameraFiltersUseCase.self] = newValue }
    }
}
