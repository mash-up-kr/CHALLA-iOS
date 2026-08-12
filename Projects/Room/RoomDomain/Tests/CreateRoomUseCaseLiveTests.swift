import RoomDomain
import Testing

@Suite("CreateRoomUseCase.live")
struct CreateRoomUseCaseLiveTests {

    @Test("성공 흐름: 입력값이 저장소로 전달되고 생성된 방이 돌아온다")
    func passesDraftAndReturnsRoom() async throws {
        let created = Room.previewShooting
        let repository = MockRoomRepository(createResult: .success(created))
        let useCase = CreateRoomUseCase.live(repository: repository)

        let result = try await useCase.run(RoomDraft(name: "제주 우정 여행", shotCount: .fortyEight))

        #expect(result == created)
        #expect(repository.createdDrafts == [RoomDraft(name: "제주 우정 여행", shotCount: .fortyEight)])
    }

    @Test("20자를 넘는 이름은 잘린 뒤 저장소로 넘어간다")
    func truncatesNameBeforeRepository() async throws {
        let repository = MockRoomRepository(createResult: .success(.previewShooting))
        let useCase = CreateRoomUseCase.live(repository: repository)

        _ = try await useCase.run(
            RoomDraft(name: String(repeating: "가", count: 25), shotCount: .default)
        )

        #expect(repository.createdDrafts.map(\.name) == [String(repeating: "가", count: 20)])
    }

    @Test("앞뒤 공백을 뗀 이름이 저장소로 넘어간다")
    func trimsNameBeforeRepository() async throws {
        let repository = MockRoomRepository(createResult: .success(.previewShooting))
        let useCase = CreateRoomUseCase.live(repository: repository)

        _ = try await useCase.run(RoomDraft(name: "  제주 우정 여행  ", shotCount: .default))

        #expect(repository.createdDrafts.map(\.name) == ["제주 우정 여행"])
    }

    @Test("공백이 앞에 붙어 20자를 넘겨도 이름이 통째로 잘리지 않는다")
    func trimsBeforeCutting() async throws {
        let repository = MockRoomRepository(createResult: .success(.previewShooting))
        let useCase = CreateRoomUseCase.live(repository: repository)

        // 자르기를 먼저 하면 공백 20자만 남아 .invalidRoomName이 난다.
        _ = try await useCase.run(
            RoomDraft(name: String(repeating: " ", count: 20) + "여행", shotCount: .default)
        )

        #expect(repository.createdDrafts.map(\.name) == ["여행"])
    }

    @Test("공백만 있는 이름은 저장소를 부르지 않고 .invalidRoomName을 던진다")
    func rejectsWhitespaceOnlyName() async {
        let repository = MockRoomRepository(createResult: .success(.previewShooting))
        let useCase = CreateRoomUseCase.live(repository: repository)

        await #expect(throws: RoomError.invalidRoomName) {
            _ = try await useCase.run(RoomDraft(name: "   ", shotCount: .default))
        }
        #expect(repository.createdDrafts.isEmpty)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = CreateRoomUseCase.live(
            repository: MockRoomRepository(createResult: .failure(.server(message: "생성 실패")))
        )

        await #expect(throws: RoomError.server(message: "생성 실패")) {
            _ = try await useCase.run(RoomDraft(name: "찰나", shotCount: .default))
        }
    }
}
