import Foundation
import PhotoDomain
import Testing

@Suite("Photo 축소본 주소")
struct PhotoThumbnailTests {

    /// 사본을 만드는 메서드가 네 개라 하나만 빠뜨려도 그 사진만 원본을 받게 된다.
    /// 증상이 "어떤 사진만 느리다"로 나타나 눈으로 잡기 어렵다.
    @Test("리액션을 남기거나 지워도 축소본 주소를 잃지 않는다")
    func keepsThumbnailAcrossReactionEdits() {
        // 실제로 부르지 않는 주소라 파싱 실패 시 파일 URL로 떨어뜨린다 (force unwrap 금지 규칙).
        let thumbnail = URL(string: "https://cdn.test/1_thumbnail.jpg") ?? URL(fileURLWithPath: "/")
        let photo = Photo(
            id: "1",
            imageURL: URL(string: "https://cdn.test/1.jpg") ?? URL(fileURLWithPath: "/"),
            thumbnailURL: thumbnail,
            author: PhotoAuthor(id: "u1", nickname: "찰나둥이"),
            capturedAt: Date(timeIntervalSince1970: 0)
        )
        let reaction = PhotoReaction(chatID: 1, kind: .heart, userID: "me")
        let added = photo.addingReaction(reaction)

        #expect(added.thumbnailURL == thumbnail)
        #expect(added.attachingChatID(2, to: reaction.id).thumbnailURL == thumbnail)
        #expect(added.removingReaction(id: reaction.id).thumbnailURL == thumbnail)
        #expect(added.applyingReactions(PhotoReactions(stickers: [reaction])).thumbnailURL == thumbnail)
    }
}
