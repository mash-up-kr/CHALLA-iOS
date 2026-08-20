import PhotoDomain

extension ReactionKind {

    /// 화면에 그리는 글리프. Figma는 Noto Color Emoji 벡터지만 시스템 이모지로 대신한다 —
    /// 검수에서 차이가 확인되면 그때 SVG 에셋으로 바꾼다.
    var emoji: String {
        switch self {
        case .medal: "🏅"
        case .heart: "❤️"
        case .poop: "💩"
        case .clap: "👏"
        case .skull: "💀"
        }
    }

    /// VoiceOver가 읽을 이름.
    var accessibilityLabel: String {
        switch self {
        case .medal: "메달"
        case .heart: "하트"
        case .poop: "똥"
        case .clap: "박수"
        case .skull: "해골"
        }
    }
}
