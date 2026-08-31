import Foundation
import PhotoDomain

/// 테스트가 공유하는 사진 만들기 헬퍼.
enum PhotoFixture {

    static func photo(
        id: String = "photo-1",
        authorID: String = "user-author",
        reactions: [PhotoReaction] = [],
        reactedKindsByUser: [String: Set<ReactionKind>]? = nil
    ) -> Photo {
        // 명시 안 하면 스티커(reactions)에서 띠를 유도해 일관되게 만든다.
        let kinds = reactedKindsByUser ?? reactions.reduce(into: [String: Set<ReactionKind>]()) {
            $0[$1.userID, default: []].insert($1.kind)
        }
        return Photo(
            id: id,
            // 실제로 부르지 않는 주소라 파싱 실패 시 파일 URL로 떨어뜨린다 (force unwrap 금지 규칙).
            imageURL: URL(string: "https://example.com/\(id).jpg") ?? URL(fileURLWithPath: "/"),
            author: PhotoAuthor(id: authorID, nickname: "나는야멋쟁이토마토"),
            capturedAt: Date(timeIntervalSince1970: 1_784_000_040),
            reactions: reactions,
            reactedKindsByUser: kinds
        )
    }

    static func reaction(_ kind: ReactionKind = .thumbsUp, by userID: String = "user-me") -> PhotoReaction {
        PhotoReaction(kind: kind, userID: userID)
    }
}
