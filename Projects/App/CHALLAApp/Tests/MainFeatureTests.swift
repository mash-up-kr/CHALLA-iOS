@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import HomeFeature
import RoomDetailFeature
import RoomDomain
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum Fixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let card = RoomCard.previewShooting

    static let editedCover = RoomCover(imageURL: URL(string: "https://cdn.example.com/edited.jpg"), sticker: nil)
}

/// 세 묶음이 함께 쓰는 TestStore·초기 State.
extension Fixture {

    @MainActor
    static func store(initialState: MainFeature.State) -> TestStoreOf<MainFeature> {
        TestStore(initialState: initialState) {
            MainFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
        }
    }

    /// 홈 위에 방 상세가 한 장 쌓인 상태.
    static func stateWithRoomDetail(
        _ detail: RoomDetailFeature.State = RoomDetailFeature.State(room: Fixture.card.room),
        cards: IdentifiedArrayOf<RoomCard> = [Fixture.card]
    ) -> MainFeature.State {
        var state = MainFeature.State(profile: Fixture.profile, cards: cards)
        state.path.append(.roomDetail(detail))
        return state
    }

    /// 홈 위에 방 상세(0) → 방 설정(1)이 쌓인 상태. 설정에서 이름을 바꿨다면 `settingsTitle`로 준다.
    static func stateWithRoomSettings(
        detail: RoomDetailFeature.State = RoomDetailFeature.State(room: Fixture.card.room),
        cards: IdentifiedArrayOf<RoomCard> = [Fixture.card],
        settingsTitle: String = Fixture.card.room.title
    ) -> MainFeature.State {
        var state = Fixture.stateWithRoomDetail(detail, cards: cards)
        state.path.append(.roomSettings(RoomSettingsFeature.State(roomID: Fixture.card.room.id, title: settingsTitle)))
        return state
    }

    /// 맨 위 방 설정의 이름 수정 드로어를 열어 둔다 — 이름 저장 액션은 드로어가 열려 있을 때만 온다.
    static func openRenameDrawer(in state: inout MainFeature.State) {
        guard let id = state.path.ids.last, case var .roomSettings(settings) = state.path[id: id] else { return }
        settings.rename = RenameRoomFeature.State(roomID: settings.roomID, title: settings.title)
        state.path[id: id] = .roomSettings(settings)
    }

    /// 홈 위에 방 상세(0) → 방 설정(1) → 커버 수정(2). 커버 수정이 `saved`를 서버에 저장해 둔 상태로 만든다.
    static func stateWithCoverEdit(saved: RoomCover) -> MainFeature.State {
        var state = Fixture.stateWithRoomSettings()
        var edit = RoomCoverEditFeature.State(
            roomID: Fixture.card.room.id, title: Fixture.card.room.title, memberCount: 4, cover: Fixture.card.room.cover
        )
        edit.cover = saved
        edit.savedCover = saved
        state.path.append(.roomCoverEdit(edit))
        return state
    }

    /// 커버 수정에서 `edited`로 바꿨지만 아직 저장하지 않은 상태 (savedCover는 처음 커버).
    static func stateWithUnsavedCoverEdit(edited: RoomCover) -> MainFeature.State {
        var state = Fixture.stateWithRoomSettings()
        var edit = RoomCoverEditFeature.State(
            roomID: Fixture.card.room.id, title: Fixture.card.room.title, memberCount: 4, cover: Fixture.card.room.cover
        )
        edit.cover = edited
        state.path.append(.roomCoverEdit(edit))
        return state
    }

    /// 홈 카드의 방만 바꾼 카드 — 기대값을 적을 때 쓴다.
    static func cardWithCover(_ cover: RoomCover) -> RoomCard {
        RoomCard(
            room: Fixture.card.room.withCover(cover),
            memberCount: Fixture.card.memberCount,
            thumbnailURLs: Fixture.card.thumbnailURLs,
            photoPrintCompletionCheckedAt: Fixture.card.photoPrintCompletionCheckedAt
        )
    }
}

/// 홈 위에 화면을 쌓고 빼는 규칙. 핵심 주장은 하나다 — **뒤로 가도 아래 화면은 그대로다.**
///
/// 스택 원소 id(`StackElementID`)는 테스트용 생성기가 테스트 함수마다 0부터 차례로 발급한다.
/// 손으로 `path[id: 0]`을 넣으면 생성기가 그걸 모르고 같은 id를 다시 발급해 덮어쓴다 —
/// 그래서 초기 State는 `append`로 쌓아 번호를 소비시키고, 리듀서가 새로 쌓을 원소는 그 다음 번호로 기대한다.
@MainActor
@Suite("MainFeature — 홈 위에 쌓고 빼기")
struct MainFeatureTests {

    // MARK: - 홈 → 방 상세

    /// 목록에서 고르든, 방금 만들었든, 초대 코드로 들어왔든 다음 동작은 같다.
    /// `arguments:`로 쪼개지 않는다 — 세 실행이 id 생성기를 공유해 번호 순서가 흔들린다. 한 함수 안에서 차례로 돈다.
    @Test("홈이 알리는 세 경로 모두 그 방의 상세를 홈 위에 쌓는다")
    func pushesRoomDetailFromHome() async {
        let delegates: [HomeFeature.Action.Delegate] = [
            .roomSelected(Fixture.card), .roomCreated(Fixture.card), .roomJoined(Fixture.card)
        ]
        for (index, delegate) in delegates.enumerated() {
            let store = Fixture.store(initialState: MainFeature.State(profile: Fixture.profile, cards: [Fixture.card]))

            await store.send(.home(.delegate(delegate))) {
                $0.path[id: StackElementID(integerLiteral: index)] =
                    .roomDetail(RoomDetailFeature.State(room: Fixture.card.room))
            }
            // 홈은 건드리지 않았다 — 목록이 그대로이고 다시 조회하지도 않는다.
            #expect(store.state.home.cards == [Fixture.card])
        }
    }

    @Test("방 상세에서 뒤로가면 상세만 빠지고 홈은 목록까지 그대로다")
    func popsRoomDetailKeepingHome() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)

        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.closeTapped))))) {
            $0.path.pop(from: detailID)
        }
        #expect(store.state.home.cards == [Fixture.card])
        // 리듀서가 홈 재조회를 걸지 않았다. 실제 앱에선 홈이 다시 보일 때 뷰의 `.task`가 재실행돼 조용히 재조회한다 —
        // 그건 뷰 수명주기라 TestStore 범위 밖이다. 이 테스트가 못 박는 건 "홈 State를 새로 만들지 않는다"이다.
        #expect(store.state.home.loadState == .notRequested)
    }

    /// 버튼 뒤로가기(delegate)와 스와이프 뒤로가기(popFrom)가 같은 결과여야 한다 — 전이를 두 곳에 적지 않는다.
    @Test("스와이프 뒤로가기(popFrom)도 상세만 빠지고 홈은 그대로다")
    func popsRoomDetailBySwipe() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)

        await store.send(.path(.popFrom(id: detailID))) {
            $0.path.pop(from: detailID)
        }
        #expect(store.state.home.cards == [Fixture.card])
    }

    // MARK: - 방 상세 → 사진 상세·채팅

    @Test("채팅 버튼을 누르면 그 방의 채팅을 상세 위에 쌓는다 — 내 id로 내 메시지를 가린다")
    func pushesChatFromRoomDetail() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)
        let chatID: StackElementID = 1 // 초기 append가 0을 썼으니 다음 번호

        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.chatTapped))))) {
            $0.path[id: chatID] = .chat(MainFeature.chatState(room: Fixture.card.room, profile: Fixture.profile))
        }

        guard case let .chat(chat) = store.state.path[id: chatID] else {
            Issue.record("채팅이 쌓이지 않았다")
            return
        }
        #expect(chat.currentUserID == Fixture.profile.id)
        #expect(chat.currentUserNickname == "찰나")
    }

    @Test("슬롯의 사진을 탭하면 그 사진을 펼친 사진 상세를 상세 위에 쌓는다")
    func pushesPhotoDetailFromRoomDetail() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)
        let photoID: StackElementID = 1

        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.photoTapped("photo-1")))))) {
            $0.path[id: photoID] = .photoDetail(
                MainFeature.photoDetailState(room: Fixture.card.room, initialPhotoID: "photo-1", profile: Fixture.profile)
            )
        }

        guard case let .photoDetail(photo) = store.state.path[id: photoID] else {
            Issue.record("사진 상세가 쌓이지 않았다")
            return
        }
        #expect(photo.currentUserID == String(Fixture.profile.id))
    }

    @Test("사진 상세를 닫으면 아래에 있던 방 상세가 조회 결과까지 그대로 남아 있다")
    func popsPhotoDetailKeepingRoomDetail() async throws {
        // 상세 조회가 이미 끝난 방 — 돌아왔을 때 이 값이 살아 있어야 한다.
        var detail = RoomDetailFeature.State(room: Fixture.card.room)
        detail.detail = .preview
        var initial = Fixture.stateWithRoomDetail(detail)
        initial.path.append(.photoDetail(
            MainFeature.photoDetailState(room: Fixture.card.room, initialPhotoID: "photo-1", profile: Fixture.profile)
        ))
        let store = Fixture.store(initialState: initial)
        let detailID = try #require(store.state.path.ids.first)
        let photoID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: photoID, action: .photoDetail(.delegate(.closeRequested))))) {
            $0.path.pop(from: photoID)
        }

        guard case let .roomDetail(remaining) = store.state.path[id: detailID] else {
            Issue.record("방 상세가 남아 있지 않다")
            return
        }
        #expect(remaining.detail == .preview)
    }

    @Test("채팅을 닫으면 방 상세로 돌아간다")
    func popsChatToRoomDetail() async throws {
        var initial = Fixture.stateWithRoomDetail()
        initial.path.append(.chat(MainFeature.chatState(room: Fixture.card.room, profile: Fixture.profile)))
        let store = Fixture.store(initialState: initial)
        let chatID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: chatID, action: .chat(.delegate(.closeRequested))))) {
            $0.path.pop(from: chatID)
        }
        #expect(store.state.path.count == 1)
    }

    // MARK: - 화면 밖에서 방 열기

    @Test("참여 토스트로 방을 열면 쌓인 화면을 비우고 그 방 상세만 쌓는다")
    func opensRoomFromOutsideReplacingStack() async {
        var initial = Fixture.stateWithRoomDetail()
        initial.path.append(.chat(MainFeature.chatState(room: Fixture.card.room, profile: Fixture.profile)))
        let store = Fixture.store(initialState: initial)
        let other = Room.previewPrinted
        let newID: StackElementID = 2 // 초기 append 두 번(0·1) 다음 번호

        await store.send(.roomOpenRequested(other)) {
            $0.path.removeAll()
            $0.path[id: newID] = .roomDetail(RoomDetailFeature.State(room: other))
        }
    }
}

/// 방 상세 위의 방 설정 → 커버 수정. 위에서 바꾼 이름·커버가 스택 아래 방 상세와 홈 카드에 반영되는지 본다.
@MainActor
@Suite("MainFeature — 방 설정·커버 수정")
struct MainFeatureRoomSettingsTests {

    @Test("방 상세에서 설정을 누르면 그 방의 이름으로 방 설정을 쌓는다")
    func pushesRoomSettingsFromRoomDetail() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)

        await store.send(.path(.element(id: detailID, action: .roomDetail(.delegate(.settingsTapped))))) {
            $0.path[id: 1] = .roomSettings(
                RoomSettingsFeature.State(roomID: Fixture.card.room.id, title: Fixture.card.room.title)
            )
        }
    }

    @Test("방 설정에서 이름이 바뀌면 스택 아래 방 상세와 홈 카드의 방 이름이 함께 바뀐다")
    func renamePropagatesToRoomDetailAndHomeCard() async {
        var initial = Fixture.stateWithRoomSettings()
        Fixture.openRenameDrawer(in: &initial)
        let store = Fixture.store(initialState: initial)
        store.exhaustivity = .off // 방 설정 자신의 드로어·이름 행 변화는 RoomSettingsFeature 테스트의 몫
        let ids = Array(store.state.path.ids)

        await store.send(.path(.element(id: ids[1], action: .roomSettings(.rename(.presented(.delegate(.renamed("강릉 여행"))))))))

        guard case let .roomDetail(detail) = store.state.path[id: ids[0]] else {
            Issue.record("방 상세가 없다")
            return
        }
        #expect(detail.room.title == "강릉 여행")
        #expect(store.state.home.cards[id: Fixture.card.id]?.room.title == "강릉 여행")
    }

    @Test("다른 방의 이름 변경은 스택의 방 상세와 홈의 다른 카드를 건드리지 않는다")
    func renameLeavesOtherRoomsAlone() async {
        let other = Room.previewPrinted
        var initial = MainFeature.State(
            profile: Fixture.profile,
            cards: [Fixture.card, RoomCard(room: other, memberCount: 2, thumbnailURLs: [])]
        )
        initial.path.append(.roomDetail(RoomDetailFeature.State(room: Fixture.card.room)))
        initial.path.append(.roomSettings(RoomSettingsFeature.State(roomID: other.id, title: other.title)))
        Fixture.openRenameDrawer(in: &initial)
        let store = Fixture.store(initialState: initial)
        store.exhaustivity = .off
        let ids = Array(store.state.path.ids)

        await store.send(.path(.element(id: ids[1], action: .roomSettings(.rename(.presented(.delegate(.renamed("제주"))))))))

        guard case let .roomDetail(detail) = store.state.path[id: ids[0]] else {
            Issue.record("방 상세가 없다")
            return
        }
        #expect(detail.room.title == Fixture.card.room.title)
        #expect(store.state.home.cards[id: Fixture.card.id]?.room.title == Fixture.card.room.title)
        #expect(store.state.home.cards[id: other.id]?.room.title == "제주")
    }

    @Test("방 설정에서 커버를 누르면 설정의 최신 이름과 방 상세의 커버로 커버 수정을 쌓는다")
    func pushesCoverEditWithLatestTitleAndDetailCover() async throws {
        let store = Fixture.store(initialState: Fixture.stateWithRoomSettings(settingsTitle: "강릉 여행"))
        let settingsID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: settingsID, action: .roomSettings(.delegate(.coverEditRequested))))) {
            $0.path[id: 2] = .roomCoverEdit(RoomCoverEditFeature.State(
                roomID: Fixture.card.room.id,
                title: "강릉 여행",
                memberCount: Fixture.card.memberCount,
                cover: Fixture.card.room.cover
            ))
        }
    }

    /// 인원수는 상세 조회 결과 → 홈 카드 → 0 순서로 고른다.
    @Test("커버 수정의 인원수는 상세 조회 후면 상세의 멤버 수, 전이면 홈 카드 값, 둘 다 없으면 0이다")
    func coverEditMemberCountFallsBack() async throws {
        var loaded = RoomDetailFeature.State(room: Fixture.card.room)
        loaded.detail = .preview // 멤버 3명 — 홈 카드(4명)와 다르다
        struct Case {
            let detail: RoomDetailFeature.State
            let cards: IdentifiedArrayOf<RoomCard>
            let expected: Int
        }
        let cases = [
            Case(detail: loaded, cards: [Fixture.card], expected: RoomDetail.preview.members.count),
            Case(detail: RoomDetailFeature.State(room: Fixture.card.room), cards: [Fixture.card], expected: Fixture.card.memberCount),
            Case(detail: RoomDetailFeature.State(room: Fixture.card.room), cards: [], expected: 0)
        ]
        for testCase in cases {
            let store = Fixture.store(
                initialState: Fixture.stateWithRoomSettings(detail: testCase.detail, cards: testCase.cards)
            )
            store.exhaustivity = .off
            let settingsID = try #require(store.state.path.ids.last)

            await store.send(.path(.element(id: settingsID, action: .roomSettings(.delegate(.coverEditRequested)))))

            guard let topID = store.state.path.ids.last, case let .roomCoverEdit(edit) = store.state.path[id: topID] else {
                Issue.record("커버 수정이 쌓이지 않았다")
                continue
            }
            #expect(edit.memberCount == testCase.expected)
        }
    }

    @Test("커버를 저장하고 닫으면 커버 수정만 빠지고 스택 아래 방 상세의 커버가 새 커버가 된다")
    func savedCoverPropagatesToRoomDetail() async {
        let newCover = RoomCover(imageURL: URL(string: "https://cdn.example.com/cover.jpg"), sticker: nil)
        let store = Fixture.store(initialState: Fixture.stateWithCoverEdit(saved: newCover))
        let ids = Array(store.state.path.ids)

        await store.send(.path(.element(id: ids[2], action: .roomCoverEdit(.delegate(.closeTapped))))) {
            $0.path[id: ids[0], case: \.roomDetail]?.room = Fixture.card.room.withCover(newCover)
            $0.home.cards[id: Fixture.card.id] = RoomCard(
                room: Fixture.card.room.withCover(newCover),
                memberCount: Fixture.card.memberCount,
                thumbnailURLs: Fixture.card.thumbnailURLs,
                photoPrintCompletionCheckedAt: Fixture.card.photoPrintCompletionCheckedAt
            )
            $0.path.pop(from: ids[2])
        }
    }

    @Test("커버를 바꾸지 않고 닫으면 방 상세의 커버는 그대로다")
    func unchangedCoverLeavesRoomDetail() async {
        let store = Fixture.store(initialState: Fixture.stateWithCoverEdit(saved: Fixture.card.room.cover))
        let ids = Array(store.state.path.ids)

        await store.send(.path(.element(id: ids[2], action: .roomCoverEdit(.delegate(.closeTapped))))) {
            $0.path.pop(from: ids[2])
        }
    }

    @Test("방 설정·커버 수정을 닫으면 그 화면만 빠지고 아래 방 상세는 그대로다")
    func popsRoomSettingsAndCoverEdit() async {
        var initial = Fixture.stateWithRoomSettings()
        initial.path.append(.roomCoverEdit(RoomCoverEditFeature.State(
            roomID: Fixture.card.room.id, title: Fixture.card.room.title, memberCount: 4, cover: Fixture.card.room.cover
        )))
        let store = Fixture.store(initialState: initial)
        let ids = Array(store.state.path.ids)

        await store.send(.path(.element(id: ids[2], action: .roomCoverEdit(.delegate(.closeTapped))))) {
            $0.path.pop(from: ids[2])
        }
        await store.send(.path(.element(id: ids[1], action: .roomSettings(.delegate(.closeTapped))))) {
            $0.path.pop(from: ids[1])
        }
        #expect(store.state.path.count == 1)
    }
}

/// 커버 수정을 버튼이 아니라 스와이프로 닫은 경우 — 부모가 `.popFrom`에서 대신 저장한다.
@MainActor
@Suite("MainFeature — 커버 수정을 스와이프로 닫음")
struct MainFeatureCoverSwipeTests {

    @Test("바꾼 커버를 저장하지 않고 스와이프로 닫으면 새 커버를 미리 보여 주고 대신 저장한다")
    func swipeSavesUnsavedCover() async {
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        let store = Fixture.store(initialState: Fixture.stateWithUnsavedCoverEdit(edited: Fixture.editedCover))
        store.dependencies.updateRoomCoverUseCase = UpdateRoomCoverUseCase(run: { roomID, draft in
            drafts.withValue { $0.append((roomID, draft)) }
        })
        let ids = Array(store.state.path.ids)

        await store.send(.path(.popFrom(id: ids[2]))) {
            $0.path[id: ids[0], case: \.roomDetail]?.room = Fixture.card.room.withCover(Fixture.editedCover)
            $0.home.cards[id: Fixture.card.id] = Fixture.cardWithCover(Fixture.editedCover)
            $0.path.pop(from: ids[2])
        }
        // 저장이 끝나면 한 번 더 알린다 — 이미 새 커버라 상태는 그대로다.
        await store.receive(\.roomCoverSaved)

        #expect(drafts.value.map(\.0) == [Fixture.card.room.id])
        #expect(drafts.value.map(\.1) == [RoomCoverDraft(cover: Fixture.editedCover)])
    }

    /// 스와이프 직후 방 상세가 다시 보이며 재조회한다. 그 응답이 저장보다 먼저 처리되면 방 상세가 옛 커버로 덮인다.
    /// 그 상태에서 저장 성공이 오면 새 커버로 다시 맞춰야 한다.
    @Test("재조회가 옛 커버로 덮은 뒤 저장 성공이 오면 방 상세와 홈 카드를 새 커버로 다시 맞춘다")
    func savedCoverReappliesAfterStaleRefetch() async throws {
        // 재조회 결과로 옛 커버가 된 상태 = 방 상세·홈 카드가 처음 커버 그대로인 상태
        let store = Fixture.store(initialState: Fixture.stateWithRoomDetail())
        let detailID = try #require(store.state.path.ids.first)

        await store.send(.roomCoverSaved(roomID: Fixture.card.room.id, cover: Fixture.editedCover)) {
            $0.path[id: detailID, case: \.roomDetail]?.room = Fixture.card.room.withCover(Fixture.editedCover)
            $0.home.cards[id: Fixture.card.id] = Fixture.cardWithCover(Fixture.editedCover)
        }
    }

    @Test("커버를 바꾸지 않고 스와이프로 닫으면 저장하지 않는다")
    func swipeWithoutChangesSkipsSave() async {
        let store = Fixture.store(initialState: Fixture.stateWithUnsavedCoverEdit(edited: Fixture.card.room.cover))
        store.dependencies.updateRoomCoverUseCase = .testValue // 불리면 미구현 실패
        let ids = Array(store.state.path.ids)

        await store.send(.path(.popFrom(id: ids[2]))) {
            $0.path.pop(from: ids[2])
        }
    }

    @Test("스와이프로 맡긴 저장이 실패하면 방 상세와 홈 카드의 커버를 저장 전 값으로 되돌린다")
    func swipeSaveFailureRevertsCover() async {
        let store = Fixture.store(initialState: Fixture.stateWithUnsavedCoverEdit(edited: Fixture.editedCover))
        store.dependencies.updateRoomCoverUseCase = UpdateRoomCoverUseCase(run: { _, _ in throw RoomError.network })
        let ids = Array(store.state.path.ids)

        await store.send(.path(.popFrom(id: ids[2]))) {
            $0.path[id: ids[0], case: \.roomDetail]?.room = Fixture.card.room.withCover(Fixture.editedCover)
            $0.home.cards[id: Fixture.card.id] = Fixture.cardWithCover(Fixture.editedCover)
            $0.path.pop(from: ids[2])
        }
        await store.receive(\.roomCoverSaveFailed) {
            $0.path[id: ids[0], case: \.roomDetail]?.room = Fixture.card.room
            $0.home.cards[id: Fixture.card.id] = Fixture.card
        }
    }

    @Test("커버 수정이 아닌 화면을 스와이프로 닫으면 빼기만 한다")
    func swipeOnOtherScreenOnlyPops() async throws {
        var initial = Fixture.stateWithRoomDetail()
        initial.path.append(.chat(MainFeature.chatState(room: Fixture.card.room, profile: Fixture.profile)))
        let store = Fixture.store(initialState: initial)
        store.dependencies.updateRoomCoverUseCase = .testValue
        let chatID = try #require(store.state.path.ids.last)

        await store.send(.path(.popFrom(id: chatID))) {
            $0.path.pop(from: chatID)
        }
    }
}
