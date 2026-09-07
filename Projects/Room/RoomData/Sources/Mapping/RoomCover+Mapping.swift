import Foundation
import RoomDomain

extension RoomCoverDTO {

    func toDomain() -> RoomCover {
        RoomCover(
            imageURL: coverImageUrl.flatMap(URL.init(string:)),
            sticker: sticker?.toDomain()
        )
    }
}

extension StickerDTO {

    func toDomain() -> RoomCoverSticker {
        RoomCoverSticker(
            id: id,
            imageURL: imageUrl.flatMap(URL.init(string:)),
            color: color.toDomain()
        )
    }
}

extension ColorDTO {

    func toDomain() -> RoomCoverColor {
        RoomCoverColor(id: id, name: name, hex: hex)
    }
}

extension StickerOptionDTO {

    func toDomain() -> RoomCoverStickerOption {
        RoomCoverStickerOption(id: id, imageURL: imageUrl.flatMap(URL.init(string:)))
    }
}

extension CoverOptionsResponseDTO.Payload {

    func toDomain() -> RoomCoverOptions {
        RoomCoverOptions(
            stickers: stickers.map { $0.toDomain() },
            colors: colors.map { $0.toDomain() }
        )
    }
}
