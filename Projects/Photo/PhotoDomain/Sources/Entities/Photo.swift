import Foundation

/// 인화가 끝난 사진 한 장. 인화 전 필름은 `RoomDomain`이 다룬다.
public struct Photo: Identifiable, Sendable, Equatable {

    public let id: String
    public let imageURL: URL
    public let author: PhotoAuthor
    public let capturedAt: Date
    /// 사진에 붙는 스티커 = 유저당 하나(그 유저가 처음 남긴 이모지). 처음 남긴 순서대로 담는다.
    /// 이모지 자체는 무제한으로 남길 수 있고 나머지는 채팅 히스토리로만 쌓인다 (정책 #71).
    public let reactions: [PhotoReaction]
    /// 유저별로 남긴 리액션 종류 전체 — 리액션 바 칩의 "띠"에 쓴다(스티커는 첫 개뿐이지만 띠는 누른 종류 전부).
    /// 서버 재조회 때도 이 값이 복원돼야 재진입 시 띠가 유지된다.
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
        // 유저당 스티커는 하나 — 앞선 것(처음 남긴 것)을 남기고 뒤는 버린다. 순서는 유지한다.
        var seen = Set<PhotoReaction.ID>()
        self.reactions = reactions.filter { seen.insert($0.id).inserted }
        self.reactedKindsByUser = reactedKindsByUser
    }

    /// 이 유저가 이미 스티커를 남겼는지. 새 이모지가 스티커가 될지(첫 이모지인지) 판단에 쓴다.
    public func hasReacted(by userID: String) -> Bool {
        reactions.contains { $0.userID == userID }
    }

    /// 이 유저의 스티커(첫 이모지). 없으면 nil.
    public func reaction(by userID: String) -> PhotoReaction? {
        reactions.first { $0.userID == userID }
    }

    /// 이 유저가 남긴 리액션 종류 전부 (칩 띠용).
    public func reactedKinds(by userID: String) -> Set<ReactionKind> {
        reactedKindsByUser[userID] ?? []
    }

    /// 이 유저가 이 종류로 이미 리액션했는지 (재탭 무시·중복 방지 판단).
    public func hasReacted(_ kind: ReactionKind, by userID: String) -> Bool {
        reactedKinds(by: userID).contains(kind)
    }

    /// 리액션을 추가한 사본. 종류는 띠(`reactedKindsByUser`)에 쌓이고, 그 유저의 첫 이모지일 때만 스티커로 붙는다.
    /// 서버 응답 전에 화면을 먼저 바꿀 때 쓴다.
    public func addingReaction(_ kind: ReactionKind, by userID: String) -> Photo {
        var kinds = reactedKindsByUser
        kinds[userID, default: []].insert(kind)
        let newReactions = hasReacted(by: userID)
            ? reactions
            : reactions + [PhotoReaction(kind: kind, userID: userID)]
        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: newReactions, reactedKindsByUser: kinds
        )
    }

    /// 리액션을 뗀 사본. 낙관적으로 붙였던 걸 실패 시 되돌릴 때 쓴다.
    /// 뗀 종류가 그 유저의 스티커였으면 스티커도 함께 뗀다.
    public func removingReaction(_ kind: ReactionKind, by userID: String) -> Photo {
        var kinds = reactedKindsByUser
        kinds[userID]?.remove(kind)
        if kinds[userID]?.isEmpty == true {
            kinds[userID] = nil
        }

        var newReactions = reactions
        if reaction(by: userID)?.kind == kind {
            // 뗀 종류가 스티커였다. 남은 띠가 있으면(그 사이 성공한 다른 리액션 등) 하나를 새 스티커로 승격한다 —
            // 스티커 없이 칩 띠만 남는 상태를 막는다. 정확한 '첫' 순서는 서버 재조회로 정정된다.
            newReactions.removeAll { $0.userID == userID }
            if let promoted = kinds[userID]?.min(by: { $0.rawValue < $1.rawValue }) {
                newReactions.append(PhotoReaction(kind: promoted, userID: userID))
            }
        }

        return Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: newReactions, reactedKindsByUser: kinds
        )
    }

    /// 서버에서 뒤늦게 받은 리액션으로 스티커·칩 띠를 채운 사본.
    /// 목록엔 리액션이 없어, 사진을 펼칠 때 상세를 따로 받아 지연 반영할 때 쓴다.
    public func applyingReactions(_ reactions: PhotoReactions) -> Photo {
        Photo(
            id: id, imageURL: imageURL, author: author, capturedAt: capturedAt,
            reactions: reactions.stickers, reactedKindsByUser: reactions.reactedKindsByUser
        )
    }
}
