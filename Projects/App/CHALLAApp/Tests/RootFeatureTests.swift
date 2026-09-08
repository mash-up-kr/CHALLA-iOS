@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import HomeFeature
import os
import RoomDomain
import Testing
import UserDomain

/// 구독을 건 방 id를 기록하는 스텁. 이벤트는 테스트가 직접 밀어 넣는다.
final class SpyRoomEventStream: Sendable {

    private let state = OSAllocatedUnfairLock(initialState: [[Room.ID]]())
    private let events: @Sendable ([Room.ID]) -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error>

    init(events: @escaping @Sendable ([Room.ID]) -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }) {
        self.events = events
    }

    /// 구독 요청마다 넘어온 방 목록. 앱 전체에서 구독은 한 번만 걸려야 한다.
    var subscribeCalls: [[Room.ID]] {
        state.withLock { $0 }
    }

    var useCase: ObserveRoomMemberJoinedUseCase {
        ObserveRoomMemberJoinedUseCase(run: { [self] roomIDs in
            state.withLock { $0.append(roomIDs) }
            return events(roomIDs)
        })
    }
}

private enum Fixture {
    static let profile = UserProfile(id: 1, nickname: "찰나", imageURL: nil)

    static let joined = RoomMemberJoined(
        roomID: 1,
        roomTitle: "강릉 여행",
        nickname: "연준",
        profileImageURL: nil
    )

    static func card(id: Room.ID) -> RoomCard {
        RoomCard(room: .previewShooting, memberCount: 2, thumbnailURLs: [])
            .withRoomID(id)
    }
}

extension RoomCard {
    /// 샘플 카드의 id만 바꾼다 — 구독 대상이 방 id별로 갈리는지 보려면 서로 다른 id가 필요하다.
    func withRoomID(_ id: Room.ID) -> RoomCard {
        RoomCard(
            room: Room(
                id: id,
                title: room.title,
                status: room.status,
                totalPhotoCount: room.totalPhotoCount,
                remainedPhotoCount: room.remainedPhotoCount,
                createdAt: room.createdAt,
                expiresAt: room.expiresAt,
                photoPrintCompletedAt: room.photoPrintCompletedAt
            ),
            memberCount: memberCount,
            thumbnailURLs: thumbnailURLs,
            photoPrintCompletionCheckedAt: photoPrintCompletionCheckedAt
        )
    }
}

@MainActor
@Suite("RootFeature — 방 참여 토스트")
struct RootFeatureTests {

    @Test("참여 알림을 받으면 토스트를 띄우고 잠시 뒤 스스로 내린다")
    func showsAndDismissesToast() async {
        let clock = TestClock()
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }

        await store.send(.roomEvent(.joined(Fixture.joined))) {
            $0.joinToast = Fixture.joined
            $0.shownJoinKey = RootFeature.JoinKey(Fixture.joined)
        }

        await clock.advance(by: .seconds(3))
        await store.receive(\.toastDismissed) {
            $0.joinToast = nil
            $0.shownJoinKey = nil
        }
    }

    @Test("연달아 들어오면 마지막 것만 남고 노출 시간이 다시 시작된다")
    func laterJoinRestartsTimer() async {
        let clock = TestClock()
        let second = RoomMemberJoined(roomID: 2, roomTitle: "제주", nickname: "성현", profileImageURL: nil)
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }

        await store.send(.roomEvent(.joined(Fixture.joined))) {
            $0.joinToast = Fixture.joined
            $0.shownJoinKey = RootFeature.JoinKey(Fixture.joined)
        }
        await clock.advance(by: .seconds(2))
        await store.send(.roomEvent(.joined(second))) {
            $0.joinToast = second
            $0.shownJoinKey = RootFeature.JoinKey(second)
        }

        // 첫 토스트의 남은 1초가 지나도 내려가지 않는다 — 타이머가 다시 시작됐기 때문.
        await clock.advance(by: .seconds(2))
        await clock.advance(by: .seconds(1))
        await store.receive(\.toastDismissed) {
            $0.joinToast = nil
            $0.shownJoinKey = nil
        }
    }

    @Test("홈이 방 목록을 받으면 한 번의 구독으로 그 방들을 전부 받는다")
    func subscribesToRoomsFromHome() async {
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))

        let cards = [Fixture.card(id: 11), Fixture.card(id: 22)]
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = spy.useCase
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { cards })
        }
        store.exhaustivity = .off

        await store.send(.app(.home(.roomsResponse(.success(cards)))))
        await store.finish()

        // 방마다 구독을 거는 것은 Data 레이어 사정이라 여기서는 한 번만 부른다.
        #expect(spy.subscribeCalls == [[11, 22]])
        #expect(store.state.subscribedRooms.map(\.id) == [11, 22])
    }

    @Test("내가 들어간 것은 나에게 알리지 않는다")
    func ignoresOwnJoin() async {
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))

        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }
        store.exhaustivity = .off

        let mine = RoomMemberJoined(
            roomID: 11,
            roomTitle: "강릉 여행",
            userID: Fixture.profile.id,
            nickname: Fixture.profile.nickname ?? "",
            profileImageURL: nil
        )
        await store.send(.roomEvent(.joined(mine)))
        #expect(store.state.joinToast == nil)
    }

    @Test("토스트를 누르면 그 방으로 이동한다")
    func tappingToastOpensRoom() async {
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))

        let cards = [Fixture.card(id: 11)]
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = spy.useCase
        }
        store.exhaustivity = .off

        // 홈 목록이 들어와야 열 방 정보를 알 수 있다.
        await store.send(.app(.home(.roomsResponse(.success(cards)))))

        let joined = RoomMemberJoined(roomID: 11, roomTitle: "강릉 여행", nickname: "연준", profileImageURL: nil)
        await store.send(.roomEvent(.joined(joined)))
        await store.send(.toastTapped)
        await store.receive(\.app.openRoomRequested)

        #expect(store.state.joinToast == nil)
        #expect(store.state.app.screenID == .roomDetail)
    }

    @Test("로그인 전 화면에서는 방 열기 요청을 무시한다")
    func ignoresOpenRoomBeforeLogin() async {
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }
        store.exhaustivity = .off

        // .launching에는 화면을 만들 프로필이 없다.
        await store.send(.app(.openRoomRequested(Fixture.card(id: 11).room)))
        #expect(store.state.app.screenID == .launching)
    }

    @Test("그 방을 보고 있으면 참여자를 다시 조회하라고 방 상세에 알린다")
    func notifiesOpenRoomDetail() async {
        let room = Fixture.card(id: 11).room
        var initialState = RootFeature.State()
        initialState.app = .roomDetail(AppFeature.RoomDetailScreen(profile: Fixture.profile, room: room))

        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = .previewValue
            // 알림을 받은 방 상세가 참여자를 다시 조회한다.
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in .preview })
            // 재조회에 딸려 오는 초대 안내 확인 — 이 테스트의 관심사가 아니라 띄우지 않는다.
            $0.shouldShowInviteGuideUseCase.run = { false }
        }
        store.exhaustivity = .off

        let joined = RoomMemberJoined(roomID: 11, roomTitle: "강릉 여행", nickname: "연준", profileImageURL: nil)
        await store.send(.roomEvent(.joined(joined)))
        await store.receive(\.app.roomDetail.memberJoined)
        await store.receive(\.app.roomDetail.detailResponse.success)
    }

    @Test("다른 방의 참여 이벤트는 방 상세에 알리지 않는다")
    func doesNotNotifyForOtherRoom() async {
        let room = Fixture.card(id: 11).room
        var initialState = RootFeature.State()
        initialState.app = .roomDetail(AppFeature.RoomDetailScreen(profile: Fixture.profile, room: room))

        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }
        store.exhaustivity = .off

        let other = RoomMemberJoined(roomID: 99, roomTitle: "제주", nickname: "성현", profileImageURL: nil)
        await store.send(.roomEvent(.joined(other)))

        // 토스트는 뜨지만 방 상세는 건드리지 않는다.
        #expect(store.state.joinToast == other)
        #expect(store.state.app.screenID == .roomDetail)
    }

    @Test("재연결(.resumed)은 토스트를 띄우지 않는다")
    func resumedDoesNotShowToast() async {
        let spy = SpyRoomEventStream(events: { _ in
            AsyncThrowingStream {
                $0.yield(.resumed)
                $0.finish()
            }
        })
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))

        let cards = [Fixture.card(id: 11)]
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = spy.useCase
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { cards })
        }
        store.exhaustivity = .off

        await store.send(.app(.home(.roomsResponse(.success(cards)))))
        await store.finish()

        #expect(store.state.joinToast == nil)
    }

    @Test("재시도를 다 쓴 뒤에도 방 목록이 바뀌면 다시 시도할 수 있다")
    func retryBudgetResetsWhenSubscribingAnew() async {
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        // 앞선 장애로 재시도를 다 쓴 상태.
        initialState.roomEventRetryCount = 3

        let cards = [Fixture.card(id: 11)]
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = spy.useCase
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { cards })
        }
        store.exhaustivity = .off

        await store.send(.app(.home(.roomsResponse(.success(cards)))))
        await store.finish()

        // 예산을 되돌리지 않으면 이후 어떤 장애에도 다시 걸지 않는다.
        #expect(store.state.roomEventRetryCount == 0)
    }

    @Test("실시간이 다시 붙으면(.resumed) 재시도 예산을 되돌린다")
    func retryBudgetResetsOnResume() async {
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        initialState.roomEventRetryCount = 3

        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.roomEvent(.resumed))

        #expect(store.state.roomEventRetryCount == 0)
    }

    @Test("구독이 실패하면 정해진 횟수만 다시 걸고 멈춘다")
    func retriesSubscriptionABoundedNumberOfTimes() async {
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))
        initialState.roomEventRetryCount = 3

        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        // 예산을 다 쓴 뒤의 실패는 더 시도하지 않는다 — 죽은 서버를 계속 두드리지 않는다.
        await store.send(.roomEventsFailed)

        #expect(store.state.roomEventRetryCount == 3)
    }

    @Test("마지막 방을 나가 목록이 비면 이전 구독을 거둔다")
    func stopsSubscribingWhenLastRoomIsLeft() async {
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Fixture.profile))

        let cards = [Fixture.card(id: 11)]
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.observeRoomMemberJoinedUseCase = spy.useCase
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { cards })
        }
        store.exhaustivity = .off

        await store.send(.app(.home(.roomsResponse(.success(cards)))))
        await store.finish()
        #expect(store.state.subscribedRooms.map(\.id) == [11])

        // 조회가 끝난 뒤의 빈 목록은 "아직 안 불러왔다"가 아니라 "이제 내 방이 없다"이다.
        await store.send(.app(.home(.roomsResponse(.success([])))))
        await store.finish()

        #expect(store.state.subscribedRooms.isEmpty)
    }
}

/// 같은 참여가 두 주소로 두 번 오는 전환 기간의 처리.
@Suite("RootFeature — 참여 알림 중복 제거")
struct RootFeatureJoinDeduplicationTests {

    @Test("같은 참여가 두 주소로 두 번 와도 한 번만 처리한다 (전환 기간)")
    func ignoresDuplicateJoin() async {
        let clock = TestClock()
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }

        await store.send(.roomEvent(.joined(Fixture.joined))) {
            $0.joinToast = Fixture.joined
            $0.shownJoinKey = RootFeature.JoinKey(Fixture.joined)
        }
        // 사용자 주소·방 주소로 같은 이벤트가 또 온다 — 상태도 타이머도 건드리지 않는다.
        await store.send(.roomEvent(.joined(Fixture.joined)))

        await clock.advance(by: .seconds(3))
        await store.receive(\.toastDismissed) {
            $0.joinToast = nil
            $0.shownJoinKey = nil
        }
    }

    @Test("두 주소가 실어 주는 값이 서로 달라도 같은 참여면 한 번만 띄운다")
    func ignoresDuplicateJoinWithDifferentPayloads() async {
        // 전환 기간에 방 주소는 userId 없이, 사용자 주소는 userId를 실어 보낼 수 있다.
        // 값 전체를 비교하면 서로 다른 이벤트가 되어 같은 참여에 토스트가 두 번 뜬다.
        let fromRoomTopic = RoomMemberJoined(
            roomID: Fixture.joined.roomID,
            roomTitle: Fixture.joined.roomTitle,
            userID: nil,
            nickname: Fixture.joined.nickname,
            profileImageURL: nil
        )
        let fromUserQueue = RoomMemberJoined(
            roomID: Fixture.joined.roomID,
            roomTitle: Fixture.joined.roomTitle,
            userID: 99,
            nickname: Fixture.joined.nickname,
            profileImageURL: URL(string: "https://cdn.test/u.jpg")
        )

        let clock = TestClock()
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.observeRoomMemberJoinedUseCase = .previewValue
        }
        store.exhaustivity = .off

        await store.send(.roomEvent(.joined(fromRoomTopic)))
        await store.send(.roomEvent(.joined(fromUserQueue)))

        // 나중에 온 쪽이 화면을 덮어쓰지 않는다 — 타이머도 다시 시작되지 않아야 한다.
        #expect(store.state.joinToast == fromRoomTopic)

        await clock.advance(by: .seconds(3))
        await store.receive(\.toastDismissed)
        #expect(store.state.joinToast == nil)
    }
}
