import ComposableArchitecture
import Foundation
import RoomDomain

/// 앱 전체를 감싸는 루트 — 화면 전환(`AppFeature`) 위에 화면과 무관한 것을 얹는다.
///
/// 지금 얹는 것은 방 참여 토스트 하나다. 정책이 "어떤 화면에 있든 뜬다"라서
/// 방 상세 화면이 아니라 여기가 주인이어야 한다.
@Reducer
public struct RootFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        public var app: AppFeature.State = .launching

        /// 지금 떠 있는 참여 안내. nil이면 숨김.
        public var joinToast: RoomMemberJoined?

        /// 참여 구독을 다시 걸어 본 횟수.
        var roomEventRetryCount = 0

        /// 지금 구독 중인 방. 토스트를 눌렀을 때 열 방을 여기서 찾는다 —
        /// 참여 이벤트에는 방 id와 이름뿐이라 그것만으로는 화면을 못 만든다.
        var subscribedRooms: [Room] = []

        /// 참여 구독 대상 = 홈이 이미 받아 둔 방 목록. 이 값을 쓰려고 목록을 따로 조회하지 않는다.
        ///
        /// 홈이 아닌 화면에서는 지금 구독 중인 값을 그대로 돌려준다 —
        /// 화면을 옮겼다고 구독을 끊으면 다른 화면에서 알림을 못 받는다.
        var subscribableRooms: [Room] {
            // 로그인 전 화면에서는 비운다. 로그아웃 뒤에도 이전 계정의 방을 듣고 있으면
            // 그 계정의 참여 토스트가 로그인 화면 위에 뜬다.
            guard app.currentProfile != nil else { return [] }
            guard case let .home(screen) = app else { return subscribedRooms }
            // 홈으로 돌아오면 화면이 새로 만들어져 목록이 잠깐 비어 있다.
            // 그때 구독을 끊으면 뒤로 갈 때마다 전체 재구독이 돌고, 그 틈에 온 이벤트를 놓친다.
            guard !screen.home.cards.isEmpty else { return subscribedRooms }
            return screen.home.cards.map(\.room)
        }

        /// 구독을 다시 걸지 판단하는 기준. 방 **목록**이 바뀔 때만 다시 건다.
        ///
        /// `Room` 전체를 보면 사진 한 장 찍어 `remainedPhotoCount`만 달라져도 전체 재구독이 돈다
        /// (홈이 진입할 때마다 목록을 새로 받는다). 그 사이에 온 이벤트는 버려진다.
        var subscribableRoomIDs: [Room.ID] {
            subscribableRooms.map(\.id)
        }

        public init() {}
    }

    // MARK: - Action

    public enum Action {
        case app(AppFeature.Action)
        /// 구독 중인 방에서 온 이벤트.
        case roomEvent(RoomMemberJoinedEvent)
        /// 구독을 걸지 못했다. 잠시 뒤 정해진 횟수만큼 다시 시도한다.
        case roomEventsFailed
        /// 재시도할 차례다.
        case roomEventsRetryRequested
        /// 토스트를 눌렀다 — 그 방으로 이동한다.
        case toastTapped
        case toastDismissed
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.observeRoomMemberJoinedUseCase) var observeRoomMemberJoinedUseCase
    @Dependency(\.continuousClock) var clock

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        // 하나로 묶어야 onChange가 자식 리듀서(AppFeature)가 만든 상태 변화까지 본다.
        // 뒤쪽 Reduce에만 붙이면 홈이 목록을 받은 변화를 놓친다.
        CombineReducers {
            Scope(state: \.app, action: \.app) {
                AppFeature()
            }

            Reduce { state, action in
                switch action {
                case .app:
                    return .none

                case let .roomEvent(.joined(joined)):
                    state.roomEventRetryCount = 0
                    // 내가 들어간 것을 나에게 알리지 않는다.
                    // 서버가 사용자 단위 주소로 보내기 시작하면 내 참여도 나에게 온다.
                    if let profile = state.app.currentProfile, joined.isMe(userID: profile.id) {
                        return .none
                    }
                    // 전환 기간에는 같은 참여가 사용자 주소와 방 주소로 두 번 온다.
                    // 이미 그 알림을 띄우고 있으면 무시한다 — 같은 사람이 같은 방에 두 번 들어올 수는 없다.
                    guard state.joinToast != joined else { return .none }
                    state.joinToast = joined
                    return .merge(
                        // 연달아 들어와도 마지막 것만 보이고, 볼 시간은 매번 처음부터 다시 준다.
                        .run { [clock] send in
                            try await clock.sleep(for: Const.toastDuration)
                            await send(.toastDismissed)
                        }
                        .cancellable(id: CancelID.toast, cancelInFlight: true),
                        notifyOpenRoomDetail(state, joinedRoomID: joined.roomID)
                    )

                case .roomEvent(.resumed):
                    // 실시간이 실제로 붙었다. 다음 장애를 위해 재시도 예산을 되돌린다.
                    state.roomEventRetryCount = 0
                    // 끊긴 사이에 무슨 일이 있었는지 알 수 없다. 토스트는 띄우지 않되,
                    // 열려 있는 방이 있으면 참여자를 다시 조회하게 한다.
                    return notifyOpenRoomDetail(state, joinedRoomID: nil)

                case .toastTapped:
                    let openable = state.joinToast.flatMap { toast in
                        state.subscribedRooms.first { $0.id == toast.roomID }
                    }
                    guard let room = openable else {
                        // 목록에 없는 방이면 열 수 없다. 토스트만 내린다.
                        state.joinToast = nil
                        return .cancel(id: CancelID.toast)
                    }
                    state.joinToast = nil
                    return .merge(
                        .cancel(id: CancelID.toast),
                        .send(.app(.openRoomRequested(room)))
                    )

                case .roomEventsFailed:
                    guard state.roomEventRetryCount < Const.roomEventRetries else { return .none }
                    state.roomEventRetryCount += 1
                    return .run { [clock] send in
                        try await clock.sleep(for: Const.roomEventRetryDelay)
                        await send(.roomEventsRetryRequested)
                    }
                    .cancellable(id: CancelID.roomEventsRetry, cancelInFlight: true)

                case .roomEventsRetryRequested:
                    return observeRooms(&state, rooms: state.subscribedRooms, isRetry: true)

                case .toastDismissed:
                    state.joinToast = nil
                    return .none
                }
            }
        }
        // 홈이 목록을 새로 받을 때마다(진입·방 생성·참여) 구독 대상을 맞춘다.
        .onChange(of: \.subscribableRoomIDs) { _, _ in
            Reduce { state, _ in
                observeRooms(&state, rooms: state.subscribableRooms)
            }
        }
    }

    // MARK: - Effects

    /// 내 방들의 참여 이벤트를 **하나의 스트림**으로 받는다.
    /// 방마다 구독을 거는 것은 Data 레이어(`RoomEventSubscriber`)의 사정이라 여기서는 보이지 않는다 —
    /// 서버에 사용자 단위 주소가 생겨도 이 코드는 그대로다.
    ///
    /// 구독 실패는 조용히 넘긴다. 토스트가 없을 뿐 앱의 다른 동작에는 영향이 없다.
    private func observeRooms(
        _ state: inout State,
        rooms: [Room],
        isRetry: Bool = false
    ) -> Effect<Action> {
        state.subscribedRooms = rooms
        // 재시도가 아니라 새로 거는 것(홈 진입·방 목록 변경·재로그인)이면 예산을 되돌린다.
        // 그러지 않으면 한 번 3회를 소진한 뒤로는 어떤 장애에도 다시 시도하지 않는다.
        if !isRetry {
            state.roomEventRetryCount = 0
        }
        guard !rooms.isEmpty else {
            // 여기까지 비어 오는 것은 로그아웃뿐이다(홈의 일시적 빈 목록은 위에서 걸러진다).
            // 듣고 있던 것을 끊고 떠 있는 토스트도 거둔다.
            state.joinToast = nil
            return .merge(.cancel(id: CancelID.roomEvents), .cancel(id: CancelID.toast))
        }
        let roomIDs = rooms.map(\.id)

        return .run { [observeRoomMemberJoinedUseCase] send in
            let events = try await observeRoomMemberJoinedUseCase.run(roomIDs)
            for try await event in events {
                await send(.roomEvent(event))
            }
            // 정상 종료는 구독을 거둘 때뿐이라 알릴 것이 없다.
        } catch: { _, send in
            await send(.roomEventsFailed)
        }
        .cancellable(id: CancelID.roomEvents, cancelInFlight: true)
    }

    /// 그 방을 보고 있으면 참여자 목록을 다시 조회하라고 알린다.
    /// 방 상세는 따로 구독하지 않는다 — 앱 전체에서 참여 구독은 이 리듀서 하나뿐이다.
    private func notifyOpenRoomDetail(_ state: State, joinedRoomID: Room.ID?) -> Effect<Action> {
        guard case let .roomDetail(screen) = state.app else { return .none }
        // 재연결(joinedRoomID == nil)이면 어느 방인지 몰라 열려 있는 방을 그냥 갱신한다.
        guard joinedRoomID == nil || joinedRoomID == screen.roomDetail.room.id else { return .none }
        return .send(.app(.roomDetail(.memberJoined)))
    }

    private enum CancelID: Hashable {
        case toast
        case roomEvents
        case roomEventsRetry
    }

    private enum Const {
        // TODO: 노출 시간은 기획 미확정 — 다른 토스트와 같은 임시값. 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(3)
        /// 참여 구독이 실패했을 때 다시 걸어 볼 횟수. 서버가 죽었을 때 계속 두드리지 않게 막는다.
        static let roomEventRetries = 3
        static let roomEventRetryDelay: Duration = .seconds(5)
    }
}
