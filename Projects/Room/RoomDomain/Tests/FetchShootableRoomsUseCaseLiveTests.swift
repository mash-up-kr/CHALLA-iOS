import RoomDomain
import Testing

@Suite("FetchShootableRoomsUseCase.live")
struct FetchShootableRoomsUseCaseLiveTests {

    @Test("저장소가 준 목록을 순서 그대로 돌려준다")
    func returnsRepositoryRooms() async throws {
        let rooms = ShootableRoom.previewRooms
        let repository = MockRoomRepository(shootableRoomsResult: .success(rooms))
        let useCase = FetchShootableRoomsUseCase.live(repository: repository)

        let result = try await useCase.run()

        #expect(result == rooms)
        #expect(repository.shootableRoomsCallCount == 1)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = FetchShootableRoomsUseCase.live(
            repository: MockRoomRepository(shootableRoomsResult: .failure(.network))
        )

        await #expect(throws: RoomError.network) {
            _ = try await useCase.run()
        }
    }
}
