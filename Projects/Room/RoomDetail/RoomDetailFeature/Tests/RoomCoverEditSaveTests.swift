@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoLibrary
import RoomDomain
import Testing

private enum SaveFixture {
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
    static let wave = options.stickers[2]
    static let frame = options.stickers[6]

    static let storedSticker = waveSticker(color: cider)
    static let storedCover = RoomCover(imageURL: storedImageURL, sticker: storedSticker)

    static let uploadingToast = "사진을 올리는 중이에요. 잠시만 기다려 주세요"

    static func waveSticker(color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: wave.id, imageURL: wave.imageURL, color: color)
    }

    static func frameSticker(color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: frame.id, imageURL: frame.imageURL, color: color)
    }

    static var saveFailedAlert: AlertState<RoomCoverEditFeature.Action.Alert> {
        AlertState {
            TextState("커버를 저장하지 못했어요")
        } actions: {
            ButtonState(action: .retryTapped) { TextState("다시 시도") }
            ButtonState(action: .discardTapped) { TextState("저장 안 함") }
        }
    }

    static func makeState(cover: RoomCover = .none, localImageData: Data? = nil) -> RoomCoverEditFeature.State {
        var state = RoomCoverEditFeature.State(roomID: roomID, title: title, memberCount: memberCount, cover: cover)
        state.localImageData = localImageData
        return state
    }

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

    static func recordingUpdate(
        recordingInto drafts: LockIsolated<[(Room.ID, RoomCoverDraft)]> = LockIsolated([]),
        beforeReturn: @escaping @Sendable (RoomCoverDraft) async throws -> Void = { _ in }
    ) -> UpdateRoomCoverUseCase {
        UpdateRoomCoverUseCase(run: { roomID, draft in
            drafts.withValue { $0.append((roomID, draft)) }
            try await beforeReturn(draft)
        })
    }

    static func failingUpdate(_ error: RoomError = .unknown) -> UpdateRoomCoverUseCase {
        UpdateRoomCoverUseCase(run: { _, _ in throw error })
    }
}

@MainActor
@Suite("RoomCoverEditFeature — 저장")
struct RoomCoverEditSaveTests {

    // MARK: - 사진 업로드

    @Test("사진이 인코딩되면 화면에 바로 그리고 업로드해 URL만 커버에 싣는다 — 저장은 부르지 않고 로컬 바이트는 남는다")
    func photoEncodedUploadsWithoutSaving() async {
        let store = SaveFixture.makeStore(initialState: SaveFixture.makeState(cover: RoomCover(sticker: SaveFixture.storedSticker)))

        await store.send(.photoEncoded(SaveFixture.imageData)) {
            $0.localImageData = SaveFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.receive(\.photoUploaded.success) {
            $0.isUploadingPhoto = false
            $0.cover.imageURL = SaveFixture.uploadedImageURL
        }
        #expect(store.state.localImageData == SaveFixture.imageData)
        #expect(store.state.savedCover == RoomCover(sticker: SaveFixture.storedSticker))
        #expect(store.state.hasChanges)
    }

    @Test("업로드에 실패하면 로컬 바이트를 버리고 토스트를 2초 띄운다")
    func photoUploadFailureDropsLocalImageAndToasts() async {
        let clock = TestClock()
        let store = SaveFixture.makeStore(
            initialState: SaveFixture.makeState(cover: SaveFixture.storedCover),
            upload: UploadRoomCoverImageUseCase(run: { _ in throw RoomError.network }),
            clock: clock
        )

        await store.send(.photoEncoded(SaveFixture.imageData)) {
            $0.localImageData = SaveFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.receive(\.photoUploaded.failure) {
            $0.isUploadingPhoto = false
            $0.localImageData = nil
            $0.toast = "사진을 올리지 못했어요"
        }
        #expect(store.state.cover == SaveFixture.storedCover)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastTimerFired) {
            $0.toast = nil
        }
    }

    @Test("사진을 올리는 동안 뒤로가기는 토스트로 막히고, 업로드가 끝난 뒤 뒤로가기 저장에 그 URL이 실린다")
    func backButtonBlockedWhileUploading() async {
        let clock = TestClock()
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        let store = SaveFixture.makeStore(
            upload: UploadRoomCoverImageUseCase(run: { _ in
                try await clock.sleep(for: .seconds(1))
                return SaveFixture.uploadedImageURL
            }),
            update: SaveFixture.recordingUpdate(recordingInto: drafts),
            clock: clock
        )

        await store.send(.photoEncoded(SaveFixture.imageData)) {
            $0.localImageData = SaveFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.send(.view(.backButtonTapped)) {
            $0.toast = SaveFixture.uploadingToast
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.photoUploaded.success) {
            $0.isUploadingPhoto = false
            $0.cover.imageURL = SaveFixture.uploadedImageURL
        }

        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
            $0.savedCover = RoomCover(imageURL: SaveFixture.uploadedImageURL)
        }
        await store.receive(\.delegate.closeTapped)
        #expect(drafts.value.map(\.1) == [RoomCoverDraft(imageURL: SaveFixture.uploadedImageURL)])

        await clock.advance(by: .seconds(1))
        await store.receive(\.toastTimerFired) {
            $0.toast = nil
        }
    }

    // MARK: - 뒤로가기

    @Test("바뀐 것이 없으면 뒤로가기는 저장 없이 바로 delegate로 위임한다")
    func backWithoutChangesDelegatesImmediately() async {
        let store = SaveFixture.makeStore(initialState: SaveFixture.makeState(cover: SaveFixture.storedCover))

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeTapped)
    }

    @Test("바뀐 것이 있으면 뒤로가기가 한 번 저장하고, 성공하면 savedCover를 갱신한 뒤 delegate로 위임한다")
    func backWithChangesSavesThenDelegates() async {
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        var initial = SaveFixture.makeState()
        initial.options = SaveFixture.options
        let store = SaveFixture.makeStore(initialState: initial, update: SaveFixture.recordingUpdate(recordingInto: drafts))

        await store.send(.view(.stickerTapped(SaveFixture.wave))) {
            $0.cover.sticker = SaveFixture.waveSticker(color: SaveFixture.lemonade)
        }
        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
            $0.savedCover = RoomCover(sticker: SaveFixture.waveSticker(color: SaveFixture.lemonade))
        }
        await store.receive(\.delegate.closeTapped)
        #expect(store.state.hasChanges == false)

        #expect(drafts.value.count == 1)
        #expect(drafts.value.first?.0 == SaveFixture.roomID)
        #expect(drafts.value.first?.1 == RoomCoverDraft(stickerID: SaveFixture.wave.id, colorID: SaveFixture.lemonade.id))
    }

    @Test("저장 draft에는 사진 URL·스티커·색의 마지막 상태가 실린다")
    func backSavesLatestPhotoStickerAndColor() async {
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        let store = SaveFixture.makeStore(
            initialState: SaveFixture.makeState(cover: SaveFixture.storedCover),
            update: SaveFixture.recordingUpdate(recordingInto: drafts)
        )

        await store.send(.photoEncoded(SaveFixture.imageData)) {
            $0.localImageData = SaveFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.receive(\.photoUploaded.success) {
            $0.isUploadingPhoto = false
            $0.cover.imageURL = SaveFixture.uploadedImageURL
        }
        await store.send(.view(.stickerTapped(SaveFixture.frame))) {
            $0.cover.sticker = SaveFixture.frameSticker(color: SaveFixture.cider)
        }
        await store.send(.view(.colorTapped(SaveFixture.raspberry))) {
            $0.selectedColor = SaveFixture.raspberry
            $0.cover.sticker = SaveFixture.frameSticker(color: SaveFixture.raspberry)
        }

        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
            $0.savedCover = RoomCover(
                imageURL: SaveFixture.uploadedImageURL,
                sticker: SaveFixture.frameSticker(color: SaveFixture.raspberry)
            )
        }
        await store.receive(\.delegate.closeTapped)
        #expect(store.state.localImageData == SaveFixture.imageData)

        #expect(drafts.value.map(\.1) == [
            RoomCoverDraft(imageURL: SaveFixture.uploadedImageURL, stickerID: SaveFixture.frame.id, colorID: SaveFixture.raspberry.id)
        ])
    }

    @Test("저장 응답을 기다리는 동안 뒤로가기를 다시 눌러도 무시된다")
    func backTapIgnoredWhileSaving() async {
        let clock = TestClock()
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        let store = SaveFixture.makeStore(
            initialState: SaveFixture.makeState(cover: SaveFixture.storedCover),
            update: SaveFixture.recordingUpdate(recordingInto: drafts, beforeReturn: { _ in
                try await clock.sleep(for: .seconds(1))
            }),
            clock: clock
        )

        await store.send(.view(.colorTapped(SaveFixture.raspberry))) {
            $0.selectedColor = SaveFixture.raspberry
            $0.cover.sticker = SaveFixture.waveSticker(color: SaveFixture.raspberry)
        }
        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.send(.view(.backButtonTapped))

        await clock.advance(by: .seconds(1))
        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
            $0.savedCover.sticker = SaveFixture.waveSticker(color: SaveFixture.raspberry)
        }
        await store.receive(\.delegate.closeTapped)

        #expect(drafts.value.count == 1)
    }

    @Test("저장에 실패하면 얼럿을 띄우고, '다시 시도'가 성공하면 그때 나간다")
    func saveFailureAlertsAndRetrySucceeds() async {
        let attempt = LockIsolated(0)
        let store = SaveFixture.makeStore(
            initialState: SaveFixture.makeState(cover: SaveFixture.storedCover),
            update: UpdateRoomCoverUseCase(run: { _, _ in
                let index = attempt.withValue { $0 += 1; return $0 }
                if index == 1 {
                    throw RoomError.network
                }
            })
        )

        await store.send(.view(.colorTapped(SaveFixture.raspberry))) {
            $0.selectedColor = SaveFixture.raspberry
            $0.cover.sticker = SaveFixture.waveSticker(color: SaveFixture.raspberry)
        }
        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.failure) {
            $0.isSaving = false
            $0.alert = SaveFixture.saveFailedAlert
        }
        #expect(store.state.cover.sticker == SaveFixture.waveSticker(color: SaveFixture.raspberry))

        await store.send(.alert(.presented(.retryTapped))) {
            $0.alert = nil
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
            $0.savedCover.sticker = SaveFixture.waveSticker(color: SaveFixture.raspberry)
        }
        await store.receive(\.delegate.closeTapped)

        #expect(attempt.value == 2)
    }

    @Test("'저장 안 함'은 커버를 진입 값으로 되돌리고 로컬 사진을 버린 뒤 나간다")
    func discardRevertsAndDelegates() async {
        let store = SaveFixture.makeStore(
            initialState: SaveFixture.makeState(cover: SaveFixture.storedCover),
            update: SaveFixture.failingUpdate()
        )

        await store.send(.photoEncoded(SaveFixture.imageData)) {
            $0.localImageData = SaveFixture.imageData
            $0.isUploadingPhoto = true
        }
        await store.receive(\.photoUploaded.success) {
            $0.isUploadingPhoto = false
            $0.cover.imageURL = SaveFixture.uploadedImageURL
        }
        await store.send(.view(.stickerTapped(SaveFixture.frame))) {
            $0.cover.sticker = SaveFixture.frameSticker(color: SaveFixture.cider)
        }
        await store.send(.view(.backButtonTapped)) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse.failure) {
            $0.isSaving = false
            $0.alert = SaveFixture.saveFailedAlert
        }

        await store.send(.alert(.presented(.discardTapped))) {
            $0.alert = nil
            $0.cover = SaveFixture.storedCover
            $0.localImageData = nil
        }
        await store.receive(\.delegate.closeTapped)
        #expect(store.state.hasChanges == false)
    }
}
