import Dependencies
import DependenciesMacros

/// 방 상세와 참여자, 두 API 응답을 합쳐 `RoomDetail` 하나로 만든다.
@DependencyClient
public struct FetchRoomDetailUseCase: Sendable {
    public var run: @Sendable (_ id: Room.ID) async throws -> RoomDetail
}

extension FetchRoomDetailUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> FetchRoomDetailUseCase {
        FetchRoomDetailUseCase(run: { id in
            // 두 API를 병렬로 부른다. 한쪽이 실패하면 다른 쪽은 취소되고 에러 하나만 올라간다.
            async let info = repository.roomInfo(id: id)
            async let members = repository.members(roomID: id)

            // 병렬로 시작한 두 호출이 모두 끝나기를 기다린다.
            let (roomInfo, memberList) = try await (info, members)

            return RoomDetail(
                room: roomInfo.room,
                invitationCode: roomInfo.invitationCode,
                members: memberList
            )
        })
    }

    public static let testValue = FetchRoomDetailUseCase()

    public static let previewValue = FetchRoomDetailUseCase(run: { _ in .preview })
}

public extension DependencyValues {
    var fetchRoomDetailUseCase: FetchRoomDetailUseCase {
        get { self[FetchRoomDetailUseCase.self] }
        set { self[FetchRoomDetailUseCase.self] = newValue }
    }
}
