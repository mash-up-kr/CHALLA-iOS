import Foundation

/// 사진 한 장의 리액션 묶음. 목록 API엔 리액션이 없어, 사진을 펼칠 때 이 값만 따로 받아 채운다.
public struct PhotoReactions: Sendable, Equatable {

    /// 사진 위 스티커 = 유저당 첫 이모지 하나 (처음 남긴 순서대로). 정책 #71.
    public let stickers: [PhotoReaction]
    /// 유저별로 남긴 리액션 종류 전부 — 리액션 바 칩의 "띠"용(재진입 시 복원).
    public let reactedKindsByUser: [String: Set<ReactionKind>]

    public init(
        stickers: [PhotoReaction] = [],
        reactedKindsByUser: [String: Set<ReactionKind>] = [:]
    ) {
        self.stickers = stickers
        self.reactedKindsByUser = reactedKindsByUser
    }
}
