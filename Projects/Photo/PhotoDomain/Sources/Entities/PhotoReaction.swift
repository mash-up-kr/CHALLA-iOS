import Foundation

/// 한 사람이 한 사진에 남긴 리액션 하나.
///
/// 한 사람이 같은 종류를 두 번 남길 수는 없어서 `종류 + 사람`이 곧 신원이다.
/// 스티커가 사진 어디에 붙는지는 화면이 정한다 (`PhotoDetailFeature.StickerLayout`) —
/// 서버가 좌표를 주지 않는 지금은 순수한 배치 규칙이라 도메인에 둘 것이 아니다.
public struct PhotoReaction: Sendable, Hashable, Identifiable {

    public let kind: ReactionKind
    public let userID: String

    public var id: String {
        "\(userID)-\(kind.rawValue)"
    }

    public init(kind: ReactionKind, userID: String) {
        self.kind = kind
        self.userID = userID
    }
}
