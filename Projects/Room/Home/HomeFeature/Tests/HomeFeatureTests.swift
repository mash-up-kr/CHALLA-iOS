import ComposableArchitecture
import RoomDomain
import Testing

@testable import HomeFeature

@MainActor
@Suite("HomeFeature")
struct HomeFeatureTests {

    // 스위트가 @MainActor라 static도 메인 액터에 묶이는데, 이 값은 UseCase의 @Sendable
    // 클로저 안에서 읽힌다. 값 타입 상수라 격리가 필요 없어 nonisolated로 푼다.
    private nonisolated static let rooms = [Room.previewShooting, .previewPrintWaiting, .previewPrinted]

    private static func makeStore(
        initialState: HomeFeature.State = HomeFeature.State(),
        fetchRooms: FetchRoomsUseCase = .testValue
    ) -> TestStoreOf<HomeFeature> {
        TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.fetchRoomsUseCase = fetchRooms
        }
    }

    /// 리듀서가 만드는 것과 같은 조회 실패 얼럿. 문구가 바뀌면 여기도 함께 바뀌어야 한다.
    private static func fetchFailedAlert(_ error: RoomError) -> AlertState<HomeFeature.Action.Alert> {
        AlertState {
            TextState("방 목록을 불러오지 못했어요")
        } actions: {
            ButtonState(action: .retryTapped) { TextState("다시 시도") }
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }

    // MARK: - 조회

    @Test("화면 등장 시 목록을 조회해 State에 담는다")
    func taskLoadsRooms() async {
        let store = Self.makeStore(fetchRooms: FetchRoomsUseCase(run: { Self.rooms }))

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.rooms = IdentifiedArray(uniqueElements: Self.rooms)
        }
    }

    @Test("조회 실패는 얼럿을 띄우고, 다시 시도가 성공하면 목록이 채워진다")
    func failureThenRetrySucceeds() async {
        // 첫 호출은 실패, 두 번째는 성공 — 재시도가 실제로 재조회하는지 본다.
        let results = LockIsolated<[Result<[Room], RoomError>]>([.failure(.network), .success(Self.rooms)])
        let store = Self.makeStore(
            fetchRooms: FetchRoomsUseCase(run: { try results.withValue { $0.removeFirst() }.get() })
        )

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.failure) {
            $0.loadState = .failed(.network)
            $0.alert = Self.fetchFailedAlert(.network)
        }

        // 얼럿 버튼 액션이 들어오면 ifLet이 얼럿을 내리고, 리듀서가 재조회를 시작한다.
        await store.send(.alert(.presented(.retryTapped))) {
            $0.alert = nil
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.rooms = IdentifiedArray(uniqueElements: Self.rooms)
        }
    }

    @Test("조회 중에는 다시 조회하지 않는다")
    func ignoresDuplicateFetchWhileLoading() async {
        var state = HomeFeature.State()
        state.loadState = .loading
        // 의존성을 주입하지 않는다 — 가드를 뚫고 조회가 실행되면 testValue가 테스트를 실패시킨다.
        let store = Self.makeStore(initialState: state)

        await store.send(.view(.task))
    }

    // MARK: - 위임

    @Test("카드를 탭하면 해당 방을 delegate로 알린다")
    func roomTappedDelegates() async {
        var state = HomeFeature.State()
        state.rooms = IdentifiedArray(uniqueElements: Self.rooms)
        state.loadState = .loaded
        let store = Self.makeStore(initialState: state)

        await store.send(.view(.roomTapped(Room.previewShooting.id)))
        await store.receive(\.delegate.roomSelected, .previewShooting)
    }

    @Test("목록에 없는 방 탭은 무시한다")
    func unknownRoomTapIgnored() async {
        let store = Self.makeStore()

        await store.send(.view(.roomTapped("ghost")))
    }

    @Test("설정 버튼은 delegate로 위임한다")
    func settingsDelegates() async {
        let store = Self.makeStore()

        await store.send(.view(.settingsButtonTapped))
        await store.receive(\.delegate.settingsTapped)
    }
}
