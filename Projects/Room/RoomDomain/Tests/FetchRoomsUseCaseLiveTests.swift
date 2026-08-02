import RoomDomain
import Testing

@Suite("FetchRoomsUseCase.live")
struct FetchRoomsUseCaseLiveTests {

    @Test("저장소가 준 목록을 순서 그대로 돌려준다")
    func returnsRepositoryRooms() async throws {
        let rooms = [Room.previewShooting, .previewPrintWaiting, .previewPrinted]
        let repository = MockRoomRepository(roomsResult: .success(rooms))
        let useCase = FetchRoomsUseCase.live(repository: repository)

        let result = try await useCase.run()

        #expect(result == rooms)
        #expect(repository.roomsCallCount == 1)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = FetchRoomsUseCase.live(
            repository: MockRoomRepository(roomsResult: .failure(.network))
        )

        await #expect(throws: RoomError.network) {
            _ = try await useCase.run()
        }
    }
}
