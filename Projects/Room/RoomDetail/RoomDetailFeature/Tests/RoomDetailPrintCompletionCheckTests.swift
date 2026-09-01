@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 인화 완료 확인 기록 — 인화 완료 방의 상세 응답이 확인(check)을 한 번만 서버에 보내는지 본다.
/// 상세·사진 조회 자체는 `RoomDetailFeatureTests`가 본다.
@MainActor
@Suite("RoomDetailFeature 인화 완료 확인 기록")
struct RoomDetailPrintCompletionCheckTests {

    private nonisolated static let printedDetail = RoomDetail(
        room: .previewPrinted,
        invitationCode: "1928121",
        members: []
    )

    private nonisolated static let shootingDetail = RoomDetail(
        room: .previewShooting,
        invitationCode: "1928121",
        members: []
    )

    private static func makeStore(
        room: Room,
        detail: RoomDetail,
        check: CheckPrintCompletionUseCase = .testValue // 기본값이 미구현 — 불리면 안 되는 테스트가 그대로 쓴다
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: RoomDetailFeature.State(room: room)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in detail })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in [] })
            $0.checkPrintCompletionUseCase = check
            $0.continuousClock = TestClock()
            // 인화 완료 알람의 남은 시간 계산이 쓴다 — 고정해야 테스트가 결정적이다.
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
    }

    @Test("인화 완료 방의 상세를 받으면 그 방 id로 확인 기록을 한 번 보낸다")
    func reportsCheckOnceOnPrintedDetail() async {
        let checkedIDs = LockIsolated<[Room.ID]>([])
        let store = Self.makeStore(
            room: .previewPrinted,
            detail: Self.printedDetail,
            check: CheckPrintCompletionUseCase(run: { id in checkedIDs.withValue { $0.append(id) } })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.printedDetail
            $0.hasReportedPrintCompletionCheck = true
        }
        await store.receive(\.photosResponse.success)
        await store.finish()

        #expect(checkedIDs.value == [Room.previewPrinted.id])
    }

    @Test("같은 화면에서 상세 응답이 다시 와도 확인 기록을 또 보내지 않는다")
    func doesNotReportTwiceOnRefetch() async {
        let checkedIDs = LockIsolated<[Room.ID]>([])
        let store = Self.makeStore(
            room: .previewPrinted,
            detail: Self.printedDetail,
            check: CheckPrintCompletionUseCase(run: { id in checkedIDs.withValue { $0.append(id) } })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.printedDetail
            $0.hasReportedPrintCompletionCheck = true
        }
        await store.receive(\.photosResponse.success)

        // 재시도·재진입과 같은 경로 — 조회는 다시 돌지만 기록 플래그가 남아 있다.
        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
        }
        await store.receive(\.photosResponse.success)
        await store.finish()

        #expect(checkedIDs.value == [Room.previewPrinted.id])
    }

    @Test("인화 완료가 아닌 방은 확인 기록을 보내지 않는다")
    func skipsCheckForNonPrintedRoom() async {
        // check가 testValue — 호출되면 미구현 실패로 걸린다.
        let store = Self.makeStore(room: .previewShooting, detail: Self.shootingDetail)

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.shootingDetail
        }
        await store.receive(\.photosResponse.success)
        await store.finish()
    }

    @Test("확인 기록이 실패해도 얼럿 없이 조용히 넘어간다")
    func checkFailureIsSilent() async {
        let store = Self.makeStore(
            room: .previewPrinted,
            detail: Self.printedDetail,
            check: CheckPrintCompletionUseCase(run: { _ in throw RoomError.network })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.printedDetail
            $0.hasReportedPrintCompletionCheck = true
        }
        await store.receive(\.photosResponse.success)
        // 실패 액션도 얼럿도 없어야 한다 — 남은 이펙트가 있으면 finish가 걸어낸다.
        await store.finish()
    }
}
