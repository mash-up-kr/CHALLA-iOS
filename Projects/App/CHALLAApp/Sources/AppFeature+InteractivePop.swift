import ComposableArchitecture
import Foundation
import HomeFeature
import RoomDetailFeature
import SettingFeature

// MARK: - 인터랙티브 pop

extension AppFeature {

    /// 엣지 스와이프로 현재 화면을 걷어낸다. 제스처는 뷰가 직접 보내므로 자식 delegate를 거치지 않아,
    /// 각 화면의 뒤로가기 case와 같은 전이를 여기서 되풀이한다 (수정 시 둘을 함께 고칠 것).
    func popCurrentScreen(_ state: inout State) -> Effect<Action> {
        switch state {
        case let .roomDetail(screen):
            state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
        case let .photoDetail(screen):
            state = .roomDetail(
                RoomDetailScreen(profile: screen.profile, room: screen.room, homeCards: screen.homeCards)
            )
        case let .chat(screen):
            state = .roomDetail(
                RoomDetailScreen(profile: screen.profile, room: screen.room, homeCards: screen.homeCards)
            )
        case let .roomSettings(screen):
            state = .roomDetail(RoomDetailScreen(
                profile: screen.profile,
                room: screen.room.renamed(to: screen.settings.title),
                homeCards: screen.homeCards
            ))
        case let .roomCoverEdit(screen):
            // 제스처는 뒤로가기 버튼의 저장을 건너뛴다 — 화면이 사라지면 그쪽 이펙트도 취소되므로 App이 대신 저장한다.
            // 올리는 중이던 사진은 URL이 없어 실리지 못한다 (업로드는 화면과 함께 끝난다).
            let edit = screen.coverEdit
            state = .roomSettings(RoomSettingsScreen(
                profile: screen.profile,
                room: screen.room.withCover(edit.cover),
                homeCards: screen.homeCards,
                memberCount: screen.memberCount
            ))
            if edit.hasChanges {
                return saveRoomCover(roomID: screen.room.id, cover: edit.cover, previous: edit.savedCover)
            }
        case let .setting(screen):
            state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
        case let .profileEdit(screen):
            // 뒤로가기(cancelled)와 같은 의미 — 편집 중 변경은 반영하지 않는다.
            state = .setting(SettingScreen(profile: screen.profile, homeCards: screen.homeCards))
        default:
            break
        }
        return .none
    }
}
