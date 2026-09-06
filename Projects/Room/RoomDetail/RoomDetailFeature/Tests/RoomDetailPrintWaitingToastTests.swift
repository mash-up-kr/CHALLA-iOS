@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 인화 대기 안내 — 인화가 아직 안 끝난 방에 들어갈 때마다 상단 토스트로 알리는지 본다.
/// 남은 시간 카운트다운과 인화 완료 전환은 `RoomDetailFeatureTests`가 본다.
@MainActor
@Suite("RoomDetailFeature 인화 대기 안내")
struct RoomDetailPrintWaitingToastTests {

    private nonisolated static let message = "인화 대기 중이에요! 조금만 기다려주세요"

    /// 완료 예정까지 100초 남은 인화 대기 방 (makeStore의 현재 시각 0 기준).
    private nonisolated static let waitingRoom = Room(
        id: Room.previewShooting.id,
        title: Room.previewShooting.title,
        status: .printWaiting,
        totalPhotoCount: 24,
        remainedPhotoCount: 0,
        createdAt: Room.previewShooting.createdAt,
        expiresAt: Room.previewShooting.expiresAt,
        photoPrintCompletedAt: Date(timeIntervalSince1970: 100)
    )

    private static func makeStore(
        room: Room,
        detail: RoomDetail,
        clock: any Clock<Duration>
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: RoomDetailFeature.State(room: room)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in detail })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in [] })
            $0.checkPrintCompletionUseCase = CheckPrintCompletionUseCase(run: { _ in })
            $0.continuousClock = clock
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
    }

    @Test("인화 대기 방에 들어가면 안내 토스트를 띄웠다가 2초 뒤 거둔다")
    func showsToastOnEnter() async {
        let clock = TestClock()
        let detail = RoomDetail(room: Self.waitingRoom, invitationCode: "1928121", members: [])
        let store = Self.makeStore(room: Self.waitingRoom, detail: detail, clock: clock)

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
            $0.photosLoad = .loading
            $0.toast = RoomDetailFeature.Toast(Self.message, placement: .top)
            $0.didShowPrintWaitingToast = true
        }
        await store.receive(\.photosResponse.success) { $0.photosLoad = .loaded }
        // 상세 응답도 같은 인화 대기 방이지만, 이미 띄웠으므로 다시 뜨지 않는다.
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = detail
        }

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) { $0.toast = nil }

        // 상세 응답이 건 인화 완료 알람은 이 테스트의 관심사가 아니다.
        await store.skipInFlightEffects()
    }

    @Test("인화가 끝난 방에서는 안내가 뜨지 않는다")
    func noToastWhenPrinted() async {
        let clock = TestClock()
        let detail = RoomDetail(room: .previewPrinted, invitationCode: "1928121", members: [])
        let store = Self.makeStore(room: .previewPrinted, detail: detail, clock: clock)

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
            $0.photosLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = detail
            $0.hasReportedPrintCompletionCheck = true
        }
        await store.receive(\.photosResponse.success) { $0.photosLoad = .loaded }
    }
}
