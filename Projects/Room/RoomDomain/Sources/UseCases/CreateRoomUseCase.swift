import Dependencies
import DependenciesMacros

/// 이름 규칙을 적용해 방을 만든다.
///
/// 뷰가 이미 막고 있어도 여기서 한 번 더 본다 — 진입점이 늘어도 규칙이 새지 않는다.
@DependencyClient
public struct CreateRoomUseCase: Sendable {
    public var run: @Sendable (_ draft: RoomDraft) async throws -> Room
}

extension CreateRoomUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> CreateRoomUseCase {
        CreateRoomUseCase(run: { draft in
            // 공백을 먼저 뗀다 — 자르기가 먼저면 "공백 20자 + 여행"이 공백만 남는다.
            let name = RoomNameRule.truncated(RoomNameRule.trimmed(draft.name))
            guard RoomNameRule.isSubmittable(name) else { throw RoomError.invalidRoomName }
            return try await repository.createRoom(
                RoomDraft(name: name, shotCount: draft.shotCount)
            )
        })
    }

    public static let testValue = CreateRoomUseCase()

    /// 입력한 이름을 그대로 돌려준다 (프리뷰 확인용).
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
