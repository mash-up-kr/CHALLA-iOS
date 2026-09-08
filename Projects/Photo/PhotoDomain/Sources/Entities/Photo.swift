import Foundation

/// 인화가 끝난 사진 한 장. 인화 전 필름은 `RoomDomain`이 다룬다.
public struct Photo: Identifiable, Sendable, Equatable {

    public let id: String
    public let imageURL: URL
    public let author: PhotoAuthor
    public let capturedAt: Date
    /// 생성 순서로 정렬된 리액션 스티커.
    public let reactions: [PhotoReaction]
    /// 사용자별 리액션 종류. 리액션 바의 선택 상태에 사용한다.
    public let reactedKindsByUser: [String: Set<ReactionKind>]

    public init(
        id: String,
        imageURL: URL,
        author: PhotoAuthor,
        capturedAt: Date,
        reactions: [PhotoReaction] = [],
        reactedKindsByUser: [String: Set<ReactionKind>] = [:]
    ) {
        self.id = id
        self.imageURL = imageURL
        self.author = author
        self.capturedAt = capturedAt
        // 같은 표시 ID의 중복을 제거한다.
        var seen = Set<PhotoReaction.ID>()
        self.reactions = reactions.filter { seen.insert($0.id).inserted }
        self.reactedKindsByUser = reactedKindsByUser
    }

    /// 이 유저가 남긴 리액션 종류 전부 (칩 띠용).
    public func reactedKinds(by userID: String) -> Set<ReactionKind> {
        reactedKindsByUser[userID] ?? []
    }

    /// 이 유저가 이 종류로 이미 리액션했는지 (칩 띠 표시 판단).
    public func hasReacted(_ kind: ReactionKind, by userID: String) -> Bool {
        reactedKinds(by: userID).contains(kind)
    }

    public func reaction(id reactionID: PhotoReaction.ID) -> PhotoReaction? {
        reactions.first { $0.id == reactionID }
    }

    /// 스티커와 사용자의 선택 종류를 추가한 사본.
    public func addingReaction(_ reaction: PhotoReaction) -> Photo {
        var kinds = reactedKindsByUser
        kinds[reaction.userID, default: []].insert(reaction.kind)

        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: reactions + [reaction], reactedKindsByUser: kinds
        )
    }

    /// 리액션을 제거한다. 같은 종류가 남아 있으면 선택 상태는 유지한다.
    public func removingReaction(id reactionID: PhotoReaction.ID) -> Photo {
        guard let target = reaction(id: reactionID) else { return self }

        let remaining = reactions.filter { $0.id != reactionID }
        var kinds = reactedKindsByUser
        let stillHasKind = remaining.contains { $0.userID == target.userID && $0.kind == target.kind }
        if !stillHasKind {
            kinds[target.userID]?.remove(target.kind)
            if kinds[target.userID]?.isEmpty == true {
                kinds[target.userID] = nil
            }
        }

        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: remaining, reactedKindsByUser: kinds
        )
    }

    /// 스티커 표시 ID를 유지하면서 삭제용 채팅 ID를 연결한다.
    public func attachingChatID(_ chatID: Int64, to reactionID: PhotoReaction.ID) -> Photo {
        let updated = reactions.map { reaction in
            reaction.id == reactionID ? reaction.attachingChatID(chatID) : reaction
        }

        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: updated, reactedKindsByUser: reactedKindsByUser
        )
    }

    /// 조회 결과를 반영하되 기존 스티커의 표시 ID는 유지한다.
    public func applyingReactions(_ reactions: PhotoReactions) -> Photo {
        var unmatched = self.reactions
        // 서버 조회 후에도 기존 스티커의 표시 ID와 위치를 유지한다.
        let stickers = reactions.stickers.map { server in
            let index = unmatched.firstIndex { $0.chatID != nil && $0.chatID == server.chatID }
                ?? unmatched.firstIndex {
                    $0.chatID == nil && $0.userID == server.userID && $0.kind == server.kind
                }
            guard let index else { return server }
            let existing = unmatched.remove(at: index)
            return PhotoReaction(
                id: existing.id, kind: server.kind, userID: server.userID, chatID: server.chatID
            )
        }
        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: stickers, reactedKindsByUser: reactions.reactedKindsByUser
        )
    }
}
