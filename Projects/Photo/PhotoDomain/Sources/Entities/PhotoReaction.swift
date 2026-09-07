import Foundation

/// 사진에 붙는 스티커 한 장 = 한 유저가 **맨 처음** 남긴 이모지.
///
/// 정책(#71): 이모지는 인당 무제한으로 남길 수 있지만, 사진에 스티커로 붙는 것은
/// 그 유저가 처음 남긴 하나뿐이다(나머지는 채팅 히스토리로만 쌓인다). 그래서 스티커는 **유저당 하나**이며
/// 신원(`id`)도 유저다. 어떤 종류를 남겼는지(`kind`)는 스티커 글리프를 고르는 값이다.
/// 스티커 위치는 화면(`StickerLayout`)이 정한다 — 서버가 좌표를 주지 않아 배치 규칙은 도메인에 두지 않는다.
public struct PhotoReaction: Sendable, Hashable, Identifiable {

    public let kind: ReactionKind
    public let userID: String

    public var id: String {
        userID
    }

    public init(kind: ReactionKind, userID: String) {
        self.kind = kind
        self.userID = userID
    }
}
