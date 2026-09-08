@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import HomeFeature
import RoomDomain
import Testing
import UserDomain

/// 구독을 언제 다시 거는지 — 너무 자주 걸면 그 틈에 온 이벤트가 사라진다.
@Suite("RootFeature — 재구독 조건")
struct RootFeatureResubscribeTests {

    @Test("목록 순서만 바뀌면 구독을 다시 걸지 않는다")
    func doesNotResubscribeWhenOnlyOrderChanges() async {
        // 홈은 들어올 때마다 목록을 새로 받는다. 순서만 달라져도 다시 걸면
        // 구독이 끊겼다 붙는 사이에 온 참여 이벤트가 사라진다.
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Sample.profile))

        let cards = [Sample.card(id: 11), Sample.card(id: 22)]
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
        await store.send(.app(.home(.roomsResponse(.success(cards.reversed())))))
        await store.finish()

        #expect(spy.subscribeCalls.count == 1)
    }

    @Test("방이 실제로 늘거나 줄면 다시 건다")
    func resubscribesWhenRoomSetChanges() async {
        let spy = SpyRoomEventStream()
        var initialState = RootFeature.State()
        initialState.app = .home(AppFeature.HomeScreen(profile: Sample.profile))

        let cards = [Sample.card(id: 11)]
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
        await store.send(.app(.home(.roomsResponse(.success(cards + [Sample.card(id: 22)])))))
        await store.finish()

        #expect(spy.subscribeCalls.count == 2)
    }
}

private enum Sample {
    static let profile = UserProfile(id: 1, nickname: "찰나", imageURL: nil)

    static func card(id: Room.ID) -> RoomCard {
        RoomCard(room: .previewShooting, memberCount: 2, thumbnailURLs: []).withRoomID(id)
    }
}
