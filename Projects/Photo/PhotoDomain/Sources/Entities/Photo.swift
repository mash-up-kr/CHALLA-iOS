import Foundation

/// 인화가 끝난 사진 한 장. 인화 전 필름은 `RoomDomain`이 다룬다.
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
        // 한 사람이 같은 종류를 두 번 남길 수 없다. 서버가 중복으로 줘도 여기서 제거한다.
        var seen = Set<PhotoReaction.ID>()
        self.reactions = reactions.filter { seen.insert($0.id).inserted }
    }

    public func hasReaction(_ kind: ReactionKind, by userID: String) -> Bool {
        reactions.contains { $0.kind == kind && $0.userID == userID }
    }

    /// 리액션을 목표 상태(isOn)로 맞춘 사본을 반환한다. 서버 응답 전에 화면을 먼저 바꿀 때 쓴다.
    /// 토글이 아니라 목표 상태를 받는 이유: 실패해서 되돌릴 때 그 사이 들어온 변경을 덮어쓰지 않기 위해서다.
    public func settingReaction(_ kind: ReactionKind, by userID: String, isOn: Bool) -> Photo {
        var next = reactions.filter { !($0.kind == kind && $0.userID == userID) }
        if isOn {
            next.append(PhotoReaction(kind: kind, userID: userID))
        }
        return Photo(id: id, imageURL: imageURL, author: author, capturedAt: capturedAt, reactions: next)
    }
}
