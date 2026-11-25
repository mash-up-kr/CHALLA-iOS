@testable import CHALLAApp
import CameraFeature
import CameraSession
import ComposableArchitecture
import Foundation
import HomeFeature
import PhotoDomain
import RoomDetailFeature
import RoomDomain
import ShootEntry
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum CameraFixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let card = RoomCard.previewShooting
    static let otherCard = RoomCard.previewPrinted

    /// 선택 방을 목록 첫 줄이 아닌 방으로 둔다 — 첫 방으로 떨어지는 기본값과 구분하려는 것.
    static let shootableRooms = [
        ShootableRoom(id: 99, title: "강릉 여행", remainedPhotoCount: 3, totalPhotoCount: 24),
        ShootableRoom(id: card.id, title: card.room.title, remainedPhotoCount: 6, totalPhotoCount: 24)
    ]
    static let entry = CameraEntry(roomID: card.id, rooms: shootableRooms, filters: CameraFilter.previewFilters)

    static let camera = LiveCameraFeature.State(
        camera: CameraFeature.State(
            rooms: IdentifiedArray(uniqueElements: shootableRooms),
            filters: IdentifiedArray(uniqueElements: CameraFilter.previewFilters),
            selectedRoomID: card.id
        )
    )
}

extension CameraFixture {

    /// 방 상세 재조회는 `CancellationError`로 응답 없이 끝낸다 — 응답 처리는 RoomDetailFeature 테스트의 몫.
    @MainActor
    static func store(initialState: MainFeature.State) -> TestStoreOf<MainFeature> {
        TestStore(initialState: initialState) {
            MainFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.fetchRoomsUseCase = FetchRoomsUseCase(run: { [CameraFixture.card] })
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in throw CancellationError() })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in throw CancellationError() })
        }
    }

    static func homeState(
        cards: IdentifiedArrayOf<RoomCard> = [CameraFixture.card],
        cameraPresented: Bool = false
    ) -> MainFeature.State {
        var state = MainFeature.State(profile: CameraFixture.profile, cards: cards)
        if cameraPresented {
            state.camera = CameraFixture.camera
        }
        return state
    }

    /// 홈 위에 `room`의 상세가 한 장 쌓인 상태 (원소 id 0).
    static func roomDetailState(
        room: Room = CameraFixture.card.room,
        cards: IdentifiedArrayOf<RoomCard> = [CameraFixture.card],
        cameraPresented: Bool = false
    ) -> MainFeature.State {
        var state = CameraFixture.homeState(cards: cards, cameraPresented: cameraPresented)
        state.path.append(.roomDetail(RoomDetailFeature.State(room: room)))
        return state
    }
}

/// 자식의 `ViewAction`에는 `@CasePathable`이 없어 키패스 대신 패턴으로 고른다.
private func isHomeTask(_ action: MainFeature.Action) -> Bool {
    if case .home(.view(.task)) = action {
        return true
    }
    return false
}

private func isRoomDetailTask(id: StackElementID) -> (MainFeature.Action) -> Bool {
    { action in
        guard case let .path(.element(id: elementID, action: .roomDetail(.view(.task)))) = action else { return false }
        return elementID == id
    }
}

/// 카메라는 스택 밖에서 덮는 화면(`@Presents`) — 닫히면 열었던 화면이 그대로 드러나고 다시 조회한다.
///
/// fullScreenCover는 아래 뷰의 `.task`를 다시 돌리지 않으므로 리듀서가 대신 보내는 `.view(.task)`를 `receive`로 확인한다.
@MainActor
@Suite("MainFeature — 카메라 열기·닫기")
struct MainCameraTests {

    private static let closeRequested = MainFeature.Action.camera(.presented(.camera(.delegate(.closeRequested))))

    private static func captureFinished(_ roomID: Room.ID) -> MainFeature.Action {
        .camera(.presented(.camera(.delegate(.captureFinished(roomID: roomID)))))
    }

    // MARK: - 열기

    @Test("홈에서 촬영 준비가 끝나면 진입 재료의 방·필터·선택 방으로 카메라를 띄운다 — 스택은 그대로")
    func opensCameraFromHome() async {
        let store = CameraFixture.store(initialState: CameraFixture.homeState())

        await store.send(.home(.delegate(.cameraRequested(CameraFixture.entry)))) {
            $0.camera = CameraFixture.camera
        }
        #expect(store.state.camera?.camera.selectedRoomID == CameraFixture.card.id)
    }

    @Test("방 상세에서 촬영 준비가 끝나면 카메라를 띄우고 방 상세는 스택에 남는다")
    func opensCameraFromRoomDetail() async throws {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState())
        let detailID = try #require(store.state.path.ids.first)

        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.cameraRequested(CameraFixture.entry)))))) {
            $0.camera = CameraFixture.camera
        }
        #expect(store.state.path.ids == [detailID])
    }

    /// 다른 진입 재료로 덮어쓰면 찍고 있던 방·필터 선택이 사라진다.
    @Test("카메라가 이미 떠 있으면 홈·방 상세의 촬영 요청을 무시한다")
    func ignoresCameraRequestWhilePresented() async throws {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(cameraPresented: true))
        let detailID = try #require(store.state.path.ids.first)
        let otherEntry = CameraEntry(
            roomID: CameraFixture.otherCard.id,
            rooms: [ShootableRoom(id: CameraFixture.otherCard.id, title: "다른 방", remainedPhotoCount: 1, totalPhotoCount: 24)],
            filters: []
        )

        await store.send(.home(.delegate(.cameraRequested(otherEntry))))
        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.cameraRequested(otherEntry))))))
    }

    // MARK: - 닫기

    @Test("홈에서 연 카메라를 닫으면 카메라만 걷히고 홈이 목록을 다시 조회한다")
    func closeRefreshesHome() async {
        let store = CameraFixture.store(initialState: CameraFixture.homeState(cameraPresented: true))

        await store.send(Self.closeRequested) {
            $0.camera = nil
        }
        await store.receive(isHomeTask) {
            $0.home.loadState = .loading
        }
        await store.receive(\.home.roomsResponse) {
            $0.home.loadState = .loaded
        }
    }

    @Test("방 상세에서 연 카메라를 닫으면 그 방 상세가 그대로 남아 다시 조회한다")
    func closeRefreshesRoomDetail() async throws {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(cameraPresented: true))
        let detailID = try #require(store.state.path.ids.first)

        await store.send(Self.closeRequested) {
            $0.camera = nil
        }
        await store.receive(isRoomDetailTask(id: detailID)) {
            $0.path[id: detailID, case: \.roomDetail]?.detailLoad = .loading
            $0.path[id: detailID, case: \.roomDetail]?.photosLoad = .loading
        }
    }

    // MARK: - 촬영 완료

    @Test("맨 위가 찍은 방의 상세면 그 화면을 유지한 채 방금 올린 사진을 강조하고 다시 조회한다")
    func captureOnSameRoomDetailHighlightsInPlace() async throws {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(cameraPresented: true))
        let detailID = try #require(store.state.path.ids.first)

        await store.send(Self.captureFinished(CameraFixture.card.id)) {
            $0.camera = nil
            $0.path[id: detailID, case: \.roomDetail]?.highlightsNewestPhoto = true
        }
        await store.receive(isRoomDetailTask(id: detailID)) {
            $0.path[id: detailID, case: \.roomDetail]?.detailLoad = .loading
            $0.path[id: detailID, case: \.roomDetail]?.photosLoad = .loading
        }
        #expect(store.state.path.ids == [detailID])
    }

    /// 새로 쌓은 상세는 뷰의 `.task`가 처음 조회하므로 리듀서가 조회를 보내지 않는다.
    @Test("홈에서 연 카메라로 찍으면 홈 카드에서 방을 찾아 사진을 강조할 방 상세를 쌓는다")
    func captureFromHomePushesHighlightedRoomDetail() async {
        let store = CameraFixture.store(initialState: CameraFixture.homeState(cameraPresented: true))

        await store.send(Self.captureFinished(CameraFixture.card.id)) {
            $0.camera = nil
            $0.path[id: 0] = .roomDetail(RoomDetailFeature.State(room: CameraFixture.card.room, highlightsNewestPhoto: true))
        }
    }

    /// 홈에서 촬영 준비 중 다른 방 상세로 들어간 뒤 카메라가 뜬 경우. 스택의 방 상세는 한 장뿐이라는 전제를 지키려고 쌓지 않고 바꾼다.
    @Test("다른 방의 상세 위에서 열고 다른 방을 찍으면 스택이 찍은 방 상세 한 장으로 바뀐다")
    func captureOnOtherRoomReplacesStack() async {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(
            room: CameraFixture.otherCard.room,
            cards: [CameraFixture.card, CameraFixture.otherCard],
            cameraPresented: true
        ))
        let newID: StackElementID = 1 // 초기 append가 0을 썼으니 다음 번호

        await store.send(Self.captureFinished(CameraFixture.card.id)) {
            $0.camera = nil
            $0.path.removeAll()
            $0.path[id: newID] = .roomDetail(RoomDetailFeature.State(room: CameraFixture.card.room, highlightsNewestPhoto: true))
        }
    }

    @Test("찍은 방이 홈 카드에 없으면 닫기와 같이 홈을 다시 조회한다")
    func captureOnUnknownRoomRefreshesHome() async {
        let store = CameraFixture.store(initialState: CameraFixture.homeState(cards: [], cameraPresented: true))

        await store.send(Self.captureFinished(CameraFixture.card.id)) {
            $0.camera = nil
        }
        await store.receive(isHomeTask) {
            $0.home.loadState = .loading
        }
        await store.receive(\.home.roomsResponse) {
            $0.home.loadState = .loaded
            $0.home.cards = [CameraFixture.card]
        }
        #expect(store.state.path.isEmpty)
    }

    @Test("다른 방 상세 위에서 홈 카드에 없는 방을 찍으면 스택을 그대로 두고 그 방 상세를 다시 조회한다")
    func captureOnUnknownRoomRefreshesRoomDetail() async throws {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(
            room: CameraFixture.otherCard.room,
            cards: [],
            cameraPresented: true
        ))
        let detailID = try #require(store.state.path.ids.first)

        await store.send(Self.captureFinished(CameraFixture.card.id)) {
            $0.camera = nil
        }
        await store.receive(isRoomDetailTask(id: detailID)) {
            $0.path[id: detailID, case: \.roomDetail]?.detailLoad = .loading
            $0.path[id: detailID, case: \.roomDetail]?.photosLoad = .loading
        }
    }

    // MARK: - 카메라가 떠 있을 때 밖에서 온 요청

    @Test("카메라가 떠 있으면 참여 토스트의 방 열기를 무시한다 — 스택·카메라 그대로")
    func ignoresRoomOpenWhileCameraPresented() async {
        let store = CameraFixture.store(initialState: CameraFixture.roomDetailState(cameraPresented: true))

        await store.send(.roomOpenRequested(CameraFixture.otherCard.room))
    }

    /// 초대 링크 입장은 홈이 잇는다 — 카메라가 덮고 있으면 입장 결과(방 상세)가 카메라 아래에 숨는다.
    @Test("카메라가 떠 있을 때 초대 코드가 오면 카메라를 닫고 홈이 입장해 그 방 상세를 쌓는다")
    func inviteCodeDismissesCamera() async {
        let codes = LockIsolated<[String]>([])
        let store = CameraFixture.store(initialState: CameraFixture.homeState(cameraPresented: true))
        store.dependencies.joinRoomUseCase = JoinRoomUseCase(run: { code in
            codes.withValue { $0.append(code) }
            return CameraFixture.otherCard
        })

        await store.send(.home(.inviteCodeReceived("ABC123"))) {
            $0.camera = nil
        }
        await store.receive(\.home.inviteJoinResponse) {
            $0.home.cards.insert(CameraFixture.otherCard, at: 0)
        }
        await store.receive(\.home.delegate.roomJoined) {
            $0.path[id: 0] = .roomDetail(RoomDetailFeature.State(room: CameraFixture.otherCard.room))
        }
        #expect(codes.value == ["ABC123"])
    }
}
