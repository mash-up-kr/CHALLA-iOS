import Foundation
import os
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

@Suite("PrepareCameraFiltersUseCase.live")
struct PrepareCameraFiltersUseCaseLiveTests {

    @Test("넘긴 필터를 빠짐없이 내려받아 등록한다")
    func registersEveryFilter() async throws {
        let filters = CameraFilter.previewFilters
        let lut = Data("LUT_3D_SIZE 2".utf8)
        let repository = MockCameraFilterRepository(lutDataResult: .success(lut))
        let registered = OSAllocatedUnfairLock<[CameraFilter.ID: Data]>(initialState: [:])
        let useCase = PrepareCameraFiltersUseCase.live(repository: repository) { data, id in
            registered.withLock { $0[id] = data }
            return true
        }

        try await useCase.run(filters)

        let expected = Dictionary(uniqueKeysWithValues: filters.map { ($0.id, lut) })
        #expect(repository.lutRequests.map(\.id).sorted() == filters.map(\.id).sorted())
        #expect(registered.withLock { $0 } == expected)
    }

    @Test("다운로드가 하나라도 실패하면 던진다 — 진입 버튼이 이 오류로 카메라를 막는다")
    func throwsWhenDownloadFails() async {
        let useCase = PrepareCameraFiltersUseCase.live(
            repository: MockCameraFilterRepository(lutDataResult: .failure(.network))
        ) { _, _ in true }

        await #expect(throws: PhotoError.network) {
            try await useCase.run(CameraFilter.previewFilters)
        }
    }

    @Test("파일이 깨져 등록에 실패해도 던진다")
    func throwsWhenRegistrationFails() async {
        let useCase = PrepareCameraFiltersUseCase.live(
            repository: MockCameraFilterRepository(lutDataResult: .success(Data("깨진 파일".utf8)))
        ) { _, _ in false }

        await #expect(throws: PhotoError.unknown) {
            try await useCase.run(CameraFilter.previewFilters)
        }
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
