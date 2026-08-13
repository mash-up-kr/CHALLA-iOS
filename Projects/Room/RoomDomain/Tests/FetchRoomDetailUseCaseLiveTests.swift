import RoomDomain
import Testing

@Suite("FetchRoomDetailUseCase.live")
struct FetchRoomDetailUseCaseLiveTests {

    @Test("상세와 참여자를 합쳐 RoomDetail 하나로 돌려준다")
    func mergesInfoAndMembers() async throws {
        let members = RoomDetail.preview.members
        let repository = MockRoomRepository(
            roomInfoResult: .success((room: .previewShooting, invitationCode: "1928121")),
            membersResult: .success(members)
        )
        let useCase = FetchRoomDetailUseCase.live(repository: repository)

        let detail = try await useCase.run(Room.previewShooting.id)

        #expect(detail.room == .previewShooting)
        #expect(detail.invitationCode == "1928121")
        #expect(detail.members == members)
        // 두 API 모두 요청한 그 방을 조회했는지 본다.
        #expect(repository.roomInfoIDs == [Room.previewShooting.id])
        #expect(repository.memberRoomIDs == [Room.previewShooting.id])
    }

    @Test("방 정보 조회가 실패하면 그 오류가 그대로 전파된다")
    func propagatesRoomInfoError() async {
        let useCase = FetchRoomDetailUseCase.live(
            repository: MockRoomRepository(
                roomInfoResult: .failure(.roomNotFound),
                membersResult: .success([])
            )
        )

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await useCase.run(-1)
        }
    }

    @Test("참여자 조회가 실패해도 부분 성공 없이 오류 하나가 전파된다")
    func propagatesMembersError() async {
        let useCase = FetchRoomDetailUseCase.live(
            repository: MockRoomRepository(
                roomInfoResult: .success((room: .previewShooting, invitationCode: "1928121")),
                membersResult: .failure(.network)
            )
        )

        await #expect(throws: RoomError.network) {
            _ = try await useCase.run(Room.previewShooting.id)
        }
    }
}
