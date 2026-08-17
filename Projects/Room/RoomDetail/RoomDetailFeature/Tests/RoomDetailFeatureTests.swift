@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

@MainActor
@Suite("RoomDetailFeature")
struct RoomDetailFeatureTests {

    /// 조회가 채워줄 상세. room의 남은 장수가 홈에서 받은 값(12)과 다르게 5 — "최신화"를 검증할 재료다.
    private nonisolated static let fresherRoom = Room(
        id: Room.previewShooting.id,
        title: Room.previewShooting.title,
        status: .shooting,
        totalPhotoCount: 24,
        remainedPhotoCount: 5,
        createdAt: Room.previewShooting.createdAt,
        expiresAt: Room.previewShooting.expiresAt
    )

    private nonisolated static let detail = RoomDetail(
        room: fresherRoom,
        invitationCode: "1928121",
        members: RoomDetail.preview.members
    )

    private nonisolated static let photos = [
        Photo(
            id: "1",
            imageURL: URL(string: "https://img.example.com/1.jpg")!,
            author: PhotoAuthor(id: "u1", nickname: "찰나둥이"),
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    ]

    private static func makeStore(
        initialState: RoomDetailFeature.State = .init(room: .previewShooting),
        fetchDetail: FetchRoomDetailUseCase = .testValue,
        fetchPhotos: FetchRoomPhotosUseCase = .testValue,
        copy: CopyToPasteboard = .testValue,
        clock: any Clock<Duration> = TestClock()
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: initialState) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = fetchDetail
            $0.fetchRoomPhotosUseCase = fetchPhotos
            $0.copyToPasteboard = copy
            $0.continuousClock = clock
        }
    }

    // MARK: - 조회

    @Test("진입 시 상세와 사진을 함께 조회한다")
    func taskLoadsDetailAndPhotos() async {
        let store = Self.makeStore(
            fetchDetail: FetchRoomDetailUseCase(run: { _ in Self.detail }),
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in Self.photos })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.room = Self.fresherRoom // 홈에서 받은 값(남은 12장)이 서버 값(5장)으로 덮인다
        }
        await store.receive(\.photosResponse.success) {
            $0.photos = Self.photos
        }
    }

    @Test("상세 조회가 실패하면 얼럿으로 알린다")
    func detailFailureShowsAlert() async {
        let store = Self.makeStore(
            fetchDetail: FetchRoomDetailUseCase(run: { _ in throw RoomError.network }),
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in [] })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.failure) {
            $0.detailLoad = .failed
            $0.alert = AlertState {
                TextState("방 정보를 불러오지 못했어요")
            } actions: {
                ButtonState(action: .retryTapped) { TextState("다시 시도") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.network.userMessage)
            }
        }
        await store.receive(\.photosResponse.success) // 사진 0장 — 상태 변화 없음
    }

    @Test("사진만 실패하면 얼럿 없이 빈 그리드로 둔다")
    func photoFailureIsSilent() async {
        let store = Self.makeStore(
            fetchDetail: FetchRoomDetailUseCase(run: { _ in Self.detail }),
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in throw PhotoError.network })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.room = Self.fresherRoom
        }
        await store.receive(\.photosResponse.failure) // 상태 변화 없음 — 슬롯이 빈 모습 그대로
    }

    // MARK: - 팝오버

    @Test("팝오버를 여닫아도 조회를 다시 걸지 않는다")
    func popoverToggleDoesNotRefetchWhenLoaded() async {
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detail = Self.detail
        state.detailLoad = .loaded
        let store = Self.makeStore(initialState: state) // 조회 의존성이 testValue — 호출되면 미구현 실패

        await store.send(.binding(.set(\.isInvitePopoverPresented, true))) {
            $0.isInvitePopoverPresented = true
        }
        await store.send(.binding(.set(\.isInvitePopoverPresented, false))) {
            $0.isInvitePopoverPresented = false
        }
    }

    /// 사진 조회에는 따로 재시도 수단이 없다 — 상세 얼럿의 "다시 시도"가 둘을 함께 부른다.
    @Test("얼럿에서 다시 시도하면 상세와 사진을 함께 조회한다")
    func alertRetryRefetchesBoth() async {
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detailLoad = .failed
        state.alert = AlertState { TextState("방 정보를 불러오지 못했어요") }
        let store = Self.makeStore(
            initialState: state,
            fetchDetail: FetchRoomDetailUseCase(run: { _ in Self.detail }),
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in Self.photos })
        )

        await store.send(.alert(.presented(.retryTapped))) {
            $0.alert = nil
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.room = Self.fresherRoom
        }
        await store.receive(\.photosResponse.success) {
            $0.photos = Self.photos
        }
    }

    // MARK: - 복사

    @Test("복사 버튼은 초대 코드를 클립보드 의존성에 넘기고, 토스트를 띄웠다가 2초 뒤 거둔다")
    func copySendsCode() async {
        let copied = LockIsolated<String?>(nil)
        let clock = TestClock()
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detail = Self.detail
        state.detailLoad = .loaded
        let store = Self.makeStore(
            initialState: state,
            copy: CopyToPasteboard(run: { text in copied.setValue(text) }),
            clock: clock
        )

        await store.send(.view(.copyInviteCodeTapped)) {
            $0.toast = "초대 코드를 복사했어요"
        }
        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }

        #expect(copied.value == "1928121")
    }

    @Test("코드가 아직 없으면 복사는 무시된다")
    func copyIgnoredWithoutDetail() async {
        let store = Self.makeStore() // copy가 testValue — 호출되면 미구현 실패

        await store.send(.view(.copyInviteCodeTapped))
    }

    // MARK: - 카운트다운 표기

    @Test("남은 시간을 시:분:초로 표기한다", arguments: zip(
        [10798.0, 59.0, 3600.0], //   2시간 59분 58초 · 59초 · 정각 1시간
        ["2:59:58", "0:00:59", "1:00:00"]
    ))
    func countdownFormats(seconds: Double, expected: String) {
        let now = Date(timeIntervalSince1970: 0)

        #expect(PrintCountdown.text(until: now.addingTimeInterval(seconds), now: now) == expected)
    }

    @Test("완료 시각이 지나면 0:00:00으로 고정된다")
    func countdownClampsAtZero() {
        let now = Date(timeIntervalSince1970: 1000)

        #expect(PrintCountdown.text(until: now.addingTimeInterval(-5), now: now) == "0:00:00")
    }

    // MARK: - 위임

    @Test("뒤로가기·촬영·채팅 버튼은 delegate로 위임한다")
    func buttonsDelegate() async {
        let store = Self.makeStore()

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeTapped)
        await store.send(.view(.shootButtonTapped))
        await store.receive(\.delegate.shootTapped)
        await store.send(.view(.chatButtonTapped))
        await store.receive(\.delegate.chatTapped)
    }
}
