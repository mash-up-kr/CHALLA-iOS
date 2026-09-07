@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 첫 진입 안내(팝오버 자동 열림 + 툴팁)와 인화 대기 토스트 —
/// 진입 조회 자체는 `RoomDetailFeatureTests`가 본다.
@MainActor
@Suite("RoomDetailFeature 진입 안내")
struct RoomDetailInviteGuideTests {

    private nonisolated static let detail = RoomDetail(
        room: .previewShooting,
        invitationCode: "1928121",
        members: RoomDetail.preview.members
    )

    private nonisolated static let printWaitingDetail = RoomDetail(
        room: .previewPrintWaiting,
        invitationCode: "1928121",
        members: RoomDetail.preview.members
    )

    private static func makeStore(
        room: Room = .previewShooting,
        detail: RoomDetail = detail,
        shouldShow: @escaping @Sendable () async -> Bool = { false },
        markSeen: MarkInviteGuideSeenUseCase = .testValue // 기본값이 미구현 — 불리면 안 되는 테스트가 그대로 쓴다
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: RoomDetailFeature.State(room: room)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in detail })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in [] })
            $0.shouldShowInviteGuideUseCase.run = shouldShow
            $0.markInviteGuideSeenUseCase = markSeen
            $0.continuousClock = TestClock()
            // 인화 완료 알람의 남은 시간 계산이 쓴다 — 고정해야 테스트가 결정적이다.
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
    }

    @Test("처음 들어온 기기면 첫 상세 성공 뒤에 팝오버가 열리고 툴팁이 붙는다")
    func firstEntryOpensPopoverWithGuide() async {
        let store = Self.makeStore(shouldShow: { true })

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success)
        // 참여자 바가 그려질 수 있는 시점(상세 성공) 뒤에야 안내가 열린다.
        await store.receive(\.inviteGuideNeeded) {
            $0.isInvitePopoverPresented = true
            $0.isInviteGuidePresented = true
        }
    }

    @Test("이미 본 기기면 아무것도 열리지 않는다")
    func seenEntryStaysClosed() async {
        let store = Self.makeStore(shouldShow: { false })

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        // inviteGuideNeeded가 오지 않는다 — 팝오버·툴팁 그대로 닫힘.
        await store.receive(\.photosResponse.success)
    }

    @Test("팝오버를 닫으면 툴팁이 내려가고 본 것으로 기록한다")
    func closingPopoverMarksSeen() async {
        let seenRecorded = LockIsolated(false)
        let store = Self.makeStore(
            shouldShow: { true },
            markSeen: MarkInviteGuideSeenUseCase(run: { seenRecorded.setValue(true) })
        )

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success)
        await store.receive(\.inviteGuideNeeded) {
            $0.isInvitePopoverPresented = true
            $0.isInviteGuidePresented = true
        }

        // 바 재탭·바깥 탭 어느 쪽이든 뷰는 이 binding으로 닫는다.
        await store.send(.binding(.set(\.isInvitePopoverPresented, false))) {
            $0.isInvitePopoverPresented = false
            $0.isInviteGuidePresented = false
        }
        await store.finish()
        #expect(seenRecorded.value)
    }

    @Test("안내 없이 연 팝오버는 닫아도 기록하지 않는다")
    func plainPopoverCloseDoesNotMark() async {
        let store = Self.makeStore() // markSeen이 testValue — 불리면 미구현 실패

        await store.send(.binding(.set(\.isInvitePopoverPresented, true))) {
            $0.isInvitePopoverPresented = true
        }
        await store.send(.binding(.set(\.isInvitePopoverPresented, false))) {
            $0.isInvitePopoverPresented = false
        }
    }

    @Test("상세가 실패하면 안내를 미루고, 다시 시도로 성공했을 때 연다")
    func opensGuideAfterRetrySucceeds() async {
        // 첫 조회는 실패, 다시 시도는 성공 — 실패한 화면 뒤에 열림 상태가 남으면 안 된다.
        let callCount = LockIsolated(0)
        let store = TestStore(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in
                if callCount.withValue({ $0 += 1; return $0 }) == 1 {
                    throw RoomError.network
                }
                return Self.detail
            })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in [] })
            $0.shouldShowInviteGuideUseCase.run = { true }
            $0.continuousClock = TestClock()
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        // 실패 — 얼럿만 뜨고 안내는 확인조차 하지 않는다.
        await store.receive(\.detailResponse.failure) {
            $0.detailLoad = .failed
            $0.alert = AlertState {
                TextState("방 정보를 불러오지 못했어요")
            } actions: {
                ButtonState(action: .retryTapped) { TextState("다시 시도") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.network.userMessage)
            }
        }
        await store.receive(\.photosResponse.success)

        await store.send(.alert(.presented(.retryTapped))) {
            $0.alert = nil
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success)
        await store.receive(\.inviteGuideNeeded) {
            $0.isInvitePopoverPresented = true
            $0.isInviteGuidePresented = true
        }
    }

    @Test("안내 확인은 첫 상세 성공에 한 번뿐이다 — 재조회 성공에 또 확인하지 않는다")
    func checksGuideOnlyOnFirstSuccess() async {
        let store = Self.makeStore(shouldShow: { true })

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success)
        await store.receive(\.inviteGuideNeeded) {
            $0.isInvitePopoverPresented = true
            $0.isInviteGuidePresented = true
        }

        // 카운트다운 알람의 재조회가 같은 상세를 다시 받은 상황 — 확인이 반복되면
        // inviteGuideNeeded가 또 와서 이 테스트가 실패한다.
        await store.send(.printCompletionReached)
        await store.receive(\.detailResponse.success)
        await store.receive(\.photosResponse.success)
    }

    @Test("인화 대기 방이면 토스트가 한 번만 뜬다")
    func printWaitingShowsToastOnce() async {
        let clock = TestClock()
        let store = TestStore(initialState: RoomDetailFeature.State(room: .previewPrintWaiting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in Self.printWaitingDetail })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in [] })
            $0.shouldShowInviteGuideUseCase.run = { false }
            $0.continuousClock = clock
            // 완료 예정 시각(previewPrintWaiting)이 과거가 되도록 잡아 알람 이펙트를 걸지 않는다.
            $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
        }

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.printWaitingDetail
            $0.room = Room.previewPrintWaiting
            $0.hasShownPrintWaitingToast = true
            $0.toast = "인화 대기 중이에요! 조금만 기다려주세요"
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success)

        // 알람 재조회가 같은 대기 응답을 다시 준 상황 — 토스트가 또 뜨지 않는다.
        await store.send(.printCompletionReached)
        await store.receive(\.detailResponse.success)
        await store.receive(\.photosResponse.success)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }
}
