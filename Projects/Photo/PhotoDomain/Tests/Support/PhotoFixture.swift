import Foundation
import PhotoDomain

/// 테스트가 공유하는 사진 만들기 헬퍼.
enum PhotoFixture {

    static func photo(
        id: String = "photo-1",
        authorID: String = "user-author",
        reactions: [PhotoReaction] = []
    ) -> Photo {
        Photo(
            id: id,
            // 실제로 부르지 않는 주소라 파싱 실패 시 파일 URL로 떨어뜨린다 (force unwrap 금지 규칙).
            imageURL: URL(string: "https://example.com/\(id).jpg") ?? URL(fileURLWithPath: "/"),
            author: PhotoAuthor(id: authorID, nickname: "나는야멋쟁이토마토"),
            capturedAt: Date(timeIntervalSince1970: 1_784_000_040),
            reactions: reactions
        )
    }

    static func reaction(_ kind: ReactionKind = .thumbsUp, by userID: String = "user-me") -> PhotoReaction {
        PhotoReaction(kind: kind, userID: userID)
    }
}
