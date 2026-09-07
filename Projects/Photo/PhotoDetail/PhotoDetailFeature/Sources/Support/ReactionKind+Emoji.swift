import CHALLADesignSystem
import PhotoDomain

extension ReactionKind {

    /// 화면에 그리는 컬러 이모지 에셋(DS)
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

    /// VoiceOver가 읽을 이름.
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
