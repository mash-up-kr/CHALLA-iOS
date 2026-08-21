import PhotoDomain
import Testing

@Suite("FetchRoomPhotosUseCase · SetPhotoReactionUseCase")
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

    @Test("리액션은 목표 상태를 그대로 저장소에 넘기고 결과를 돌려준다")
    func forwardsReactionTarget() async throws {
        let updated = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart)])
        let repository = MockPhotoRepository(reactionResult: .success(updated))
        let useCase = SetPhotoReactionUseCase.live(repository: repository)

        let result = try await useCase.run("photo-1", .heart, true)

        #expect(repository.reactionCalls == [
            MockPhotoRepository.ReactionCall(photoID: "photo-1", kind: .heart, isOn: true)
        ])
        #expect(result == updated)
    }

    @Test("리액션 실패는 그대로 전달된다")
    func propagatesReactionFailure() async {
        let repository = MockPhotoRepository(reactionResult: .failure(.network))
        let useCase = SetPhotoReactionUseCase.live(repository: repository)

        await #expect(throws: PhotoError.network) {
            try await useCase.run("photo-1", .thumbsUp, false)
        }
    }
}
