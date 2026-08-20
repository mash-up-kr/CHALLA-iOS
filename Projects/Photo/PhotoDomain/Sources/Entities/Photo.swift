import Foundation

/// 방에서 찍힌 사진 한 장.
/// 인화가 끝난 사진만 다룬다 — 인화 전 필름은 방의 상태라 `RoomDomain` 소관이다.
public struct Photo: Identifiable, Sendable, Equatable {

    public let id: String
    public let imageURL: URL
    public let author: PhotoAuthor
    public let capturedAt: Date
    /// 한 사람이 종류별로 하나씩 남긴다.
    public let reactions: [PhotoReaction]

    public init(
        id: String,
        imageURL: URL,
        author: PhotoAuthor,
        capturedAt: Date,
        reactions: [PhotoReaction] = []
    ) {
        self.id = id
        self.imageURL = imageURL
        self.author = author
        self.capturedAt = capturedAt
        // 한 사람이 같은 종류를 두 번 남길 수는 없다 — 서버가 중복으로 줘도 그 규칙을 여기서 지킨다.
        var seen = Set<PhotoReaction.ID>()
        self.reactions = reactions.filter { seen.insert($0.id).inserted }
    }

    public func hasReaction(_ kind: ReactionKind, by userID: String) -> Bool {
        reactions.contains { $0.kind == kind && $0.userID == userID }
    }

    /// 리액션을 목표 상태로 맞춘 사본. 서버 응답을 기다리는 동안 화면을 먼저 갱신하는 데 쓴다.
    /// 뒤집기가 아니라 목표 상태를 받는 이유는 실패한 요청을 되돌릴 때 중간에 들어온 변화를 덮어쓰지 않기 위해서다.
    public func settingReaction(_ kind: ReactionKind, by userID: String, isOn: Bool) -> Photo {
        var next = reactions.filter { !($0.kind == kind && $0.userID == userID) }
        if isOn {
            next.append(PhotoReaction(kind: kind, userID: userID))
        }
        return Photo(id: id, imageURL: imageURL, author: author, capturedAt: capturedAt, reactions: next)
    }
}
