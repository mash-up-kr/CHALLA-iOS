import PhotoDomain
import Testing

@Suite("Photo 리액션 규칙")
struct PhotoReactionTests {

    @Test("켜면 리액션이 붙는다")
    func addsReaction() {
        let photo = PhotoFixture.photo()

        let updated = photo.settingReaction(.thumbsUp, by: "user-me", isOn: true)

        #expect(updated.reactions.count == 1)
        #expect(updated.hasReaction(.thumbsUp, by: "user-me"))
    }

    @Test("끄면 리액션이 지워진다")
    func removesReaction() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.thumbsUp, by: "user-me")])

        let updated = photo.settingReaction(.thumbsUp, by: "user-me", isOn: false)

        #expect(updated.reactions.isEmpty)
    }

    @Test("같은 값을 두 번 적용해도 결과가 같다 — 재시도·되돌리기가 안전해야 한다")
    func isIdempotent() {
        let photo = PhotoFixture.photo()

        let once = photo.settingReaction(.heart, by: "user-me", isOn: true)
        let twice = once.settingReaction(.heart, by: "user-me", isOn: true)

        #expect(once == twice)
        #expect(twice.reactions.count == 1)
    }

    @Test("이미 없는 리액션을 꺼도 아무 일도 없다")
    func removingAbsentReactionIsNoop() {
        let photo = PhotoFixture.photo()

        let updated = photo.settingReaction(.skull, by: "user-me", isOn: false)

        #expect(updated == photo)
    }

    @Test("남이 남긴 같은 종류의 리액션은 건드리지 않는다")
    func keepsOtherUsersReaction() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.thumbsUp, by: "user-other")])

        let updated = photo.settingReaction(.thumbsUp, by: "user-me", isOn: true)

        #expect(updated.reactions.count == 2)
        #expect(updated.hasReaction(.thumbsUp, by: "user-other"))
        #expect(updated.hasReaction(.thumbsUp, by: "user-me"))
    }

    @Test("종류가 다르면 따로 쌓인다")
    func addsDifferentKinds() {
        let photo = PhotoFixture.photo()
            .settingReaction(.thumbsUp, by: "user-me", isOn: true)
            .settingReaction(.heart, by: "user-me", isOn: true)

        #expect(photo.reactions.count == 2)
        #expect(photo.hasReaction(.heart, by: "user-me"))
    }

    @Test("서버가 같은 리액션을 중복으로 줘도 하나만 남는다")
    func dropsDuplicateReactions() {
        let duplicated = [
            PhotoFixture.reaction(.thumbsUp, by: "user-me"),
            PhotoFixture.reaction(.thumbsUp, by: "user-me")
        ]

        let photo = PhotoFixture.photo(reactions: duplicated)

        #expect(photo.reactions.count == 1)
    }

    @Test("리액션 신원은 종류 + 사람이다")
    func reactionIdentity() {
        let mine = PhotoFixture.reaction(.thumbsUp, by: "user-me")
        let yours = PhotoFixture.reaction(.thumbsUp, by: "user-you")
        let myHeart = PhotoFixture.reaction(.heart, by: "user-me")

        #expect(mine.id != yours.id)
        #expect(mine.id != myHeart.id)
    }

    @Test("리액션을 바꿔도 사진의 나머지 값은 그대로다")
    func keepsPhotoIdentity() {
        let photo = PhotoFixture.photo()

        let updated = photo.settingReaction(.skull, by: "user-me", isOn: true)

        #expect(updated.id == photo.id)
        #expect(updated.imageURL == photo.imageURL)
        #expect(updated.author == photo.author)
        #expect(updated.capturedAt == photo.capturedAt)
    }
}
