import Foundation
import PhotoDomain
import Testing

@Suite("FetchCameraFiltersUseCase.live")
struct FetchCameraFiltersUseCaseLiveTests {

    @Test("저장소가 준 필터 목록을 순서 그대로 돌려준다")
    func returnsRepositoryFilters() async throws {
        let filters = CameraFilter.previewFilters
        let repository = MockCameraFilterRepository(filtersResult: .success(filters))
        let useCase = FetchCameraFiltersUseCase.live(repository: repository)

        let result = try await useCase.run()

        #expect(result == filters)
        #expect(repository.filtersCallCount == 1)
    }

    @Test("저장소 오류는 그대로 전파된다")
    func propagatesRepositoryError() async {
        let useCase = FetchCameraFiltersUseCase.live(
            repository: MockCameraFilterRepository(filtersResult: .failure(.network))
        )

        await #expect(throws: PhotoError.network) {
            _ = try await useCase.run()
        }
    }
}

@Suite("LoadFilterLUTUseCase.live")
struct LoadFilterLUTUseCaseLiveTests {

    @Test("요청한 필터의 LUT 바이트를 돌려준다")
    func returnsLUTData() async throws {
        let filter = try #require(CameraFilter.previewFilters.first)
        let lut = Data("LUT_3D_SIZE 2".utf8)
        let repository = MockCameraFilterRepository(lutDataResult: .success(lut))
        let useCase = LoadFilterLUTUseCase.live(repository: repository)

        let result = try await useCase.run(filter)

        #expect(result == lut)
        #expect(repository.lutRequests == [filter])
    }
}

@Suite("UploadPhotoUseCase.live")
struct UploadPhotoUseCaseLiveTests {

    @Test("업로더에 인자를 그대로 넘기고 남은 장수를 돌려준다")
    func forwardsToUploader() async throws {
        let uploader = MockPhotoUploader(result: .success(5))
        let useCase = UploadPhotoUseCase.live(uploader: uploader)

        let remained = try await useCase.run(Data("jpeg".utf8), 7, "Warm")

        #expect(remained == 5)
        #expect(uploader.uploads == [
            MockPhotoUploader.Upload(jpegData: Data("jpeg".utf8), roomID: 7, filterName: "Warm")
        ])
    }

    @Test("업로더 오류는 그대로 전파된다")
    func propagatesUploaderError() async {
        let useCase = UploadPhotoUseCase.live(uploader: MockPhotoUploader(result: .failure(.photoExhausted)))

        await #expect(throws: PhotoError.photoExhausted) {
            _ = try await useCase.run(Data(), 7, "Warm")
        }
    }
}

@Suite("카메라 안내 UseCase.live")
struct CameraOnboardingUseCasesLiveTests {

    @Test("본 적 없으면 안내를 띄우라고 답한다")
    func showsWhenNeverSeen() async {
        let useCase = ShouldShowCameraCoachMarkUseCase.live(
            repository: MockCameraOnboardingRepository(hasSeen: false)
        )

        #expect(await useCase.run())
    }

    @Test("이미 본 적 있으면 안내를 띄우지 말라고 답한다")
    func hidesWhenAlreadySeen() async {
        let useCase = ShouldShowCameraCoachMarkUseCase.live(
            repository: MockCameraOnboardingRepository(hasSeen: true)
        )

        #expect(await !useCase.run())
    }

    @Test("봤다고 기록하면 이후 조회에서 띄우지 않는다")
    func markingSeenStops() async {
        let repository = MockCameraOnboardingRepository(hasSeen: false)
        let mark = MarkCameraCoachMarkSeenUseCase.live(repository: repository)
        let shouldShow = ShouldShowCameraCoachMarkUseCase.live(repository: repository)

        await mark.run()

        #expect(repository.didMarkSeen)
        #expect(await !shouldShow.run())
    }
}
