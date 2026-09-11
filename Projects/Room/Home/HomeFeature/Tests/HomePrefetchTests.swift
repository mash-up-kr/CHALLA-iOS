@testable import HomeFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 홈에 머무는 동안 인화 완료 안내에 쓸 사진을 미리 받아 두는 규칙.
@MainActor
@Suite("HomeFeature 사진 미리 받기")
struct HomePrefetchTests {

    private nonisolated static let cards = [RoomCard.previewShooting, .previewPrintWaiting, .previewPrinted]

    @Test("인화가 끝났고 안내를 아직 안 본 방만 미리 받는다")
    func prefetchesOnlyUnseenPrintedRoom() async {
        let prefetched = LockIsolated<[Room.ID]>([])
        let store = TestStore(initialState: HomeFeature.State(nickname: "찰나")) {
            HomeFeature()
        } withDependencies: {
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { Self.cards })
            $0.shouldShowPrintNoticeUseCase.run = { _ in true }
            $0.prefetchRoomPhotosUseCase.run = { roomID in prefetched.withValue { $0.append(roomID) } }
            $0.continuousClock = TestClock()
            $0.date = .constant(Date(timeIntervalSince1970: 1_790_000_000))
        }
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        // 촬영 중·인화 대기 방은 안내가 뜨지 않으므로 받지 않는다.
        #expect(prefetched.value == [RoomCard.previewPrinted.id])
    }

    @Test("이미 안내를 본 방은 받지 않는다 — 들어가도 필름이 뜨지 않는다")
    func skipsSeenRoom() async {
        let prefetched = LockIsolated(false)
        let store = TestStore(initialState: HomeFeature.State(nickname: "찰나")) {
            HomeFeature()
        } withDependencies: {
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { Self.cards })
            $0.shouldShowPrintNoticeUseCase.run = { _ in false }
            $0.prefetchRoomPhotosUseCase.run = { _ in prefetched.setValue(true) }
            $0.continuousClock = TestClock()
            $0.date = .constant(Date(timeIntervalSince1970: 1_790_000_000))
        }
        store.exhaustivity = .off

        await store.send(.view(.task))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(!prefetched.value)
    }
}
