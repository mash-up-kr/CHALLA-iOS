import Foundation
import RoomDomain
import Testing

@Suite("FetchRoomCoverOptionsUseCase.live")
struct FetchRoomCoverOptionsUseCaseLiveTests {

    @Test("저장소가 준 옵션을 그대로 돌려준다")
    func returnsRepositoryOptions() async throws {
        let repository = MockRoomRepository(coverOptionsResult: .success(.preview))
        let useCase = FetchRoomCoverOptionsUseCase.live(repository: repository)

        let options = try await useCase.run()

        #expect(options == .preview)
        #expect(repository.coverOptionsCallCount == 1)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = FetchRoomCoverOptionsUseCase.live(
            repository: MockRoomRepository(coverOptionsResult: .failure(.network))
        )

        await #expect(throws: RoomError.network) {
            _ = try await useCase.run()
        }
    }
}

@Suite("UpdateRoomCoverUseCase.live")
struct UpdateRoomCoverUseCaseLiveTests {

    private static let imageURL = URL(string: "https://cdn.example.com/cover.jpg")!

    @Test("사진 URL·스티커·색을 그대로 저장소에 싣는다")
    func forwardsDraft() async throws {
        let repository = MockRoomRepository(updateCoverResult: .success(()))
        let useCase = UpdateRoomCoverUseCase.live(repository: repository)

        try await useCase.run(-1, RoomCoverDraft(imageURL: Self.imageURL, stickerID: 3, colorID: 2))

        #expect(repository.coverUpdates == [.init(roomID: -1, imageURL: Self.imageURL, stickerID: 3, colorID: 2)])
    }

    @Test("스티커가 없으면 색 id도 싣지 않는다")
    func dropsColorWithoutSticker() async throws {
        let repository = MockRoomRepository(updateCoverResult: .success(()))
        let useCase = UpdateRoomCoverUseCase.live(repository: repository)

        try await useCase.run(-1, RoomCoverDraft(imageURL: nil, stickerID: nil, colorID: 2))

        #expect(repository.coverUpdates == [.init(roomID: -1, imageURL: nil, stickerID: nil, colorID: nil)])
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = UpdateRoomCoverUseCase.live(
            repository: MockRoomRepository(updateCoverResult: .failure(.server(message: "저장 실패")))
        )

        await #expect(throws: RoomError.server(message: "저장 실패")) {
            try await useCase.run(-1, RoomCoverDraft(imageURL: Self.imageURL))
        }
    }
}

@Suite("UploadRoomCoverImageUseCase.live")
struct UploadRoomCoverImageUseCaseLiveTests {

    private static let uploadedURL = URL(string: "https://cdn.example.com/uploaded.jpg")!
    private static let imageData = Data([0xFF, 0xD8, 0xFF])

    @Test("업로더가 돌려준 URL을 그대로 넘긴다")
    func returnsUploadedURL() async throws {
        let uploader = MockRoomCoverImageUploader(result: .success(Self.uploadedURL))
        let useCase = UploadRoomCoverImageUseCase.live(uploader: uploader)

        let url = try await useCase.run(Self.imageData)

        #expect(url == Self.uploadedURL)
        #expect(uploader.uploadedData == [Self.imageData])
    }

    @Test("업로드 오류는 그대로 전파된다")
    func propagatesUploadError() async {
        let useCase = UploadRoomCoverImageUseCase.live(uploader: MockRoomCoverImageUploader(result: .failure(.network)))

        await #expect(throws: RoomError.network) {
            _ = try await useCase.run(Self.imageData)
        }
    }
}
