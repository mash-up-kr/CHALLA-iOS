@testable import RoomDetailFeature
import ComposableArchitecture
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

    private static func makeStore(
        initialState: RoomDetailFeature.State = .init(room: .previewShooting),
        fetchDetail: FetchRoomDetailUseCase = .testValue,
        copy: CopyToPasteboard = .testValue
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: initialState) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = fetchDetail
            $0.copyToPasteboard = copy
        }
    }

    // MARK: - 조회

    @Test("진입 시 상세를 조회해 초대 코드·참여자를 채우고 방 정보도 최신화한다")
    func taskLoadsDetail() async {
        let store = Self.makeStore(fetchDetail: FetchRoomDetailUseCase(run: { _ in Self.detail }))

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.room = Self.fresherRoom // 홈에서 받은 값(남은 12장)이 서버 값(5장)으로 덮인다
        }
    }

    @Test("조회 실패는 얼럿 없이 실패 상태만 기록한다")
    func failureIsSilent() async {
        let store = Self.makeStore(fetchDetail: FetchRoomDetailUseCase(run: { _ in throw RoomError.network }))

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.failure) {
            $0.detailLoad = .failed // 이게 전부다 — 얼럿 State 자체가 없다
        }
    }

    // MARK: - 팝오버

    @Test("팝오버가 열리고 닫혀도, 조회가 성공한 상태면 재조회하지 않는다")
    func popoverToggleDoesNotRefetchWhenLoaded() async {
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detail = Self.detail
        state.detailLoad = .loaded
        let store = Self.makeStore(initialState: state) // fetchDetail이 testValue — 호출되면 미구현 실패

        await store.send(.binding(.set(\.isInvitePopoverPresented, true))) {
            $0.isInvitePopoverPresented = true
        }
        await store.send(.binding(.set(\.isInvitePopoverPresented, false))) {
            $0.isInvitePopoverPresented = false
        }
    }

    @Test("조회가 실패한 상태에서 팝오버를 열면 재조회한다")
    func openingPopoverRetriesAfterFailure() async {
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detailLoad = .failed
        let store = Self.makeStore(
            initialState: state,
            fetchDetail: FetchRoomDetailUseCase(run: { _ in Self.detail })
        )

        await store.send(.binding(.set(\.isInvitePopoverPresented, true))) {
            $0.isInvitePopoverPresented = true
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.room = Self.fresherRoom
        }
    }

    // MARK: - 복사

    @Test("복사 버튼은 초대 코드를 클립보드 의존성에 넘긴다")
    func copySendsCode() async {
        let copied = LockIsolated<String?>(nil)
        var state = RoomDetailFeature.State(room: .previewShooting)
        state.detail = Self.detail
        state.detailLoad = .loaded
        let store = Self.makeStore(
            initialState: state,
            copy: CopyToPasteboard(run: { text in copied.setValue(text) })
        )

        await store.send(.view(.copyInviteCodeTapped))
        await store.finish()

        #expect(copied.value == "1928121")
    }

    @Test("코드가 아직 없으면 복사는 무시된다")
    func copyIgnoredWithoutDetail() async {
        let store = Self.makeStore() // copy가 testValue — 호출되면 미구현 실패

        await store.send(.view(.copyInviteCodeTapped))
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
