import ComposableArchitecture
import Foundation

// 엣지 스와이프 pop이 도착할 화면을 정한다.
//
// 제스처는 뷰(`AppView`)가 직접 보내므로 자식 delegate를 거치지 않는다.
// 각 화면의 뒤로가기 delegate와 같은 전이를 유지해야 한다 —
// 전이를 고칠 때 `AppFeature.swift`의 delegate case와 함께 고친다.
//
// `.main` 안의 화면(방 상세·사진 상세·채팅·방 설정·커버 수정)은 NavigationStack이 스와이프를 스스로 처리하므로 여기 오지 않는다.

extension AppFeature {

    /// 지금 화면을 한 단계 되돌린다. pop할 부모가 없는 화면에서는 아무 일도 하지 않는다.
    func popCurrentScreen(_ state: inout State) -> Effect<Action> {
        switch state {

        case let .setting(screen):
            state = Self.returnToMain(profile: screen.profile, cards: screen.homeCards)
        case let .profileEdit(screen):
            // 뒤로가기(cancelled)와 같은 의미 — 편집 중 변경은 반영하지 않는다.
            state = .setting(SettingScreen(profile: screen.profile, homeCards: screen.homeCards))
        default:
            break
        }
        return .none
    }
}
