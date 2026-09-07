import RoomDomain
import Testing

@Suite("CheckPrintCompletionUseCase.live")
struct CheckPrintCompletionUseCaseLiveTests {

    @Test("방 id가 저장소에 그대로 전달된다")
    func passesRoomID() async throws {
        let repository = MockRoomRepository(checkPrintCompletionResult: .success(()))
        let useCase = CheckPrintCompletionUseCase.live(repository: repository)

        try await useCase.run(-3)

        #expect(repository.checkedPrintCompletionRoomIDs == [-3])
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = CheckPrintCompletionUseCase.live(
            repository: MockRoomRepository(checkPrintCompletionResult: .failure(.network))
        )

        await #expect(throws: RoomError.network) {
            try await useCase.run(-3)
        }
    }
}
