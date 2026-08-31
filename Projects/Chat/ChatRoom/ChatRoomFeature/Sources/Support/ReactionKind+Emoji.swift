import CHALLADesignSystem
import PhotoDomain

/// 사진에 달린 이모지 리액션을 그릴 때 쓰는 DS 이모지 에셋 매핑.
/// PhotoDetailFeature의 같은 매핑을 복사한 것 — Feature끼리 참조할 수 없어(규칙 3) 각자 둔다.
/// (DS는 도메인을 몰라야 해 매핑을 DS로 올리지 않는다. 리액션 10종은 거의 변하지 않아 복사 비용이 작다.)
extension ReactionKind {

    var emoji: CHALLAReactionEmoji {
        switch self {
        case .heart: .heart
        case .sparkle: .sparkle
        case .thumbsUp: .thumbsUp
        case .poop: .poop
        case .skull: .skull
        case .medal: .medal
        case .question: .question
        case .huh: .huh
        case .loveEyes: .loveEyes
        case .fire: .fire
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .heart: "하트"
        case .sparkle: "반짝"
        case .thumbsUp: "최고"
        case .poop: "똥"
        case .skull: "해골"
        case .medal: "메달"
        case .question: "물음표"
        case .huh: "당황"
        case .loveEyes: "하트 눈"
        case .fire: "불"
        }
    }
}
