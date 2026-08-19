import SwiftUI

/// 사진 리액션 컬러 이모지. 리액션 바 칩용(130)과 사진 위 스티커용(200, 흰 테두리 포함) 두 에셋을 제공한다.
///
/// 리액션의 **뜻**은 도메인(`PhotoDomain.ReactionKind`)이 정하고, 여기선 **그림**만 안다 —
/// 둘을 잇는 매핑은 Feature가 한다(DS는 도메인을 모른다).
/// `template-rendering-intent`를 주지 않아 원색 이모지가 그대로 그려진다(tint 불가).
public enum CHALLAReactionEmoji: String, CaseIterable, Sendable {
    case heart
    case sparkle
    case thumbsUp
    case poop
    case skull
    case medal
    case question
    case huh
    case loveEyes
    case fire

    /// 리액션 바 칩용 (흰 테두리 없음).
    public var barImage: Image {
        Image("\(rawValue)Bar", bundle: .module)
    }

    /// 사진 위 스티커용 (흰 테두리 포함).
    public var stickerImage: Image {
        Image("\(rawValue)Sticker", bundle: .module)
    }
}
