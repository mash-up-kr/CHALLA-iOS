import ComposableArchitecture
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 목록 조회와 사진 넘기기")
struct PhotoDetailPhotoTests {

    // MARK: - 목록 조회

    @Test("진입하면 목록을 받아 첫 장을 펼친다")
    func loadsPhotosOnAppear() async {
        let loaded = [Fixture.photo(id: "photo-1"), Fixture.photo(id: "photo-2")]
        let store = makeTestStore(photos: { roomID in
            #expect(roomID == Fixture.roomID)
            return loaded
        })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.success) {
            $0.isLoading = false
            $0.photos = IdentifiedArray(uniqueElements: loaded)
            $0.selectedPhotoID = "photo-1"
        }
    }

    @Test("진입할 때 지정한 사진이 있으면 그 장을 펼친다")
    func opensRequestedPhoto() async {
        let loaded = [Fixture.photo(id: "photo-1"), Fixture.photo(id: "photo-2")]
        let store = makeTestStore(initialPhotoID: "photo-2", photos: { _ in loaded })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.success) {
            $0.isLoading = false
            $0.photos = IdentifiedArray(uniqueElements: loaded)
            $0.selectedPhotoID = "photo-2"
        }
    }

    @Test("지정한 사진이 목록에 없으면 첫 장으로 떨어진다")
    func fallsBackToFirstPhoto() async {
        let loaded = [Fixture.photo(id: "photo-1")]
        let store = makeTestStore(initialPhotoID: "deleted-photo", photos: { _ in loaded })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.success) {
            $0.isLoading = false
            $0.photos = IdentifiedArray(uniqueElements: loaded)
            $0.selectedPhotoID = "photo-1"
        }
    }

    @Test("보고 있던 사진이 재조회에서 사라지면 첫 장으로 떨어진다")
    func fallsBackWhenSelectedPhotoDisappears() async {
        let first = [Fixture.photo(id: "photo-1"), Fixture.photo(id: "photo-2")]
        let second = [Fixture.photo(id: "photo-2")]
        let store = makeTestStore(initialPhotoID: "photo-1", photos: { _ in first })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.success) {
            $0.isLoading = false
            $0.photos = IdentifiedArray(uniqueElements: first)
            $0.selectedPhotoID = "photo-1"
        }

        await store.send(.photosResponse(.success(second))) {
            $0.photos = IdentifiedArray(uniqueElements: second)
            $0.selectedPhotoID = "photo-2"
        }
    }

    @Test("조회에 실패하면 다시 시도할 수 있는 얼럿을 띄운다")
    func showsRetryAlertOnLoadFailure() async {
        let loaded = [Fixture.photo(id: "photo-1")]
        let shouldFail = LockIsolated(true)
        let store = makeTestStore(photos: { _ in
            if shouldFail.value {
                shouldFail.setValue(false)
                throw PhotoError.network
            }
            return loaded
        })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("사진을 불러오지 못했어요")
            } actions: {
                ButtonState(action: .retryButtonTapped) { TextState("다시 시도") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }

        await store.send(.alert(.presented(.retryButtonTapped))) {
            $0.alert = nil
            $0.isLoading = true
        }
        await store.receive(\.photosResponse.success) {
            $0.isLoading = false
            $0.photos = IdentifiedArray(uniqueElements: loaded)
            $0.selectedPhotoID = "photo-1"
        }
    }

    @Test("사진이 한 장도 없으면 빈 목록으로 남는다")
    func marksEmptyState() async {
        let store = makeTestStore(photos: { _ in [] })

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.photosResponse.success) { $0.isLoading = false }
        #expect(store.state.photos.isEmpty)
        #expect(store.state.selectedPhoto == nil)
    }

    // MARK: - 사진 넘기기

    @Test("다른 장으로 넘기면 펼친 사진이 바뀐다")
    func changesSelectedPhoto() async {
        let loaded = [Fixture.photo(id: "photo-1"), Fixture.photo(id: "photo-2")]
        let store = await openedTestStore(photos: loaded)

        await store.send(.view(.photoSelected("photo-2"))) { $0.selectedPhotoID = "photo-2" }
    }

    @Test("목록에 없는 사진으로는 넘어가지 않는다")
    func ignoresUnknownPhotoSelection() async {
        let store = await openedTestStore(photos: [Fixture.photo(id: "photo-1")])

        await store.send(.view(.photoSelected("photo-9")))
        await store.send(.view(.photoSelected(nil)))
    }

    @Test("VoiceOver 이동은 앞뒤로 한 장씩 옮기고 끝에서는 멈춘다")
    func movesToAdjacentPhoto() async {
        let loaded = [Fixture.photo(id: "photo-1"), Fixture.photo(id: "photo-2")]
        let store = await openedTestStore(photos: loaded)

        await store.send(.view(.adjacentPhotoRequested(offset: -1)))
        await store.send(.view(.adjacentPhotoRequested(offset: 1))) { $0.selectedPhotoID = "photo-2" }
        await store.send(.view(.adjacentPhotoRequested(offset: 1)))
    }
}
