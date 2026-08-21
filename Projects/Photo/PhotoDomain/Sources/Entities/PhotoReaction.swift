import Foundation

/// 한 사람이 한 사진에 남긴 리액션 하나.
///
/// 한 사람이 같은 종류를 두 번 남길 수 없어서 `종류 + 사람`이 id가 된다.
/// 스티커 위치는 화면(`StickerLayout`)이 정한다. 서버가 좌표를 주지 않아 배치 규칙은 도메인에 두지 않는다.
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
