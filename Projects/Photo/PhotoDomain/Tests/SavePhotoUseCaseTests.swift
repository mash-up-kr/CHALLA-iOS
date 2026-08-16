import Foundation
import PhotoDomain
import Testing

@Suite("SavePhotoUseCase")
struct SavePhotoUseCaseTests {

    private let imageData = Data("사진 바이트".utf8)

    @Test("내려받은 바이트를 그대로 사진첩에 넘긴다")
    func passesDownloadedBytes() async throws {
        let repository = MockPhotoRepository(imageDataResult: .success(imageData))
        let library = MockPhotoLibraryWriter()
        let useCase = SavePhotoUseCase.live(repository: repository, photoLibrary: library)

        try await useCase.run(PhotoFixture.photo())

        #expect(repository.imageDataRequests == ["photo-1"])
        #expect(library.savedData == [imageData])
    }

    @Test("내려받기 실패는 그대로 전달된다")
    func propagatesDownloadFailure() async {
        let repository = MockPhotoRepository(imageDataResult: .failure(.network))
        let library = MockPhotoLibraryWriter()
        let useCase = SavePhotoUseCase.live(repository: repository, photoLibrary: library)

        await #expect(throws: PhotoError.network) {
            try await useCase.run(PhotoFixture.photo())
        }
        #expect(library.savedData.isEmpty)
    }

    @Test("권한 거부는 그대로 전달된다")
    func propagatesPermissionDenied() async {
        let repository = MockPhotoRepository(imageDataResult: .success(imageData))
        let library = MockPhotoLibraryWriter(result: .failure(PhotoError.permissionDenied))
        let useCase = SavePhotoUseCase.live(repository: repository, photoLibrary: library)

        await #expect(throws: PhotoError.permissionDenied) {
            try await useCase.run(PhotoFixture.photo())
        }
    }

    @Test("취소는 정규화하지 않고 그대로 던진다 — 이펙트 취소와 저장 실패는 다른 일이다")
    func rethrowsCancellation() async {
        let repository = MockPhotoRepository(imageDataResult: .success(imageData))
        let library = MockPhotoLibraryWriter(result: .failure(CancellationError()))
        let useCase = SavePhotoUseCase.live(repository: repository, photoLibrary: library)

        await #expect(throws: CancellationError.self) {
            try await useCase.run(PhotoFixture.photo())
        }
    }

    @Test("PhotoError가 아닌 오류가 새어 나와도 unknown으로 정규화된다")
    func normalizesUnexpectedError() async {
        struct UnexpectedError: Error {}
        let repository = MockPhotoRepository(imageDataResult: .success(imageData))
        let library = MockPhotoLibraryWriter(result: .failure(UnexpectedError()))
        let useCase = SavePhotoUseCase.live(repository: repository, photoLibrary: library)

        await #expect(throws: PhotoError.unknown) {
            try await useCase.run(PhotoFixture.photo())
        }
    }
}
