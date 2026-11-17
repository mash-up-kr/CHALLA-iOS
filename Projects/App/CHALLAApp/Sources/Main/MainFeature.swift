import ChatRoomFeature
import ComposableArchitecture
import Foundation
import HomeFeature
import PhotoDetailFeature
import PhotoDomain
import RoomDetailFeature
import RoomDomain
import UserDomain

/// 로그인 뒤 화면 전부를 맡는 리듀서 — 홈이 항상 맨 아래에 있고, 그 위로 화면을 쌓고(push) 뺀다(pop).
///
/// `AppFeature`가 enum으로 화면을 "교체"하던 것과 달리 이전 화면이 살아 있다.
/// 뒤로 갈 때 홈·방 상세를 다시 만들지 않으므로, 그러기 위해 profile·cards를 실어 나를 필요도 없다.
///
/// 아직 enum 교체로 남아 있는 화면(설정·프로필 편집·카메라)은
/// `AppFeature`가 이 리듀서의 Action을 엿보고 처리한다 — 단계 3~4에서 이쪽으로 옮겨 온다.
@Reducer
public struct MainFeature {

    // MARK: - Path

    /// 홈 위에 쌓일 수 있는 화면. 화면 하나 추가 = 여기 case 1줄 + `MainView` destination 1줄.
    @Reducer
    public enum Path {
        case roomDetail(RoomDetailFeature)
        case photoDetail(PhotoDetailFeature)
        case chat(ChatRoomFeature)
        case roomSettings(RoomSettingsFeature)
        case roomCoverEdit(RoomCoverEditFeature)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        /// 내 프로필. 사진 상세·채팅 State를 만들 때(현재 사용자 id) 쓴다.
        /// 옛 포장 struct들이 저마다 들고 다니던 값을 여기 한 곳에만 둔다.
        public var profile: UserProfile
        /// 스택 맨 아래. 항상 있다.
        public var home: HomeFeature.State
        /// 홈 위에 쌓인 화면들. 비어 있으면 홈이 보인다. 원소마다 TCA가 id(`StackElementID`)를 붙인다.
        public var path = StackState<Path.State>()

        /// `cards`는 옛 enum 화면(설정·카메라…)에서 돌아올 때 직전 목록을 시딩하는 값 —
        /// 재조회가 끝나기 전에도 홈이 비어 보이지 않게 한다. 단계 4가 끝나면 쓸 곳이 없다.
        public init(
            profile: UserProfile,
            cards: IdentifiedArrayOf<RoomCard> = [],
            path: StackState<Path.State> = StackState()
        ) {
            self.profile = profile
            var home = HomeFeature.State(
                nickname: profile.nickname ?? "",
                profileImageURL: profile.imageURL
            )
            home.cards = cards
            self.home = home
            self.path = path
        }
    }

    // MARK: - Action

    public enum Action {
        case home(HomeFeature.Action)
        /// 스택 안 화면들의 Action 통로. push·popFrom·각 화면의 Action(`.element(id:action:)`)이 전부 여기로 온다.
        case path(StackActionOf<Path>)
        /// 화면 밖(참여 토스트)에서 방을 열어 달라는 요청. 쌓인 화면을 비우고 그 방 상세를 쌓는다.
        case roomOpenRequested(Room)
        /// 스와이프로 닫으며 맡긴 커버 저장이 실패했다 — 미리 끼워 둔 커버를 저장 전 값으로 되돌린다.
        case roomCoverSaveFailed(roomID: Room.ID, previousCover: RoomCover)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.updateRoomCoverUseCase) var updateRoomCoverUseCase

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        // 홈은 optional도 enum도 아닌 "항상 있는" 자식이라 Scope로 연결한다.
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {

            // MARK: - 홈에서

            // 목록에서 고른 방, 방금 만든 방, 초대 코드로 들어간 방 모두 상세로 들어간다 (push = append).
            case let .home(.delegate(.roomSelected(card))),
                 let .home(.delegate(.roomCreated(card))),
                 let .home(.delegate(.roomJoined(card))):
                state.path.append(.roomDetail(RoomDetailFeature.State(room: card.room)))
                return .none

            case let .roomOpenRequested(room):
                state.path.removeAll()
                state.path.append(.roomDetail(RoomDetailFeature.State(room: room)))
                return .none

            // MARK: - 방 상세에서

            // 뒤로가기 버튼. 홈은 아래에 그대로 있으니 "새로 만들기"가 없다.
            case let .path(.element(id: id, action: .roomDetail(.delegate(.closeTapped)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .roomDetail(.delegate(.chatTapped)))):
                guard case let .roomDetail(detail) = state.path[id: id] else { return .none }
                state.path.append(.chat(Self.chatState(room: detail.room, profile: state.profile)))
                return .none

            // 슬롯의 사진을 탭 — 그 사진을 펼친 채 사진 상세로 들어간다.
            case let .path(.element(id: id, action: .roomDetail(.delegate(.photoTapped(photoID))))):
                guard case let .roomDetail(detail) = state.path[id: id] else { return .none }
                state.path.append(.photoDetail(
                    Self.photoDetailState(room: detail.room, initialPhotoID: photoID, profile: state.profile)
                ))
                return .none

            // MARK: - 사진 상세·채팅에서

            // 닫기 버튼. 스와이프 뒤로가기는 NavigationStack이 `.path(.popFrom(id:))`를 보내
            // `.forEach`가 처리하므로 여기 오지 않는다 — 버튼이든 스와이프든 결과는 같다.
            case let .path(.element(id: id, action: .photoDetail(.delegate(.closeRequested)))),
                 let .path(.element(id: id, action: .chat(.delegate(.closeRequested)))):
                state.path.pop(from: id)
                return .none

            // MARK: - 방 상세 → 방 설정

            case let .path(.element(id: id, action: .roomDetail(.delegate(.settingsTapped)))):
                guard case let .roomDetail(detail) = state.path[id: id] else { return .none }
                state.path.append(.roomSettings(
                    RoomSettingsFeature.State(roomID: detail.room.id, title: detail.room.title)
                ))
                return .none

            // MARK: - 방 설정에서 이름 변경

            // 방 설정은 자기 이름 행만 고친다. 아래에 살아 있는 화면들은 MainFeature가 같은 액션을 엿보고 고친다.
            // 서버가 저장한 이름이 실려 오므로 다시 조회하지 않는다.
            case let .path(.element(id: id, action: .roomSettings(.rename(.presented(.delegate(.renamed(name))))))):
                guard case let .roomSettings(settings) = state.path[id: id] else { return .none }
                state.updateRoom(id: settings.roomID) { $0.renamed(to: name) }
                return .none

            // MARK: - 방 설정 → 커버 수정

            // 방 설정은 방 이름만 안다. 커버·인원수는 스택 아래에 살아 있는 그 방의 상세에서 읽는다.
            case let .path(.element(id: id, action: .roomSettings(.delegate(.coverEditRequested)))):
                guard case let .roomSettings(settings) = state.path[id: id],
                      let detail = state.roomDetail(roomID: settings.roomID)
                else { return .none }
                state.path.append(.roomCoverEdit(RoomCoverEditFeature.State(
                    roomID: settings.roomID,
                    // 설정에서 이름을 바꿨을 수 있어 설정 화면의 최신 이름을 쓴다.
                    title: settings.title,
                    // 커버 미리보기가 그릴 인원수. 상세 조회 전이면 홈 카드 값으로 메운다.
                    memberCount: detail.detail?.members.count
                        ?? state.home.cards[id: settings.roomID]?.memberCount
                        ?? 0,
                    cover: detail.room.cover
                )))
                return .none

            // MARK: - 방 설정·커버 수정 닫기

            case let .path(.element(id: id, action: .roomSettings(.delegate(.closeTapped)))):
                state.path.pop(from: id)
                return .none

            // 닫히는 순간의 savedCover = 서버에 저장된 커버. 바꾸지 않았거나 저장을 포기했으면 처음 커버 그대로라
            // 그대로 끼워도 아무것도 안 바뀐다. 빼기 전에 읽어야 한다 — 빼고 나면 그 원소가 없다.
            case let .path(.element(id: id, action: .roomCoverEdit(.delegate(.closeTapped)))):
                guard case let .roomCoverEdit(edit) = state.path[id: id] else { return .none }
                state.updateRoom(id: edit.roomID) { $0.withCover(edit.savedCover) }
                state.path.pop(from: id)
                return .none

            // MARK: - 커버 수정을 스와이프로 닫음

            // 스와이프는 뒤로 버튼을 거치지 않아 커버 수정이 스스로 저장하지 못한다 — 화면이 빠지면 그쪽 이펙트도 취소된다.
            // popFrom은 이 Reduce가 먼저 받고 .forEach가 그다음에 원소를 빼므로, 여기서는 편집값을 아직 읽을 수 있다.
            // 올리는 중이던 사진은 URL이 없어 실리지 못한다 (업로드는 화면과 함께 끝난다).
            case let .path(.popFrom(id: id)):
                guard case let .roomCoverEdit(edit) = state.path[id: id], edit.hasChanges else { return .none }
                // 저장 전에 미리 새 커버로 보여 준다 (낙관 반영). 실패하면 아래 case가 되돌린다.
                state.updateRoom(id: edit.roomID) { $0.withCover(edit.cover) }
                return .run { [updateRoomCoverUseCase, roomID = edit.roomID, cover = edit.cover, previous = edit.savedCover] send in
                    do {
                        try await updateRoomCoverUseCase.run(roomID, RoomCoverDraft(cover: cover))
                    } catch {
                        await send(.roomCoverSaveFailed(roomID: roomID, previousCover: previous))
                    }
                }

            // 사용자는 이미 다른 화면이라 알리지 않는다 — 다음 조회가 서버 값을 다시 준다.
            case let .roomCoverSaveFailed(roomID, previousCover):
                state.updateRoom(id: roomID) { $0.withCover(previousCover) }
                return .none

            // 홈의 설정·카메라 요청과 방 상세의 카메라 요청은 아직 AppFeature가 enum 교체로 처리한다.
            case .home, .path:
                return .none
            }
        }
        // 스택의 각 원소에 해당 Feature를 실행한다. 원소의 id로 찾아 포장을 벗기고 자식 리듀서를 돌린다.
        .forEach(\.path, action: \.path)
    }
}

// MARK: - 스택 안 찾기

extension MainFeature.State {

    /// 스택에 쌓인 그 방의 상세. 방 설정·커버 수정이 커버·인원수를 읽을 때 쓴다.
    /// 지금 흐름에서 방 상세는 스택에 한 장뿐이다 — 방을 새로 열 때(토스트·초대 링크)는 스택을 먼저 비운다.
    /// 위에서부터 찾는 것은 방 설정 바로 아래의 상세를 고르려는 것이고, 한 장뿐이면 결과는 같다.
    func roomDetail(roomID: Room.ID) -> RoomDetailFeature.State? {
        for id in path.ids.reversed() {
            if case let .roomDetail(detail) = path[id: id], detail.room.id == roomID { return detail }
        }
        return nil
    }

    /// 그 방을 들고 있는 곳(스택 안 방 상세 전부 · 홈 목록의 카드)을 한 번에 고친다.
    /// 스택 원소와 카드는 값 타입이라 꺼내 고친 뒤 같은 자리에 다시 넣는다.
    mutating func updateRoom(id roomID: Room.ID, _ transform: (Room) -> Room) {
        for id in path.ids {
            guard case var .roomDetail(detail) = path[id: id], detail.room.id == roomID else { continue }
            detail.room = transform(detail.room)
            path[id: id] = .roomDetail(detail)
        }
        if let card = home.cards[id: roomID] {
            home.cards[id: roomID] = card.replacingRoom(transform(card.room))
        }
    }
}

// MARK: - 자식 State 조립

extension MainFeature {

    static func photoDetailState(
        room: Room,
        initialPhotoID: Photo.ID,
        profile: UserProfile
    ) -> PhotoDetailFeature.State {
        PhotoDetailFeature.State(
            roomID: room.id,
            roomTitle: room.title,
            // 리액션을 남기는 주체 = 지금 보는 사람. PhotoReaction.userID(String)와 맞춘다.
            currentUserID: String(profile.id),
            // 인화 완료 전이면 방 상세처럼 사진을 blur로 가린다.
            isPrinted: room.status == .printed,
            initialPhotoID: initialPhotoID
        )
    }

    static func chatState(room: Room, profile: UserProfile) -> ChatRoomFeature.State {
        ChatRoomFeature.State(
            roomID: room.id,
            roomTitle: room.title,
            // 내 메시지(오른쪽 흰 버블) 판별 기준.
            currentUserID: profile.id,
            // 낙관적으로 덧붙이는 내 메시지의 표시 이름.
            currentUserNickname: profile.nickname ?? "",
            isPrinted: room.status == .printed
        )
    }
}

// `@Reducer enum`이 만든 State는 Equatable을 자동으로 따르지 않아 파일 스코프에서 붙인다.
// 부모 State가 `StackState<Path.State>`를 담아서 Equatable이어야 한다.
extension MainFeature.Path.State: Equatable {}

private extension RoomCard {

    /// `RoomCard`는 전부 `let`이라 방만 바꾼 새 카드를 만든다.
    func replacingRoom(_ room: Room) -> RoomCard {
        RoomCard(
            room: room,
            memberCount: memberCount,
            thumbnailURLs: thumbnailURLs,
            photoPrintCompletionCheckedAt: photoPrintCompletionCheckedAt
        )
    }
}
