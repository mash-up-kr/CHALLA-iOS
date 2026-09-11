@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 인화가 끝난 방에 처음 들어왔을 때 한 번만 뜨는 안내(필름 화면)의 노출·기록 규칙.
/// 필름을 당기는 동작 자체는 `PrintNoticeView`가 맡고, 리듀서는 "띄울지"와 "봤다고 기록할지"만 본다.
@MainActor
@Suite("RoomDetailFeature 인화 완료 안내")
struct RoomDetailPrintNoticeTests {

    /// 인화가 끝난 방. 완료 예정 시각은 과거라 카운트다운 알람이 걸리지 않는다.
    private nonisolated static let printedRoom = Room(
        id: Room.previewShooting.id,
        title: Room.previewShooting.title,
        status: .printed,
        totalPhotoCount: 24,
        remainedPhotoCount: 0,
        createdAt: Room.previewShooting.createdAt,
        expiresAt: Room.previewShooting.expiresAt,
        photoPrintCompletedAt: Date(timeIntervalSince1970: 100)
    )

    private nonisolated static let photos = [
        Photo(
            id: "1",
            imageURL: URL(string: "https://img.example.com/1.jpg")!,
            author: PhotoAuthor(id: "u1", nickname: "찰나둥이"),
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    ]

    private static func makeStore(
        initialState: RoomDetailFeature.State,
        fetchDetail: FetchRoomDetailUseCase,
        fetchPhotos: FetchRoomPhotosUseCase,
        shouldShowPrintNotice: ShouldShowPrintNoticeUseCase,
        markPrintNoticeSeen: MarkPrintNoticeSeenUseCase = .init(run: { _ in })
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(initialState: initialState) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = fetchDetail
            $0.fetchRoomPhotosUseCase = fetchPhotos
            $0.shouldShowPrintNoticeUseCase = shouldShowPrintNotice
            $0.markPrintNoticeSeenUseCase = markPrintNoticeSeen
            // 상세 성공은 초대 안내 확인까지 부른다 — 띄우지 않는 답을 고정해 팝오버가 끼어들지 않게 한다.
            $0.shouldShowInviteGuideUseCase.run = { false }
            // 인화 완료 방에 들어오면 리듀서가 서버에 확인을 알린다 — 이 묶음의 관심사가 아니라 비워 둔다.
            $0.checkPrintCompletionUseCase = CheckPrintCompletionUseCase(run: { _ in })
            $0.continuousClock = TestClock()
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
    }

    private nonisolated static let printedDetail = RoomDetail(
        room: printedRoom,
        invitationCode: "1928121",
        members: []
    )

    /// 상세와 사진 중 어느 응답이 먼저 오는지는 이펙트가 끝나는 순서에 달려 있고, 안내는 그 순서와 무관하게
    /// 동작해야 한다. 그래서 이 묶음은 액션 순서를 따지지 않고(`exhaustivity = .off`) 조회가 끝난 뒤의 상태를 본다.
    private static func makePrintedStore(
        shouldShow: Bool,
        photos: [Photo] = RoomDetailPrintNoticeTests.photos,
        fetchDetail: FetchRoomDetailUseCase = .init(run: { _ in RoomDetailPrintNoticeTests.printedDetail }),
        markSeen: MarkPrintNoticeSeenUseCase = .init(run: { _ in })
    ) -> TestStoreOf<RoomDetailFeature> {
        let store = makeStore(
            initialState: .init(room: printedRoom),
            fetchDetail: fetchDetail,
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in photos }),
            shouldShowPrintNotice: ShouldShowPrintNoticeUseCase(run: { _ in shouldShow }),
            markPrintNoticeSeen: markSeen
        )
        store.exhaustivity = .off
        return store
    }

    /// 진입 조회와 그 뒤에 이어지는 안내 확인까지 모두 흘려보낸다.
    /// 받은 액션은 `receive` 전까지 상태에 반영되지 않으므로, 처리 → 이펙트 대기 → 처리 순으로 두 번 비운다.
    private static func drain(_ store: TestStoreOf<RoomDetailFeature>) async {
        await store.skipReceivedActions(strict: false)
        await store.finish()
        await store.skipReceivedActions(strict: false)
    }

    @Test("인화 완료 방에 처음 들어오면 안내를 띄운다")
    func showsPrintNoticeOnFirstVisit() async {
        let store = Self.makePrintedStore(shouldShow: true)

        await store.send(.view(.task))
        await Self.drain(store)

        #expect(store.state.isPrintNoticePresented)
    }

    @Test("이미 안내를 본 방이면 띄우지 않는다")
    func skipsPrintNoticeWhenAlreadySeen() async {
        let store = Self.makePrintedStore(shouldShow: false)

        await store.send(.view(.task))
        await Self.drain(store)

        #expect(store.state.didCheckPrintNotice) // 물어보긴 했다
        #expect(!store.state.isPrintNoticePresented)
    }

    @Test("사진이 없으면 안내를 확인조차 하지 않는다 — 빈 필름을 띄우지 않는다")
    func doesNotShowPrintNoticeWithoutPhotos() async {
        let store = Self.makePrintedStore(shouldShow: true, photos: [])

        await store.send(.view(.task))
        await Self.drain(store)

        #expect(!store.state.didCheckPrintNotice)
        #expect(!store.state.isPrintNoticePresented)
    }

    @Test("상세 조회가 실패해도 사진만 있으면 안내를 띄운다")
    func showsPrintNoticeWhenOnlyDetailFails() async {
        let store = Self.makePrintedStore(
            shouldShow: true,
            fetchDetail: FetchRoomDetailUseCase(run: { _ in throw RoomError.network })
        )

        await store.send(.view(.task))
        await Self.drain(store)

        #expect(store.state.isPrintNoticePresented)
    }

    @Test("필름이 다 내려가면 봤다고 기록하고 그리드로 돌아간다")
    func dismissingPrintNoticeMarksSeen() async {
        let markedRoomID = LockIsolated<Room.ID?>(nil)
        let store = Self.makePrintedStore(
            shouldShow: true,
            markSeen: MarkPrintNoticeSeenUseCase(run: { markedRoomID.setValue($0) })
        )

        await store.send(.view(.task))
        await Self.drain(store)
        #expect(store.state.isPrintNoticePresented)

        await store.send(.view(.printNoticeDismissed)) {
            $0.isPrintNoticePresented = false
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(markedRoomID.value == Self.printedRoom.id)
    }

    @Test("사진을 못 받아 안내를 접으면 봤다고 기록하지 않는다 — 다음 진입에 다시 시도한다")
    func skippingPrintNoticeDoesNotMarkSeen() async {
        let markedRoomID = LockIsolated<Room.ID?>(nil)
        let store = Self.makePrintedStore(
            shouldShow: true,
            markSeen: MarkPrintNoticeSeenUseCase(run: { markedRoomID.setValue($0) })
        )

        await store.send(.view(.task))
        await Self.drain(store)
        #expect(store.state.isPrintNoticePresented)

        await store.send(.view(.printNoticeSkipped)) {
            $0.isPrintNoticePresented = false
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(markedRoomID.value == nil)
    }

    @Test("안내를 한 번 닫으면 뒤늦게 도착한 응답이 다시 띄우지 않는다")
    func doesNotReshowPrintNoticeAfterDismiss() async {
        let store = Self.makePrintedStore(shouldShow: true)

        await store.send(.view(.task))
        await Self.drain(store)
        await store.send(.view(.printNoticeDismissed))
        await store.finish()

        // 화면에 머무는 동안 다시 조회가 돌아도(얼럿의 다시 시도 등) 안내는 다시 뜨지 않는다.
        await store.send(.view(.task))
        await Self.drain(store)

        #expect(!store.state.isPrintNoticePresented)
    }

    // MARK: - 필름 당기기

    @Test("내려가던 필름을 중간에 잡으면 지난 시간에 비례한 자리에 선다")
    func catchesRunningFilmAtElapsedPosition() {
        // 1초 동안 100 → 1,100(=1,000pt)을 내려가는 움직임.
        let start = Date(timeIntervalSince1970: 0)
        let run = RunInFlight(startedAt: start, from: 100, to: 1100, duration: 1)

        // 절반이 지났으면 절반만큼 내려와 있다.
        #expect(run.position(at: start.addingTimeInterval(0.5)) == 600)
        // 시작 전과 끝난 뒤는 양 끝값으로 자른다 — 잡는 순간이 어긋나도 필름이 튀지 않는다.
        #expect(run.position(at: start) == 100)
        #expect(run.position(at: start.addingTimeInterval(5)) == 1100)
    }

    // MARK: - 당기기를 여는 시점

    /// 72장 방의 기준 — 실제로 쓰는 값과 같게 맞춘다.
    /// 상수가 바뀌어도 규칙만 따로 보면 테스트가 통과해버린다.
    private static let gate = PrintNoticePullGate(
        minReadyFrames: 4,
        safetyWindow: PrintNoticeMetric.runDuration(frameCount: 72)
    )

    @Test("앞 칸이 덜 찼으면 열지 않는다 — 멈춰 있는 동안 검은 칸이 보인다")
    func staysClosedUntilFirstFramesArrive() {
        #expect(!Self.gate.isOpen(total: 72, leadingReady: 3, loaded: 3, elapsed: 0.05))
    }

    @Test("뒤쪽이 먼저 도착해도 앞 칸이 비어 있으면 열지 않는다")
    func staysClosedWhenLeadingFramesAreMissing() {
        // 30장을 받았지만 앞에서 이어진 것은 2장뿐 — 필름이 시작하자마자 빈 자리를 만난다.
        #expect(!Self.gate.isOpen(total: 72, leadingReady: 2, loaded: 30, elapsed: 0.5))
    }

    @Test("다 받았으면 남은 장이 없으므로 연다")
    func opensWhenEverythingLoaded() {
        #expect(Self.gate.isOpen(total: 24, leadingReady: 24, loaded: 24, elapsed: 1))
    }

    @Test("방이 앞 칸 수보다 작으면 전부 받아야 연다")
    func waitsForAllInTinyRoom() {
        #expect(!Self.gate.isOpen(total: 2, leadingReady: 1, loaded: 1, elapsed: 1))
        #expect(Self.gate.isOpen(total: 2, leadingReady: 2, loaded: 2, elapsed: 1))
    }

    @Test("빠르게 들어오면 남은 장이 많아도 연다 — 필름이 닿기 전에 도착한다")
    func opensWhileLoadingWhenFastEnough() {
        // 0.4초에 20장 = 장당 0.02초. 남은 52장은 1.04초면 들어온다 (필름은 4초).
        #expect(Self.gate.isOpen(total: 72, leadingReady: 20, loaded: 20, elapsed: 0.4))
    }

    @Test("느리게 들어오면 열지 않는다 — 필름이 사진을 앞지른다")
    func staysClosedWhenTooSlow() {
        // 2초에 5장 = 장당 0.4초. 남은 67장에 26초가 걸린다.
        #expect(!Self.gate.isOpen(total: 72, leadingReady: 5, loaded: 5, elapsed: 2))
    }

    @Test("시간이 흐르지 않았으면 속도를 알 수 없어 열지 않는다")
    func staysClosedWithoutElapsedTime() {
        #expect(!Self.gate.isOpen(total: 72, leadingReady: 10, loaded: 10, elapsed: 0))
    }

    @Test("사진이 적은 방은 필름도 짧아 기준이 함께 좁아진다")
    func usesShorterWindowForShortFilm() {
        // 6장 필름은 0.6초면 다 지나간다. 같은 속도라도 72장 기준으로는 열리고 6장 기준으로는 닫혀야 한다.
        let short = PrintNoticePullGate(
            minReadyFrames: 4,
            safetyWindow: PrintNoticeMetric.runDuration(frameCount: 6)
        )
        #expect(PrintNoticeMetric.runDuration(frameCount: 6) == PrintNoticeMetric.minRunDuration)
        // 1초에 4장 = 장당 0.25초. 남은 2장에 0.5초 — 0.6초 안에 들어오므로 열린다.
        #expect(short.isOpen(total: 6, leadingReady: 4, loaded: 4, elapsed: 1))
        // 2초에 4장 = 장당 0.5초. 남은 2장에 1초 — 0.6초를 넘겨 닫힌다.
        #expect(!short.isOpen(total: 6, leadingReady: 4, loaded: 4, elapsed: 2))
    }

    @Test("촬영 중인 방에서는 안내를 확인하지 않는다")
    func doesNotCheckPrintNoticeWhileShooting() async {
        let shootingRoom = Room.previewShooting
        let store = Self.makeStore(
            initialState: .init(room: shootingRoom),
            fetchDetail: FetchRoomDetailUseCase(run: { _ in
                RoomDetail(room: shootingRoom, invitationCode: "1928121", members: [])
            }),
            fetchPhotos: FetchRoomPhotosUseCase(run: { _ in Self.photos }),
            // 물어보면 실패하는 UseCase — 확인 자체가 없어야 통과한다.
            shouldShowPrintNotice: ShouldShowPrintNoticeUseCase(run: { _ in
                Issue.record("촬영 중인 방에서 안내 노출 여부를 물었다")
                return false
            })
        )
        store.exhaustivity = .off

        await store.send(.view(.task))
        await Self.drain(store)

        #expect(!store.state.didCheckPrintNotice)
    }
}
