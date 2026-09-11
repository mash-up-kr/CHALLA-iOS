import Dependencies
import DependenciesMacros

/// 방의 사진을 화면보다 먼저 받아 이미지 캐시에 넣어 둔다.
///
/// 인화 완료 안내는 필름이 4초 만에 지나가서, 화면에 들어간 뒤에 받기 시작하면 늦다.
/// 홈에서 방 카드를 보는 동안 미리 받아 두면 들어갔을 때 기다릴 것이 없다.
///
/// 실패를 던지지 않는다 — 미리 받기는 없어도 되는 일이고, 못 받으면 화면이 들어간 뒤에 받는다.
@DependencyClient
public struct PrefetchRoomPhotosUseCase: Sendable {
    public var run: @Sendable (_ roomID: Int64) async -> Void
}

extension PrefetchRoomPhotosUseCase: TestDependencyKey {

    public static let testValue = PrefetchRoomPhotosUseCase()

    public static let previewValue = PrefetchRoomPhotosUseCase(run: { _ in })
}

public extension DependencyValues {
    var prefetchRoomPhotosUseCase: PrefetchRoomPhotosUseCase {
        get { self[PrefetchRoomPhotosUseCase.self] }
        set { self[PrefetchRoomPhotosUseCase.self] = newValue }
    }
}
