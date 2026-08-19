import Dependencies
import DependenciesMacros

// 카메라 진입 안내(코치마크)가 쓰는 UseCase 2종.
//
// `liveValue`가 없는 이유는 `FetchCameraFiltersUseCase` 주석 참고.

// MARK: - 안내를 봐야 하는지

/// 카메라에 처음 들어왔는지 묻는다. true면 안내를 띄운다.
@DependencyClient
public struct ShouldShowCameraCoachMarkUseCase: Sendable {
    /// 기기 저장값을 읽을 뿐이라 실패 개념이 없다 — 던지지 않는다.
    /// 기본값이 false인 이유: 확인이 안 되는 상황에서 안내를 반복해 띄우는 쪽이 더 거슬린다.
    public var run: @Sendable () async -> Bool = { false }
}

extension ShouldShowCameraCoachMarkUseCase: TestDependencyKey {

    public static func live(repository: any CameraOnboardingRepository) -> ShouldShowCameraCoachMarkUseCase {
        ShouldShowCameraCoachMarkUseCase(run: { await !repository.hasSeenCoachMark() })
    }

    public static let testValue = ShouldShowCameraCoachMarkUseCase()

    public static let previewValue = ShouldShowCameraCoachMarkUseCase(run: { true })
}

public extension DependencyValues {
    var shouldShowCameraCoachMarkUseCase: ShouldShowCameraCoachMarkUseCase {
        get { self[ShouldShowCameraCoachMarkUseCase.self] }
        set { self[ShouldShowCameraCoachMarkUseCase.self] = newValue }
    }
}

// MARK: - 봤다고 기록

/// 안내를 끝까지 본 것으로 기록한다 — 다음 진입부터는 뜨지 않는다.
@DependencyClient
public struct MarkCameraCoachMarkSeenUseCase: Sendable {
    public var run: @Sendable () async -> Void
}

extension MarkCameraCoachMarkSeenUseCase: TestDependencyKey {

    public static func live(repository: any CameraOnboardingRepository) -> MarkCameraCoachMarkSeenUseCase {
        MarkCameraCoachMarkSeenUseCase(run: { await repository.markCoachMarkSeen() })
    }

    public static let testValue = MarkCameraCoachMarkSeenUseCase()

    public static let previewValue = MarkCameraCoachMarkSeenUseCase(run: {})
}

public extension DependencyValues {
    var markCameraCoachMarkSeenUseCase: MarkCameraCoachMarkSeenUseCase {
        get { self[MarkCameraCoachMarkSeenUseCase.self] }
        set { self[MarkCameraCoachMarkSeenUseCase.self] = newValue }
    }
}
