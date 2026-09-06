import PhotoDomain
import Testing

@Suite("FetchRoomPhotosUseCase · FetchPhotoReactionsUseCase · SetPhotoReactionUseCase")
struct PhotoUseCaseTests {

    @Test("조회는 받은 방 ID를 그대로 저장소에 넘긴다")
    func forwardsRoomID() async throws {
        let photos = [PhotoFixture.photo(id: "photo-1"), PhotoFixture.photo(id: "photo-2")]
        let repository = MockPhotoRepository(photosResult: .success(photos))
        let useCase = FetchRoomPhotosUseCase.live(repository: repository)

        let result = try await useCase.run(42)

        #expect(repository.requestedRoomIDs == [42])
        #expect(result.map(\.id) == ["photo-1", "photo-2"])
    }

    @Test("조회 실패는 그대로 전달된다")
    func propagatesFetchFailure() async {
        let repository = MockPhotoRepository(photosResult: .failure(.server(message: "서버 점검 중")))
        let useCase = FetchRoomPhotosUseCase.live(repository: repository)

        await #expect(throws: PhotoError.server(message: "서버 점검 중")) {
            try await useCase.run(42)
        }
    }

    @Test("리액션 조회는 방 ID와 사진 ID를 그대로 저장소에 넘긴다")
    func forwardsReactionPhotoID() async throws {
        let reactions = PhotoReactions(stickers: [PhotoReaction(chatID: 1, kind: .heart, userID: "1")])
        let repository = MockPhotoRepository(reactionsResult: .success(reactions))
        let useCase = FetchPhotoReactionsUseCase.live(repository: repository)

        let result = try await useCase.run(42, "photo-7")

        #expect(repository.reactionsForPhotoIDs == ["photo-7"])
        #expect(repository.reactionsRoomIDs == [42])
        #expect(result == reactions)
    }

    @Test("리액션은 방·사진·목표 상태를 그대로 저장소에 넘긴다")
    func forwardsReactionTarget() async throws {
        let repository = MockPhotoRepository(reactionResult: .success(()))
        let useCase = SetPhotoReactionUseCase.live(repository: repository)

        try await useCase.run(42, "photo-1", .heart)

        #expect(repository.reactionCalls == [
            MockPhotoRepository.ReactionCall(roomID: 42, photoID: "photo-1", kind: .heart)
        ])
    }

    @Test("리액션 실패는 그대로 전달된다")
    func propagatesReactionFailure() async {
        let repository = MockPhotoRepository(reactionResult: .failure(.network))
        let useCase = SetPhotoReactionUseCase.live(repository: repository)

        await #expect(throws: PhotoError.network) {
            try await useCase.run(42, "photo-1", .thumbsUp)
        }
    }
}
