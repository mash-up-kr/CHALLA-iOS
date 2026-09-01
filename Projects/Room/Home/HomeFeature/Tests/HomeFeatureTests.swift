@testable import HomeFeature
import ComposableArchitecture
import Foundation
import RoomDomain
import Testing

@MainActor
@Suite("HomeFeature")
struct HomeFeatureTests {

    /// 스위트가 @MainActor라 static도 메인 액터에 묶이는데, 이 값은 UseCase의 @Sendable
    /// 클로저 안에서 읽힌다. 값 타입 상수라 격리가 필요 없어 nonisolated로 푼다.
    private nonisolated static let cards = [RoomCard.previewShooting, .previewPrintWaiting, .previewPrinted]

    private static func makeStore(
        initialState: HomeFeature.State = HomeFeature.State(nickname: "찰나"),
        fetchRooms: FetchRoomsUseCase = .testValue,
        clock: any Clock<Duration> = TestClock()
    ) -> TestStoreOf<HomeFeature> {
        TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.fetchRoomsUseCase = fetchRooms
            $0.continuousClock = clock
            // 알람을 걸지 말지는 "지금이 완료 시각 전인가"로 갈리는데, 실제 시각을 읽으면 돌릴 때마다
            // 결과가 달라진다. 프리뷰 카드의 완료 시각(생성 + 3일)보다 뒤로 고정해 두면 기본 픽스처에서는
            // 알람이 걸리지 않는다 — 알람 동작 자체는 미래 완료 시각 카드를 쓰는 전용 테스트가 본다.
            $0.date = .constant(Date(timeIntervalSince1970: 1_790_000_000))
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
        let store = Self.makeStore(fetchRooms: FetchRoomsUseCase(run: { Self.cards }))

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.cards = IdentifiedArray(uniqueElements: Self.cards)
        }
    }

    @Test("조회를 마쳤는데 방이 없으면 빈 상태를 그린다")
    func emptyResultShowsEmptyState() async {
        let store = Self.makeStore(fetchRooms: FetchRoomsUseCase(run: { [] }))

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        // 조회 중에는 아직 빈 상태가 아니다 — 빈 화면이 보였다 목록으로 바뀌는 걸 막는 조건이다.
        #expect(!store.state.showsEmptyState)

        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
        }
        #expect(store.state.showsEmptyState)
    }

    @Test("조회 실패는 얼럿을 띄우고, 다시 시도가 성공하면 목록이 채워진다")
    func failureThenRetrySucceeds() async {
        // 첫 호출은 실패, 두 번째는 성공 — 재시도가 실제로 재조회하는지 본다.
        let results = LockIsolated<[Result<[RoomCard], RoomError>]>([.failure(.network), .success(Self.cards)])
        let store = Self.makeStore(
            fetchRooms: FetchRoomsUseCase(run: { try results.withValue { $0.removeFirst() }.get() })
        )

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.failure) {
            $0.loadState = .failed(.network)
            $0.destination = .alert(Self.fetchFailedAlert(.network))
        }
        // 얼럿을 닫아도 본문에 안내와 재시도 버튼이 남는다.
        #expect(store.state.errorMessage == RoomError.network.userMessage)

        // 얼럿 버튼 액션이 들어오면 ifLet이 얼럿을 내리고, 리듀서가 재조회를 시작한다.
        await store.send(.destination(.presented(.alert(.retryTapped)))) {
            $0.destination = nil
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.cards = IdentifiedArray(uniqueElements: Self.cards)
        }
    }

    @Test("목록이 있는 상태의 재조회 실패는 본문을 건드리지 않는다")
    func refetchFailureKeepsList() async {
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: Self.cards)
        state.loadState = .loaded
        let store = Self.makeStore(
            initialState: state,
            fetchRooms: FetchRoomsUseCase(run: { throw RoomError.network })
        )

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.failure) {
            $0.loadState = .failed(.network)
            $0.destination = .alert(Self.fetchFailedAlert(.network))
        }
        // 보여줄 목록이 남아 있으므로 실패 안내 대신 목록을 그대로 그린다.
        #expect(store.state.errorMessage == nil)
        #expect(!store.state.showsLoading)
        #expect(store.state.cards.count == Self.cards.count)
    }

    @Test("드로어가 열려 있으면 조회 실패 얼럿으로 덮지 않는다")
    func failureKeepsOpenDrawer() async {
        var state = HomeFeature.State(nickname: "찰나")
        state.destination = .createRoom(CreateRoomFeature.State())
        let store = Self.makeStore(
            initialState: state,
            fetchRooms: FetchRoomsUseCase(run: { throw RoomError.network })
        )

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        // destination은 그대로 드로어다 — 얼럿이 대입됐다면 여기서 실패한다.
        await store.receive(\.roomsResponse.failure) {
            $0.loadState = .failed(.network)
        }
    }

    @Test("취소로 loadState가 .loading에 남아 있어도 다시 들어오면 조회한다")
    func staleLoadingDoesNotBlockFetch() async {
        // 화면을 벗어나 이펙트가 취소되면 액션이 오지 않아 loadState가 .loading에 남는다.
        // 그 상태로 다시 들어온 상황이다 — 가드로 막으면 여기서 조회가 시작되지 않는다.
        var state = HomeFeature.State(nickname: "찰나")
        state.loadState = .loading
        let store = Self.makeStore(
            initialState: state,
            fetchRooms: FetchRoomsUseCase(run: { Self.cards })
        )

        await store.send(.view(.task))
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.cards = IdentifiedArray(uniqueElements: Self.cards)
        }
    }

    // MARK: - 위임

    @Test("카드를 탭하면 해당 방을 delegate로 알린다")
    func roomTappedDelegates() async {
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: Self.cards)
        state.loadState = .loaded
        let store = Self.makeStore(initialState: state)

        await store.send(.view(.roomTapped(RoomCard.previewShooting.id)))
        await store.receive(\.delegate.roomSelected, .previewShooting)
    }

    @Test("목록에 없는 방 탭은 무시한다")
    func unknownRoomTapIgnored() async {
        let store = Self.makeStore()

        await store.send(.view(.roomTapped(-999)))
    }

    @Test("설정 버튼은 delegate로 위임한다")
    func settingsDelegates() async {
        let store = Self.makeStore()

        await store.send(.view(.settingsButtonTapped))
        await store.receive(\.delegate.settingsTapped)
    }

    // MARK: - 방 만들기

    @Test("+ 버튼은 메뉴를 토글하고, 방 만들기를 고르면 메뉴가 내려가며 드로어가 뜬다")
    func plusMenuTogglesAndOpensCreateDrawer() async {
        let store = Self.makeStore()

        await store.send(.view(.plusButtonTapped)) {
            $0.isPlusMenuPresented = true
        }
        await store.send(.view(.createRoomButtonTapped)) {
            $0.isPlusMenuPresented = false
            $0.destination = .createRoom(CreateRoomFeature.State())
        }
    }

    @Test("드로어가 방 생성을 알리면 드로어를 닫고 목록 맨 앞에 넣은 뒤 delegate로 넘긴다")
    func createdRoomClosesDrawerAndPrepends() async {
        let created = RoomCard.previewPrinted
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: [RoomCard.previewShooting])
        state.loadState = .loaded
        state.destination = .createRoom(CreateRoomFeature.State())
        let store = Self.makeStore(initialState: state)

        await store.send(.destination(.presented(.createRoom(.delegate(.created(created)))))) {
            $0.destination = nil
            $0.cards.insert(created, at: 0)
        }
        await store.receive(\.delegate.roomCreated, created)
    }

    // MARK: - 초대 코드 입장

    @Test("+ 메뉴에서 방 입장하기를 고르면 메뉴가 내려가며 입장 드로어가 뜬다")
    func plusMenuOpensJoinDrawer() async {
        let store = Self.makeStore()

        await store.send(.view(.plusButtonTapped)) {
            $0.isPlusMenuPresented = true
        }
        await store.send(.view(.joinRoomButtonTapped)) {
            $0.isPlusMenuPresented = false
            $0.destination = .joinRoom(JoinRoomFeature.State())
        }
    }

    @Test("드로어가 입장을 알리면 드로어를 닫고 목록 맨 앞에 넣은 뒤 delegate로 넘긴다")
    func joinedRoomClosesDrawerAndPrepends() async {
        let joined = RoomCard.previewPrintWaiting
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: [RoomCard.previewShooting])
        state.loadState = .loaded
        state.destination = .joinRoom(JoinRoomFeature.State())
        let store = Self.makeStore(initialState: state)

        await store.send(.destination(.presented(.joinRoom(.delegate(.joined(joined)))))) {
            $0.destination = nil
            $0.cards.insert(joined, at: 0)
        }
        await store.receive(\.delegate.roomJoined, joined)
    }

    @Test("이미 목록에 있는 방에 다시 입장하면 중복 없이 값만 갱신한다")
    func rejoiningExistingRoomUpdatesInPlace() async {
        // 갱신된 방(인원 +1)을 받는 상황 — insert만 하면 같은 id가 두 번 들어간다.
        // updateOrInsert의 at: 0은 새 방에만 적용되므로 이 방은 원래 자리에 남는다.
        let updated = RoomCard(
            room: RoomCard.previewPrintWaiting.room,
            memberCount: RoomCard.previewPrintWaiting.memberCount + 1,
            thumbnailURLs: []
        )
        var state = HomeFeature.State(nickname: "찰나")
        state.cards = IdentifiedArray(uniqueElements: [.previewShooting, .previewPrintWaiting])
        state.loadState = .loaded
        state.destination = .joinRoom(JoinRoomFeature.State())
        let store = Self.makeStore(initialState: state)

        await store.send(.destination(.presented(.joinRoom(.delegate(.joined(updated)))))) {
            $0.destination = nil
            $0.cards = IdentifiedArray(uniqueElements: [.previewShooting, updated])
        }
        await store.receive(\.delegate.roomJoined, updated)
    }
}
