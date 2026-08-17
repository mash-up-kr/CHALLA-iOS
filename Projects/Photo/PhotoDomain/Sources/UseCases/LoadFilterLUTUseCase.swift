import Dependencies
import DependenciesMacros
import Foundation

/// 필터 하나의 LUT(.cube) 원본 바이트를 내려받는다. 파싱·CoreImage 변환은 호출부(화면 조립) 몫이다.
///
/// `liveValue`가 없는 이유는 `FetchCameraFiltersUseCase` 주석 참고.
@DependencyClient
public struct LoadFilterLUTUseCase: Sendable {
    public var run: @Sendable (CameraFilter) async throws -> Data
}

extension LoadFilterLUTUseCase: TestDependencyKey {

    public static func live(repository: any CameraFilterRepository) -> LoadFilterLUTUseCase {
        LoadFilterLUTUseCase(run: { try await repository.lutData(for: $0) })
    }

    public static let testValue = LoadFilterLUTUseCase()

    /// 프리뷰는 LUT 없이 무필터로 그린다 — 빈 데이터는 파싱에 실패해 원본 통과가 된다.
    public static let previewValue = LoadFilterLUTUseCase(
        run: { _ in Data() }
    )
}

public extension DependencyValues {
    var loadFilterLUTUseCase: LoadFilterLUTUseCase {
        get { self[LoadFilterLUTUseCase.self] }
        set { self[LoadFilterLUTUseCase.self] = newValue }
    }
}
