import PhotoDetailFeature
import PhotoDomain
import Testing

@Suite("리액션 스티커 배치 규칙")
struct StickerLayoutTests {

    private func photo(id: String = "photo-1", count: Int) -> Photo {
        let reactions = Array(ReactionKind.allCases.prefix(count)).enumerated().map { index, kind in
            Fixture.reaction(kind, by: "user-\(index)")
        }
        return Fixture.photo(id: id, reactions: reactions)
    }

    private func placements(of photo: Photo) -> [StickerPlacement] {
        let slots = StickerLayout.assignSlots(for: [photo], previous: [:])
        return StickerLayout.placements(for: photo, slots: slots).map(\.placement)
    }

    @Test("최대 3개까지만 그린다")
    func capsAtMaxCount() {
        #expect(StickerLayout.maxCount == 3)
        #expect(placements(of: photo(count: 10)).count == 3)
        #expect(placements(of: photo(count: 2)).count == 2)
    }

    @Test("같은 사진이면 늘 같은 자리")
    func isDeterministic() {
        let subject = photo(count: 3)
        #expect(placements(of: subject) == placements(of: subject))
    }

    @Test("서로 다른 자리에 놓여 겹치지 않는다")
    func doesNotOverlap() {
        let spots = placements(of: photo(count: 3))
        let unique = Set(spots.map { "\($0.xRatio)-\($0.yRatio)" })
        #expect(unique.count == spots.count, "같은 자리에 둘 이상 놓였다")
    }

    @Test("리액션을 떼도 남은 스티커 자리는 그대로다")
    func keepsPositionsWhenRemoved() {
        let all = [
            Fixture.reaction(.heart, by: "a"),
            Fixture.reaction(.skull, by: "b"),
            Fixture.reaction(.fire, by: "c")
        ]
        let full = Fixture.photo(id: "p", reactions: all)
        let removed = Fixture.photo(id: "p", reactions: [all[0], all[2]])

        let slotsFull = StickerLayout.assignSlots(for: [full], previous: [:])
        let slotsRemoved = StickerLayout.assignSlots(for: [removed], previous: slotsFull)

        let before = StickerLayout.placements(for: full, slots: slotsFull)
        let after = StickerLayout.placements(for: removed, slots: slotsRemoved)

        for (reaction, placement) in after {
            let original = before.first { $0.reaction.id == reaction.id }?.placement
            #expect(original == placement, "\(reaction.id) 자리가 바뀌었다")
        }
    }

    @Test("가장자리에 놓고 정중앙은 비운다")
    func usesEdgePositions() {
        for spot in placements(of: photo(count: 3)) {
            let onEdge = spot.xRatio <= 0.3 || spot.xRatio >= 0.75
            #expect(onEdge, "x=\(spot.xRatio)가 가운데에 있다")
        }
    }
}
