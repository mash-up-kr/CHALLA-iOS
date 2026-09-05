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
