@testable import PhotoDetailFeature
import PhotoDomain
import Testing

@Suite("리액션 스티커 배치 규칙")
struct StickerLayoutTests {

    @Test("생성 응답과 재조회 후에도 스티커 위치를 유지한다")
    func keepsPlacementAfterServerConfirmation() {
        let local = PhotoReaction(id: "local-1", kind: .heart, userID: "me")
        let original = Fixture.photo(id: "photo-1", reactions: [local])
        let confirmed = original.attachingChatID(1, to: local.id)
        let server = PhotoReactions(stickers: [PhotoReaction(chatID: 1, kind: .heart, userID: "me")])

        #expect(placements(of: original) == placements(of: confirmed))
        #expect(placements(of: original) == placements(of: confirmed.applyingReactions(server)))
        #expect(placements(of: original) == placements(of: original.applyingReactions(server)))
    }

    /// 서로 다른 리액션 `count`개가 붙은 사진.
    private func photo(id: String = "photo-1", count: Int) -> Photo {
        let reactions = (0 ..< count).map { index in
            Fixture.reaction(
                ReactionKind.allCases[index % ReactionKind.allCases.count],
                by: "user-\(index)",
                chatID: Int64(index + 1)
            )
        }
        return Fixture.photo(id: id, reactions: reactions)
    }

    private func placements(of photo: Photo) -> [StickerPlacement] {
        StickerLayout.placements(for: photo).map(\.placement)
    }

    @Test("개수 제한 없이 붙은 만큼 다 그린다")
    func drawsEverySticker() {
        #expect(placements(of: photo(count: 2)).count == 2)
        #expect(placements(of: photo(count: 12)).count == 12)
    }

    @Test("같은 사진·같은 리액션이면 늘 같은 자리")
    func isDeterministic() {
        let subject = photo(count: 5)

        #expect(placements(of: subject) == placements(of: subject))
    }

    @Test("리액션 하나를 떼도 남은 스티커 자리는 그대로다")
    func keepsPlacementsAfterRemoval() {
        let subject = photo(count: 4)
        let removedID = subject.reactions[1].id
        let before = StickerLayout.placements(for: subject)
            .filter { $0.reaction.id != removedID }

        let after = StickerLayout.placements(for: subject.removingReaction(id: removedID))

        #expect(before.map(\.placement) == after.map(\.placement))
    }

    @Test("사진이 다르면 같은 리액션도 다른 자리에 놓인다")
    func variesByPhoto() {
        let first = placements(of: photo(id: "photo-1", count: 3))
        let second = placements(of: photo(id: "photo-2", count: 3))

        #expect(first != second)
    }

    @Test("스티커가 잘리지 않도록 사진 안쪽에 놓는다")
    func staysInsidePhoto() {
        for placement in placements(of: photo(count: 20)) {
            #expect(placement.xRatio >= 0.20 && placement.xRatio <= 0.80)
            // 위쪽은 촬영자 표시를 피한다.
            #expect(placement.yRatio >= 0.28 && placement.yRatio <= 0.80)
            #expect(placement.angleDegrees >= -15 && placement.angleDegrees <= 15)
        }
    }
}
