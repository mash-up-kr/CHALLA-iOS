@testable import HomeFeature
import ComposableArchitecture
import Foundation
import RoomDomain
import Testing

/// 인화 완료 예정 시각에 거는 알람 — 그 시각이 되면 목록을 다시 받아 상태 전이를 반영한다.
/// 카운트다운 표기 자체는 `RoomDomain`의 `PrintCountdown` 테스트가 본다.
@MainActor
@Suite("HomeFeature 인화 완료 알람")
struct HomeAlarmTests {

    /// 고정 시각 기준 100초 뒤에 인화가 끝나는 대기 방과, 서버가 전환을 끝낸 뒤의 같은 방.
    ///
    /// 스위트가 @MainActor라 static도 메인 액터에 묶이는데, 이 값은 UseCase의 @Sendable
    /// 클로저 안에서 읽힌다. 값 타입 상수라 격리가 필요 없어 nonisolated로 푼다.
    private nonisolated static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private nonisolated static let waitingSoon = RoomCard(
        room: Room(
            id: -50,
            title: "알람 검증 방",
            status: .printWaiting,
            totalPhotoCount: 24,
            remainedPhotoCount: 0,
            createdAt: now.addingTimeInterval(-3600),
            expiresAt: now.addingTimeInterval(Room.previewLifetime),
            photoPrintCompletedAt: now.addingTimeInterval(100)
        ),
        memberCount: 1,
        thumbnailURLs: []
    )

    private nonisolated static let printedAfterAlarm = RoomCard(
        room: Room(
            id: -50,
            title: "알람 검증 방",
            status: .printed,
            totalPhotoCount: 24,
            remainedPhotoCount: 0,
            createdAt: now.addingTimeInterval(-3600),
            expiresAt: now.addingTimeInterval(Room.previewLifetime),
            photoPrintCompletedAt: now.addingTimeInterval(100)
        ),
        memberCount: 1,
        thumbnailURLs: []
    )

    private static func makeStore(
        fetchRooms: FetchRoomsUseCase,
        clock: any Clock<Duration>
    ) -> TestStoreOf<HomeFeature> {
        TestStore(initialState: HomeFeature.State(nickname: "찰나")) {
            HomeFeature()
        } withDependencies: {
            $0.fetchRoomsUseCase = fetchRooms
            $0.continuousClock = clock
            // 알람을 걸지 말지는 "지금이 완료 시각 전인가"로 갈린다. 실제 시각을 읽으면 돌릴 때마다
            // 결과가 달라지므로 픽스처의 기준 시각으로 고정한다.
            $0.date = .constant(now)
        }
    }

    @Test("인화 완료 예정 시각에 도달하면 재조회하고, 서버가 전환을 끝냈으면 인화 완료로 바뀐다")
    func refetchesWhenPrintCompletionReached() async {
        let clock = TestClock()
        // 첫 조회는 인화 대기, 재조회는 인화 완료 — 알람이 울리는 사이 서버가 전환을 끝낸 상황.
        let callCount = LockIsolated(0)
        let store = Self.makeStore(
            fetchRooms: FetchRoomsUseCase(run: {
                callCount.withValue { $0 += 1 }
                return callCount.value == 1 ? [Self.waitingSoon] : [Self.printedAfterAlarm]
            }),
            clock: clock
        )

        await store.send(.view(.task)) {
            $0.loadState = .loading
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.cards = IdentifiedArray(uniqueElements: [Self.waitingSoon]) // 이 응답이 100초 뒤 알람을 건다
        }

        await clock.advance(by: .seconds(100)) // 완료 예정 시각 도달
        await store.receive(\.printCompletionReached) {
            $0.loadState = .loading // 알람이 깨어나 재조회를 시작한다
        }
        await store.receive(\.roomsResponse.success) {
            $0.loadState = .loaded
            $0.cards = IdentifiedArray(uniqueElements: [Self.printedAfterAlarm]) // 완료 — 알람은 다시 걸리지 않는다
        }
    }
}
