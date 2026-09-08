@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("커버 DTO 매핑")
struct RoomCoverMappingTests {

    private static let raspberry = ColorDTO(id: 2, name: "라즈베리", hex: "#FF1887")
    private static let sticker = StickerDTO(id: 3, imageUrl: "https://img.example.com/s.png", color: raspberry)

    @Test("사진 URL·스티커·색이 도메인으로 옮겨진다")
    func mapsFullCover() {
        let cover = RoomCoverDTO(coverImageUrl: "https://img.example.com/c.jpg", sticker: Self.sticker).toDomain()

        #expect(cover.imageURL?.absoluteString == "https://img.example.com/c.jpg")
        #expect(cover.sticker == RoomCoverSticker(
            id: 3,
            imageURL: URL(string: "https://img.example.com/s.png"),
            color: RoomCoverColor(id: 2, name: "라즈베리", hex: "#FF1887")
        ))
    }

    @Test("둘 다 null이면 빈 커버다")
    func mapsNullsToEmpty() {
        #expect(RoomCoverDTO(coverImageUrl: nil, sticker: nil).toDomain() == .none)
    }

    @Test("깨진 사진 URL은 nil로 접고 스티커는 남는다")
    func dropsInvalidImageURL() {
        let cover = RoomCoverDTO(coverImageUrl: "", sticker: Self.sticker).toDomain()

        #expect(cover.imageURL == nil)
        #expect(cover.sticker?.id == 3)
    }

    @Test("옵션 응답은 스티커(색 없음)·색 순서를 그대로 유지한다")
    func mapsOptionsInOrder() {
        let lemonade = ColorDTO(id: 1, name: "레몬에이드", hex: "#D5F700")
        let payload = CoverOptionsResponseDTO.Payload(
            stickers: [
                StickerOptionDTO(id: 10, imageUrl: "https://img.example.com/a.png"),
                StickerOptionDTO(id: 20, imageUrl: nil)
            ],
            colors: [lemonade, Self.raspberry]
        )

        let options = payload.toDomain()

        #expect(options.stickers.map(\.id) == [10, 20])
        #expect(options.stickers[1].imageURL == nil)
        #expect(options.colors.map(\.id) == [1, 2])
    }

    @Test("실서버 옵션 응답 — 스티커에 color가 없어도 디코딩된다")
    func decodesLiveOptionsResponseWithoutStickerColor() throws {
        let json = ##"""
        {
          "room": {
            "stickers": [
              { "id": 1, "imageUrl": "https://s3/1.svg" },
              { "id": 2, "imageUrl": "https://s3/2.svg" }
            ],
            "colors": [{ "id": 1, "name": "lime", "hex": "#D5F700" }]
          }
        }
        """##

        let dto = try JSONDecoder().decode(CoverOptionsResponseDTO.self, from: Data(json.utf8))

        #expect(dto.room.stickers.map(\.id) == [1, 2])
        #expect(dto.room.colors.first?.name == "lime")
    }
}
