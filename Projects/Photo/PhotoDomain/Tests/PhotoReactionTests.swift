import PhotoDomain
import Testing

@Suite("Photo 리액션 규칙 (스티커 + 칩 띠)")
struct PhotoReactionTests {

    @Test("첫 이모지는 스티커로 붙고 띠에도 들어간다")
    func addsFirstReaction() {
        let photo = PhotoFixture.photo()

        let updated = photo.addingReaction(.thumbsUp, by: "user-me")

        #expect(updated.reactions.count == 1)
        #expect(updated.reaction(by: "user-me")?.kind == .thumbsUp)
        #expect(updated.hasReacted(by: "user-me"))
        #expect(updated.reactedKinds(by: "user-me") == [.thumbsUp])
    }

    @Test("두 번째 이모지는 스티커는 그대로지만 띠에는 쌓인다")
    func secondReactionUpdatesBandNotSticker() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart, by: "user-me")])

        let updated = photo.addingReaction(.thumbsUp, by: "user-me")

        // 스티커는 첫 이모지(heart) 유지
        #expect(updated.reactions.count == 1)
        #expect(updated.reaction(by: "user-me")?.kind == .heart)
        // 띠는 둘 다
        #expect(updated.reactedKinds(by: "user-me") == [.heart, .thumbsUp])
    }

    @Test("이미 그 종류로 남겼는지 확인한다")
    func hasReactedKind() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart, by: "user-me")])

        #expect(photo.hasReacted(.heart, by: "user-me"))
        #expect(!photo.hasReacted(.thumbsUp, by: "user-me"))
    }

    @Test("스티커 종류를 떼면 스티커·띠 모두에서 빠진다")
    func removingStickerKind() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.thumbsUp, by: "user-me")])

        let updated = photo.removingReaction(.thumbsUp, by: "user-me")

        #expect(updated.reactions.isEmpty)
        #expect(updated.reactedKinds(by: "user-me").isEmpty)
    }

    @Test("스티커가 아닌 종류를 떼면 띠에서만 빠지고 스티커는 유지된다")
    func removingNonStickerKind() {
        let photo = PhotoFixture.photo(
            reactions: [PhotoFixture.reaction(.heart, by: "user-me")],
            reactedKindsByUser: ["user-me": [.heart, .thumbsUp]]
        )

        let updated = photo.removingReaction(.thumbsUp, by: "user-me")

        #expect(updated.reaction(by: "user-me")?.kind == .heart) // 스티커 유지
        #expect(updated.reactedKinds(by: "user-me") == [.heart])
    }

    @Test("남의 리액션은 건드리지 않는다")
    func keepsOtherUsersReaction() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.thumbsUp, by: "user-other")])

        let updated = photo.addingReaction(.heart, by: "user-me")

        #expect(updated.reactions.count == 2)
        #expect(updated.reaction(by: "user-other")?.kind == .thumbsUp)
        #expect(updated.reaction(by: "user-me")?.kind == .heart)
    }

    @Test("스티커는 유저당 하나 — 서버가 같은 유저를 여럿 줘도 처음 것만 남는다")
    func keepsFirstPerUserOnConstruction() {
        let reactions = [
            PhotoFixture.reaction(.heart, by: "user-me"),
            PhotoFixture.reaction(.thumbsUp, by: "user-me")
        ]

        let photo = PhotoFixture.photo(reactions: reactions)

        #expect(photo.reactions.count == 1)
        #expect(photo.reaction(by: "user-me")?.kind == .heart)
    }

    @Test("스티커 신원은 유저다")
    func reactionIdentity() {
        let mine = PhotoFixture.reaction(.thumbsUp, by: "user-me")
        let yours = PhotoFixture.reaction(.thumbsUp, by: "user-you")
        let myHeart = PhotoFixture.reaction(.heart, by: "user-me")

        #expect(mine.id != yours.id)
        #expect(mine.id == myHeart.id) // 같은 유저면 종류가 달라도 같은 스티커 자리
    }

    @Test("리액션을 바꿔도 사진의 나머지 값은 그대로다")
    func keepsPhotoIdentity() {
        let photo = PhotoFixture.photo()

        let updated = photo.addingReaction(.skull, by: "user-me")

        #expect(updated.id == photo.id)
        #expect(updated.imageURL == photo.imageURL)
        #expect(updated.author == photo.author)
        #expect(updated.capturedAt == photo.capturedAt)
    }
}
