@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoLibrary
import RoomDomain
import Testing

private enum EditFixture {
    static let roomID = Room.previewShooting.id
    static let title = Room.previewShooting.title
    static let memberCount = 4
    static let options = RoomCoverOptions.preview
    static let imageData = Data([0x01, 0x02, 0x03])
    static let storedImageURL = URL(string: "https://example.com/cover/stored.jpg")!
    static let uploadedImageURL = URL(string: "https://example.com/cover/uploaded.jpg")!

    static let lemonade = options.colors[0]
    static let raspberry = options.colors[1]
    static let cider = options.colors[4]
    static let blueberry = options.colors[5]
    static let wave = options.stickers[2]
    static let frame = options.stickers[6]

    static let storedSticker = waveSticker(color: cider)
    static let storedCover = RoomCover(imageURL: storedImageURL, sticker: storedSticker)

    static func waveSticker(color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: wave.id, imageURL: wave.imageURL, color: color)
    }

    static func frameSticker(color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: frame.id, imageURL: frame.imageURL, color: color)
    }

    static func makeState(cover: RoomCover = .none, localImageData: Data? = nil) -> RoomCoverEditFeature.State {
        var state = RoomCoverEditFeature.State(roomID: roomID, title: title, memberCount: memberCount, cover: cover)
        state.localImageData = localImageData
        return state
    }

    /// 저장은 뒤로가기에서만 불린다 — 편집 테스트는 `update: .testValue`(호출되면 미구현 실패)가 기본이다.
    @MainActor
    static func makeStore(
        initialState: RoomCoverEditFeature.State = makeState(),
        fetchOptions: FetchRoomCoverOptionsUseCase = FetchRoomCoverOptionsUseCase(run: { options }),
        upload: UploadRoomCoverImageUseCase = UploadRoomCoverImageUseCase(run: { _ in uploadedImageURL }),
        update: UpdateRoomCoverUseCase = .testValue,
        permission: PhotoLibraryPermissionClient = PhotoLibraryPermissionClient(request: { _ in .authorized }),
        clock: any Clock<Duration> = TestClock()
    ) -> TestStoreOf<RoomCoverEditFeature> {
        TestStore(initialState: initialState) {
            RoomCoverEditFeature()
        } withDependencies: {
            $0.fetchRoomCoverOptionsUseCase = fetchOptions
            $0.uploadRoomCoverImageUseCase = upload
            $0.updateRoomCoverUseCase = update
            $0.photoLibraryPermission = permission
            $0.continuousClock = clock
        }
    }
}

@MainActor
@Suite("RoomCoverEditFeature")
struct RoomCoverEditFeatureTests {

    // MARK: - 옵션 조회

    @Test("진입 시 옵션을 받으면 저장하고, 선택 색이 없으면 첫 색을 고른다")
    func taskLoadsOptionsAndPicksFirstColor() async {
        let store = EditFixture.makeStore()

        await store.send(.view(.task))
        await store.receive(\.optionsResponse.success) {
            $0.options = EditFixture.options
            $0.selectedColor = EditFixture.lemonade
        }
    }

    @Test("스티커가 있는 커버로 들어오면 선택 색은 그 스티커 색이다")
    func taskKeepsStickerColorAsSelection() async {
        let store = EditFixture.makeStore(initialState: EditFixture.makeState(cover: EditFixture.storedCover))
        #expect(store.state.selectedColor == EditFixture.cider)

        await store.send(.view(.task))
        await store.receive(\.optionsResponse.success) {
            $0.options = EditFixture.options
        }
    }

    @Test("옵션 조회가 실패하면 토스트를 2초 띄우고 옵션은 비워 둔다")
    func taskFailureToasts() async {
        let clock = TestClock()
        let store = EditFixture.makeStore(
            fetchOptions: FetchRoomCoverOptionsUseCase(run: { throw RoomError.network }),
            clock: clock
        )

        await store.send(.view(.task))
        await store.receive(\.optionsResponse.failure) {
            $0.toast = "커버 옵션을 불러오지 못했어요"
        }
        #expect(store.state.options == .empty)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastTimerFired) {
            $0.toast = nil
        }
    }

    @Test("편집을 시작해도 옵션 조회는 취소되지 않는다 — 옵션은 편집과 무관하다")
    func editDoesNotCancelOptionsLoad() async {
        let clock = TestClock()
        let store = EditFixture.makeStore(
            initialState: EditFixture.makeState(cover: EditFixture.storedCover),
            fetchOptions: FetchRoomCoverOptionsUseCase(run: {
                try await clock.sleep(for: .seconds(1))
                return EditFixture.options
            }),
            clock: clock
        )

        await store.send(.view(.task))
        await store.send(.view(.colorTapped(EditFixture.raspberry))) {
            $0.selectedColor = EditFixture.raspberry
            $0.cover.sticker = EditFixture.waveSticker(color: EditFixture.raspberry)
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.optionsResponse.success) {
            $0.options = EditFixture.options
        }
    }

    // MARK: - 색

    @Test("스티커가 없을 때 색을 탭하면 선택만 바뀌고 커버는 그대로다")
    func colorTapWithoutStickerOnlySelects() async {
        let store = EditFixture.makeStore()

        await store.send(.view(.colorTapped(EditFixture.raspberry))) {
            $0.selectedColor = EditFixture.raspberry
        }
        #expect(store.state.hasChanges == false)
    }

    @Test("스티커가 있을 때 색을 탭하면 스티커 색만 바뀌고 저장은 부르지 않는다")
    func colorTapWithStickerRecolorsWithoutSaving() async {
        let store = EditFixture.makeStore(initialState: EditFixture.makeState(cover: EditFixture.storedCover))

        await store.send(.view(.colorTapped(EditFixture.raspberry))) {
            $0.selectedColor = EditFixture.raspberry
            $0.cover.sticker = EditFixture.waveSticker(color: EditFixture.raspberry)
        }
        #expect(store.state.savedCover == EditFixture.storedCover)
        #expect(store.state.hasChanges)
    }

    @Test("이미 선택된 색을 다시 탭하면 아무 일도 없다")
    func sameColorTapIsIgnored() async {
        let store = EditFixture.makeStore(initialState: EditFixture.makeState(cover: EditFixture.storedCover))

        await store.send(.view(.colorTapped(EditFixture.cider)))
    }

    // MARK: - 스티커

    @Test("스티커는 탭하면 선택, 같은 것을 다시 탭하면 해제, 다른 것을 탭하면 교체되고 저장은 부르지 않는다")
    func stickerTapTogglesAndReplaces() async {
        var initial = EditFixture.makeState()
        initial.options = EditFixture.options // 색을 고른 적이 없으면 팔레트 첫 색으로 붙는다
        let store = EditFixture.makeStore(initialState: initial)

        await store.send(.view(.stickerTapped(EditFixture.wave))) {
            $0.cover.sticker = EditFixture.waveSticker(color: EditFixture.lemonade)
        }
        #expect(store.state.hasChanges)

        await store.send(.view(.stickerTapped(EditFixture.wave))) {
            $0.cover.sticker = nil
        }
        #expect(store.state.hasChanges == false)

        await store.send(.view(.stickerTapped(EditFixture.frame))) {
            $0.cover.sticker = EditFixture.frameSticker(color: EditFixture.lemonade)
        }
        #expect(store.state.savedCover == .none)
    }

    @Test("먼저 고른 색이 있으면 스티커는 그 색으로 붙는다")
    func stickerTapUsesSelectedColor() async {
        let store = EditFixture.makeStore()

        await store.send(.view(.colorTapped(EditFixture.blueberry))) {
            $0.selectedColor = EditFixture.blueberry
        }
        await store.send(.view(.stickerTapped(EditFixture.wave))) {
            $0.cover.sticker = EditFixture.waveSticker(color: EditFixture.blueberry)
        }
    }

    @Test("hasChanges는 진입 값과 다를 때만 참이다 — 원래대로 되돌리면 다시 거짓")
    func hasChangesTracksDiffFromSavedCover() async {
        let store = EditFixture.makeStore(initialState: EditFixture.makeState(cover: EditFixture.storedCover))
        #expect(store.state.hasChanges == false)

        await store.send(.view(.colorTapped(EditFixture.raspberry))) {
            $0.selectedColor = EditFixture.raspberry
            $0.cover.sticker = EditFixture.waveSticker(color: EditFixture.raspberry)
        }
        #expect(store.state.hasChanges)

        await store.send(.view(.colorTapped(EditFixture.cider))) {
            $0.selectedColor = EditFixture.cider
            $0.cover.sticker = EditFixture.storedSticker
        }
        #expect(store.state.hasChanges == false)
    }

    // MARK: - 사진

    @Test("사진 접근이 허용되면 피커를 연다", arguments: [PhotoLibraryAuthorization.authorized, .limited])
    func cameraButtonOpensPickerWhenAllowed(authorization: PhotoLibraryAuthorization) async {
        let requestedLevel = LockIsolated<PhotoLibraryAccessLevel?>(nil)
        let store = EditFixture.makeStore(
            permission: PhotoLibraryPermissionClient(request: { level in
                requestedLevel.setValue(level)
                return authorization
            })
        )

        await store.send(.view(.cameraButtonTapped))
        await store.receive(\.photoAuthorizationResponse) {
            $0.isPhotoPickerPresented = true
        }

        #expect(requestedLevel.value == .readWrite)
    }

    @Test("사진 접근이 막히면 피커를 열지 않고 설정 안내 토스트를 2초 띄운다", arguments: [PhotoLibraryAuthorization.denied, .restricted])
    func cameraButtonToastsWhenBlocked(authorization: PhotoLibraryAuthorization) async {
        let clock = TestClock()
        let store = EditFixture.makeStore(
            permission: PhotoLibraryPermissionClient(request: { _ in authorization }),
            clock: clock
        )

        await store.send(.view(.cameraButtonTapped))
        await store.receive(\.photoAuthorizationResponse) {
            $0.toast = "설정에서 사진 접근을 허용해 주세요"
        }
        #expect(store.state.isPhotoPickerPresented == false)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastTimerFired) {
            $0.toast = nil
        }
    }

    @Test("사진 읽기에 실패하면 토스트를 2초 띄우고 커버는 건드리지 않는다")
    func photoLoadFailureToasts() async {
        let clock = TestClock()
        let store = EditFixture.makeStore(upload: .testValue, clock: clock) // 업로드가 불리면 미구현 실패

        await store.send(.photoEncoded(nil)) {
            $0.toast = "사진을 불러오지 못했어요"
        }

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastTimerFired) {
            $0.toast = nil
        }
    }

    // MARK: - X 버튼

    @Test("사진도 스티커도 없으면 X 버튼은 무시된다")
    func clearIgnoredWhenCoverIsEmpty() async {
        let store = EditFixture.makeStore()

        await store.send(.view(.clearButtonTapped))
    }

    @Test("X 버튼은 사진과 스티커를 함께 비우고 선택 색은 남긴다 — 저장은 부르지 않는다")
    func clearRemovesImageAndStickerWithoutSaving() async {
        let store = EditFixture.makeStore(
            initialState: EditFixture.makeState(cover: EditFixture.storedCover, localImageData: EditFixture.imageData)
        )

        await store.send(.view(.clearButtonTapped)) {
            $0.localImageData = nil
            $0.cover = .none
        }
        #expect(store.state.selectedColor == EditFixture.cider)
        #expect(store.state.savedCover == EditFixture.storedCover)
        #expect(store.state.hasChanges)
    }

    @Test("서버에 없는 로컬 사진만 있어도 X 버튼이 지운다 — 커버는 그대로라 변경으로 치지 않는다")
    func clearRemovesLocalOnlyPhoto() async {
        let store = EditFixture.makeStore(initialState: EditFixture.makeState(localImageData: EditFixture.imageData))

        await store.send(.view(.clearButtonTapped)) {
            $0.localImageData = nil
        }
        #expect(store.state.hasChanges == false)
    }

    @Test("업로드 중에 X 버튼을 누르면 업로드를 버린다 — 늦게 온 URL이 지운 사진을 되살리지 않는다")
    func clearDuringUploadCancelsUpload() async {
        let clock = TestClock()
        let store = EditFixture.makeStore(
            initialState: EditFixture.makeState(cover: EditFixture.storedCover),
            upload: UploadRoomCoverImageUseCase(run: { _ in
                try await clock.sleep(for: .seconds(1))
                return EditFixture.uploadedImageURL
            }),
            clock: clock
        )

        await store.send(.photoEncoded(EditFixture.imageData)) {
            $0.localImageData = EditFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.send(.view(.clearButtonTapped)) {
            $0.localImageData = nil
            $0.isUploadingPhoto = false
            $0.cover = .none
        }

        await clock.advance(by: .seconds(1))
        #expect(store.state.cover == .none)
    }
}
