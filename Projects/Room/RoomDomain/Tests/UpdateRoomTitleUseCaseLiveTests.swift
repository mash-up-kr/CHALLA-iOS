import RoomDomain
import Testing

@Suite("UpdateRoomTitleUseCase.live")
struct UpdateRoomTitleUseCaseLiveTests {

    @Test("성공 흐름: 정제된 이름과 방 id가 저장소로 전달되고, 같은 이름이 돌아온다")
    func passesRefinedNameAndReturnsIt() async throws {
        let repository = MockRoomRepository(updateTitleResult: .success(()))
        let useCase = UpdateRoomTitleUseCase.live(repository: repository)

        let result = try await useCase.run(-1, "  제주 우정 여행  ")

        #expect(result == "제주 우정 여행")
        #expect(repository.titleUpdates == [.init(roomID: -1, title: "제주 우정 여행")])
    }

    @Test("20자를 넘는 이름은 잘린 뒤 저장소로 넘어간다")
    func truncatesNameBeforeRepository() async throws {
        let repository = MockRoomRepository(updateTitleResult: .success(()))
        let useCase = UpdateRoomTitleUseCase.live(repository: repository)

        let result = try await useCase.run(-1, String(repeating: "가", count: 25))

        #expect(result == String(repeating: "가", count: 20))
        #expect(repository.titleUpdates.map(\.title) == [String(repeating: "가", count: 20)])
    }

    @Test("20자는 공백을 뗀 뒤에 센다")
    func trimsBeforeCutting() async throws {
        let repository = MockRoomRepository(updateTitleResult: .success(()))
        let useCase = UpdateRoomTitleUseCase.live(repository: repository)

        // 자르기를 먼저 하면 공백 20자만 남아 .invalidRoomName이 난다 (CreateRoomUseCase와 같은 순서).
        let result = try await useCase.run(-1, String(repeating: " ", count: 20) + "여행")

        #expect(result == "여행")
        #expect(repository.titleUpdates.map(\.title) == ["여행"])
    }

    @Test("빈 이름·공백만인 이름은 저장소를 부르지 않고 .invalidRoomName을 던진다", arguments: ["", "   ", " \n "])
    func rejectsBlankName(name: String) async {
        let repository = MockRoomRepository(updateTitleResult: .success(()))
        let useCase = UpdateRoomTitleUseCase.live(repository: repository)

        await #expect(throws: RoomError.invalidRoomName) {
            _ = try await useCase.run(-1, name)
        }
        #expect(repository.titleUpdates.isEmpty)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = UpdateRoomTitleUseCase.live(
            repository: MockRoomRepository(updateTitleResult: .failure(.server(message: "변경 실패")))
        )

        await #expect(throws: RoomError.server(message: "변경 실패")) {
            _ = try await useCase.run(-1, "강릉 여행")
        }
    }
}
