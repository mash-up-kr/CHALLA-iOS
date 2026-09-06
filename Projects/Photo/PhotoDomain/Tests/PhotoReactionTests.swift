import PhotoDomain
import Testing

@Suite("Photo 리액션 규칙 (스티커 + 칩 띠)")
struct PhotoReactionTests {

    @Test("같은 종류의 서버 리액션도 채팅 ID별 표시 ID를 유지한다")
    func preservesDistinctStickerIDsOnRefresh() {
        let local = PhotoReaction(id: "local-1", kind: .heart, userID: "me", chatID: 2)
        let first = PhotoReaction(chatID: 1, kind: .heart, userID: "me")
        let photo = PhotoFixture.photo(reactions: [local, first])
        let refreshed = photo.applyingReactions(PhotoReactions(stickers: [
            first, PhotoReaction(chatID: 2, kind: .heart, userID: "me")
        ]))

        #expect(refreshed.reactions.map(\.id) == [first.id, local.id])
        #expect(refreshed.reactions.map(\.chatID) == [1, 2])
    }

    @Test("리액션을 남기면 스티커로 붙고 띠에도 들어간다")
    func addsReaction() {
        let photo = PhotoFixture.photo()

        let updated = photo.addingReaction(PhotoFixture.reaction(.thumbsUp, by: "user-me"))

        #expect(updated.reactions.count == 1)
        #expect(updated.reactedKinds(by: "user-me") == [.thumbsUp])
    }

    @Test("개수 제한이 없어 남긴 만큼 다 붙는다")
    func addsEveryReaction() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart, by: "user-me", chatID: 1)])

        let updated = photo
            .addingReaction(PhotoFixture.reaction(.thumbsUp, by: "user-me", chatID: 2))
            .addingReaction(PhotoFixture.reaction(.fire, by: "user-me", chatID: 3))

        #expect(updated.reactions.count == 3)
        #expect(updated.reactedKinds(by: "user-me") == [.heart, .thumbsUp, .fire])
    }

    @Test("이미 그 종류로 남겼는지 확인한다")
    func hasReactedKind() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart, by: "user-me")])

        #expect(photo.hasReacted(.heart, by: "user-me"))
        #expect(!photo.hasReacted(.thumbsUp, by: "user-me"))
    }

    @Test("스티커를 떼면 그 종류가 남지 않았을 때만 띠에서도 빠진다")
    func removingReaction() {
        let first = PhotoFixture.reaction(.heart, by: "user-me", chatID: 1)
        let second = PhotoFixture.reaction(.heart, by: "user-me", chatID: 2)
        let photo = PhotoFixture.photo(reactions: [first, second])

        let removedOne = photo.removingReaction(id: first.id)
        // heart가 하나 더 남아 있어 띠는 그대로다.
        #expect(removedOne.reactions.count == 1)
        #expect(removedOne.reactedKinds(by: "user-me") == [.heart])

        let removedBoth = removedOne.removingReaction(id: second.id)
        #expect(removedBoth.reactions.isEmpty)
        #expect(removedBoth.reactedKinds(by: "user-me").isEmpty)
    }

    @Test("없는 리액션을 떼면 아무것도 바뀌지 않는다")
    func removingUnknownReactionDoesNothing() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.heart, by: "user-me")])

        #expect(photo.removingReaction(id: "없는-id") == photo)
    }

    @Test("남의 리액션은 건드리지 않는다")
    func keepsOtherUsersReaction() {
        let photo = PhotoFixture.photo(reactions: [PhotoFixture.reaction(.thumbsUp, by: "user-other", chatID: 1)])

        let updated = photo.addingReaction(PhotoFixture.reaction(.heart, by: "user-me", chatID: 2))

        #expect(updated.reactions.count == 2)
        #expect(updated.reactedKinds(by: "user-other") == [.thumbsUp])
        #expect(updated.reactedKinds(by: "user-me") == [.heart])
    }

    @Test("같은 리액션이 두 번 들어오면 하나만 남는다")
    func dedupesSameReaction() {
        let reaction = PhotoFixture.reaction(.heart, by: "user-me", chatID: 7)

        let photo = PhotoFixture.photo(reactions: [reaction, reaction])

        #expect(photo.reactions.count == 1)
    }

    @Test("같은 사용자·종류라도 채팅 ID가 다르면 다른 스티커다")
    func reactionIdentity() {
        let first = PhotoFixture.reaction(.thumbsUp, by: "user-me", chatID: 1)
        let second = PhotoFixture.reaction(.thumbsUp, by: "user-me", chatID: 2)

        #expect(first.id != second.id)
    }

    @Test("서버 채팅 ID를 받아도 스티커 표시 ID는 유지한다")
    func attachesChatID() {
        let local = PhotoReaction(id: "local-1", kind: .fire, userID: "user-me")
        let photo = PhotoFixture.photo().addingReaction(local)

        let updated = photo.attachingChatID(42, to: local.id)

        #expect(updated.reactions.first?.chatID == 42)
        #expect(updated.reactions.first?.id == local.id)
    }

    @Test("리액션을 바꿔도 사진의 나머지 값은 그대로다")
    func keepsPhotoIdentity() {
        let photo = PhotoFixture.photo()

        let updated = photo.addingReaction(PhotoFixture.reaction(.skull, by: "user-me"))

        #expect(updated.id == photo.id)
        #expect(updated.imageURL == photo.imageURL)
        #expect(updated.author == photo.author)
        #expect(updated.capturedAt == photo.capturedAt)
    }
}
