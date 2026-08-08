import RoomDomain
import Testing

@Suite("JoinRoomUseCase.live")
struct JoinRoomUseCaseLiveTests {

    @Test("성공 흐름: 공백을 제거한 코드가 저장소로 전달되고 입장한 방이 돌아온다")
    func trimsCodeAndReturnsRoom() async throws {
        let joined = Room.previewShooting
        let repository = MockRoomRepository(joinResult: .success(joined))
        let useCase = JoinRoomUseCase.live(repository: repository)

        let result = try await useCase.run("  1928121  ")

        #expect(result == joined)
        #expect(repository.joinedCodes == ["1928121"])
    }

    @Test("공백만 있는 코드는 저장소를 부르지 않고 .invalidInviteCode를 던진다")
    func rejectsWhitespaceOnlyCode() async {
        let repository = MockRoomRepository(joinResult: .success(.previewShooting))
        let useCase = JoinRoomUseCase.live(repository: repository)

        await #expect(throws: RoomError.invalidInviteCode) {
            _ = try await useCase.run("   ")
        }
        #expect(repository.joinedCodes.isEmpty)
    }

    @Test("없는 코드의 .roomNotFound는 그대로 전파된다")
    func propagatesRoomNotFound() async {
        let useCase = JoinRoomUseCase.live(
            repository: MockRoomRepository(joinResult: .failure(.roomNotFound))
        )

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await useCase.run("NOPE")
        }
    }
}
