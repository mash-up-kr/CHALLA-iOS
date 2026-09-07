import Foundation
import RoomDomain
import Testing

@Suite("RoomCover")
struct RoomCoverTests {

    private static let color = RoomCoverColor(id: 2, name: "라즈베리", hex: "FF1887")
    private static let sticker = RoomCoverSticker(id: 3, imageURL: nil, color: color)
    private static let imageURL = URL(string: "https://cdn.example.com/cover.jpg")!

    @Test("none은 사진·스티커가 없어 비어 있다")
    func noneIsEmpty() {
        #expect(RoomCover.none.imageURL == nil)
        #expect(RoomCover.none.sticker == nil)
        #expect(RoomCover.none.isEmpty)
    }

    @Test("사진이나 스티커 중 하나라도 있으면 비어 있지 않다")
    func notEmptyWithImageOrSticker() {
        #expect(!RoomCover(imageURL: Self.imageURL).isEmpty)
        #expect(!RoomCover(sticker: Self.sticker).isEmpty)
    }

    @Test("withCover는 커버만 바꾸고 나머지 값은 유지한다")
    func withCoverReplacesOnlyCover() {
        let cover = RoomCover(imageURL: Self.imageURL, sticker: Self.sticker)

        let updated = Room.previewShooting.withCover(cover)

        #expect(updated.cover == cover)
        #expect(updated.withCover(.none) == Room.previewShooting)
    }

    @Test("renamed는 커버를 유지한다")
    func renamedKeepsCover() {
        let room = Room.previewShooting.withCover(RoomCover(sticker: Self.sticker))

        let renamed = room.renamed(to: "강릉 여행")

        #expect(renamed.title == "강릉 여행")
        #expect(renamed.cover == room.cover)
    }

    @Test("Room 기본 커버는 none이다")
    func defaultCoverIsNone() {
        #expect(Room.previewShooting.cover == .none)
    }
}

@Suite("RoomCoverSticker")
struct RoomCoverStickerTests {

    private static let lemonade = RoomCoverColor(id: 1, name: "레몬에이드", hex: "D5F700")
    private static let raspberry = RoomCoverColor(id: 2, name: "라즈베리", hex: "FF1887")
    private static let option = RoomCoverStickerOption(
        id: 3,
        imageURL: URL(string: "https://cdn.example.com/stickers/3.svg")
    )

    @Test("선택지에 색을 입히면 도안 id·그림 주소는 그대로다")
    func optionBecomesStickerWithColor() {
        let sticker = Self.option.sticker(color: Self.lemonade)

        #expect(sticker.id == Self.option.id)
        #expect(sticker.imageURL == Self.option.imageURL)
        #expect(sticker.color == Self.lemonade)
    }

    @Test("색만 바꾸면 도안은 유지된다")
    func recoloredKeepsDesign() {
        let recolored = Self.option.sticker(color: Self.lemonade).recolored(Self.raspberry)

        #expect(recolored == Self.option.sticker(color: Self.raspberry))
    }
}

@Suite("RoomCoverDraft")
struct RoomCoverDraftTests {

    @Test("커버에서 만든 초안은 사진 URL·스티커 id·색 id를 그대로 옮긴다")
    func draftFromCover() {
        let color = RoomCoverColor(id: 2, name: "라즈베리", hex: "FF1887")
        let cover = RoomCover(
            imageURL: URL(string: "https://cdn.example.com/cover.jpg"),
            sticker: RoomCoverSticker(id: 3, imageURL: nil, color: color)
        )

        #expect(RoomCoverDraft(cover: cover) == RoomCoverDraft(imageURL: cover.imageURL, stickerID: 3, colorID: 2))
        #expect(RoomCoverDraft(cover: .none) == RoomCoverDraft())
    }
}

@Suite("RoomCoverOptions")
struct RoomCoverOptionsTests {

    @Test("preview는 스티커·색 7종이고 id가 1부터 이어진다")
    func previewHasSevenOfEach() {
        let options = RoomCoverOptions.preview

        #expect(options.stickers.map(\.id) == Array(1 ... 7))
        #expect(options.colors.map(\.id) == Array(1 ... 7))
        #expect(options.colors.map(\.hex) == ["D5F700", "FF1887", "FF4D01", "22F662", "10E6D8", "508EFF", "C67AFF"])
    }

    @Test("empty는 아무것도 없다")
    func emptyHasNothing() {
        #expect(RoomCoverOptions.empty.stickers.isEmpty)
        #expect(RoomCoverOptions.empty.colors.isEmpty)
    }
}
