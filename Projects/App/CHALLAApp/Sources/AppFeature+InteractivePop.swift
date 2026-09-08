import ComposableArchitecture
import RoomDomain

// 엣지 스와이프 pop이 도착할 화면을 정한다.
//
// 제스처는 뷰(`AppView`)가 직접 보내므로 자식 delegate를 거치지 않는다.
// 각 화면의 뒤로가기 delegate와 같은 전이를 유지해야 한다 —
// 전이를 고칠 때 `AppFeature.swift`의 delegate case와 함께 고친다.

extension AppFeature {

    /// 지금 화면을 한 단계 되돌린다. pop할 부모가 없는 화면에서는 아무 일도 하지 않는다.
    func popCurrentScreen(_ state: inout State) {
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
        case let .setting(screen):
            state = .home(HomeScreen(profile: screen.profile, cards: screen.homeCards))
        case let .profileEdit(screen):
            // 뒤로가기(cancelled)와 같은 의미 — 편집 중 변경은 반영하지 않는다.
            state = .setting(SettingScreen(profile: screen.profile, homeCards: screen.homeCards))
        default:
            break
        }
    }
}
