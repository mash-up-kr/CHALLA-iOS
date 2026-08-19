import PhotoDetailFeature
import PhotoDomain
import Testing

@Suite("리액션 스티커 배치 규칙")
struct StickerLayoutTests {

    /// 시안 실측 — 사진 358 × 477에 스티커 한 변 82.
    private let photoWidth = 358.0
    private let photoHeight = 477.0
    private let stickerSize = 82.0

    private func placements(of photo: Photo) -> [StickerPlacement] {
        StickerLayout.placements(for: photo).map(\.placement)
    }

    private func distance(_ lhs: StickerPlacement, _ rhs: StickerPlacement) -> Double {
        let dx = (lhs.xRatio - rhs.xRatio) * photoWidth
        let dy = (lhs.yRatio - rhs.yRatio) * photoHeight
        return (dx * dx + dy * dy).squareRoot()
    }

    private func photo(index: Int = 1, kinds: [ReactionKind] = ReactionKind.allCases) -> Photo {
        Fixture.photo(id: "photo-\(index)", reactions: kinds.map { Fixture.reaction($0, by: "user-me") })
    }

    @Test("같은 사진이면 늘 같은 자리 — 화면을 다시 그려도 스티커가 움직이지 않는다")
    func isDeterministic() {
        let subject = photo()

        #expect(placements(of: subject) == placements(of: subject))
    }

    @Test("사진·사람·종류 중 하나만 달라도 자리가 갈린다")
    func differsByInput() {
        let mine = placements(of: Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.clap, by: "user-me")]))
        let yours = placements(of: Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.clap, by: "user-you")]))
        let heart = placements(of: Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.heart, by: "user-me")]))
        let otherPhoto = placements(
            of: Fixture.photo(id: "photo-2", reactions: [Fixture.reaction(.clap, by: "user-me")])
        )

        #expect(mine != yours)
        #expect(mine != heart)
        #expect(mine != otherPhoto)
    }

    @Test("한 사진에 종류를 다 눌러도 스티커끼리 겹치지 않는다")
    func neverOverlaps() {
        for index in 0 ..< 50 {
            let spots = placements(of: photo(index: index))

            for (offset, spot) in spots.enumerated() {
                for other in spots[(offset + 1)...] {
                    #expect(
                        distance(spot, other) >= stickerSize,
                        "photo-\(index)에서 스티커 두 개가 \(Int(distance(spot, other)))pt 거리로 겹친다"
                    )
                }
            }
        }
    }

    @Test("여러 사람이 같은 종류를 남겨도 겹치지 않는다")
    func neverOverlapsAcrossUsers() {
        let subject = Fixture.photo(
            id: "photo-1",
            reactions: (0 ..< 5).map { Fixture.reaction(.clap, by: "user-\($0)") }
        )
        let spots = placements(of: subject)

        for (offset, spot) in spots.enumerated() {
            for other in spots[(offset + 1)...] {
                #expect(distance(spot, other) >= stickerSize)
            }
        }
    }

    @Test("스티커가 사진 밖으로 나가지 않는다")
    func staysInsidePhoto() {
        let marginX = stickerSize / 2 / photoWidth
        let marginY = stickerSize / 2 / photoHeight

        for index in 0 ..< 50 {
            for placement in placements(of: photo(index: index)) {
                #expect((marginX ... (1 - marginX)).contains(placement.xRatio))
                #expect((marginY ... (1 - marginY)).contains(placement.yRatio))
                #expect((-20 ... 12).contains(placement.angleDegrees))
            }
        }
    }

    @Test("스티커가 촬영자 표시를 가리지 않는다")
    func avoidsAuthorHeader() {
        // 촬영자 표시는 사진 위쪽 32에서 시작해 48 높이를 쓴다 (시안 실측).
        let headerBottom = (32.0 + 48.0) / photoHeight

        for index in 0 ..< 50 {
            for placement in placements(of: photo(index: index)) {
                let stickerTop = placement.yRatio - stickerSize / 2 / photoHeight
                #expect(stickerTop >= headerBottom, "photo-\(index)의 스티커가 촬영자 표시 위로 올라온다")
            }
        }
    }

    @Test("슬롯보다 리액션이 많아지면 앞자리에 다시 쌓인다")
    func stacksWhenSlotsRunOut() {
        let subject = Fixture.photo(
            id: "photo-1",
            reactions: (0 ..< 12).map { Fixture.reaction(.clap, by: "user-\($0)") }
        )

        #expect(StickerLayout.placements(for: subject).count == 12)
    }
}
