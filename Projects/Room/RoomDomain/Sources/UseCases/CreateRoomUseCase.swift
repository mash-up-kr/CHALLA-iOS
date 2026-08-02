import Dependencies
import DependenciesMacros

/// 이름 규칙을 적용해 방을 만들고 생성된 방을 돌려준다.
///
/// 저장소를 그냥 통과시키지 않고 `RoomNameRule`을 여기서 한 번 더 적용한다 —
/// UseCase가 도메인 경계라, 진입점이 늘어도(드로어 외의 다른 화면) 규칙이 새지 않는다.
@DependencyClient
public struct CreateRoomUseCase: Sendable {
    public var run: @Sendable (_ draft: RoomDraft) async throws -> Room
}

extension CreateRoomUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> CreateRoomUseCase {
        CreateRoomUseCase(run: { draft in
            let name = RoomNameRule.sanitize(draft.name)
            guard RoomNameRule.isSubmittable(name) else { throw RoomError.invalidRoomName }
            return try await repository.createRoom(
                RoomDraft(name: name, shotCount: draft.shotCount)
            )
        })
    }

    public static let testValue = CreateRoomUseCase()

    /// 입력한 이름이 그대로 보여야 프리뷰에서 화면을 확인할 수 있다.
    public static let previewValue = CreateRoomUseCase(
        run: { draft in
            Room(
                id: "preview-created",
                name: draft.name,
                status: .shooting,
                memberCount: 1,
                photoCount: 0,
                shotCount: draft.shotCount,
                coverImageURL: nil,
                thumbnailURLs: []
            )
        }
    )
}

public extension DependencyValues {
    var createRoomUseCase: CreateRoomUseCase {
        get { self[CreateRoomUseCase.self] }
        set { self[CreateRoomUseCase.self] = newValue }
    }
}
