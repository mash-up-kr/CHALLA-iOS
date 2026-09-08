import Foundation

public struct RoomCoverColor: Identifiable, Equatable, Sendable {

    public let id: Int64
    public let name: String
    public let hex: String

    public init(id: Int64, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }
}

public struct RoomCoverSticker: Identifiable, Equatable, Sendable {

    public let id: Int64
    public let imageURL: URL?
    public let color: RoomCoverColor

    public init(id: Int64, imageURL: URL?, color: RoomCoverColor) {
        self.id = id
        self.imageURL = imageURL
        self.color = color
    }

    /// 도안은 그대로 두고 색만 바꾼 사본 (`Room.renamed(to:)`과 같은 이유 — 전 필드가 let이다).
    public func recolored(_ color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: id, imageURL: imageURL, color: color)
    }
}

/// 선택지 목록의 스티커. 색이 없다 — 색은 고를 때 붙고, 방 커버에 저장된 뒤에야 `RoomCoverSticker`가 된다.
public struct RoomCoverStickerOption: Identifiable, Equatable, Sendable {

    public let id: Int64
    public let imageURL: URL?

    public init(id: Int64, imageURL: URL?) {
        self.id = id
        self.imageURL = imageURL
    }

    /// 이 선택지에 색을 입혀 방 커버에 담을 스티커로 만든다.
    public func sticker(color: RoomCoverColor) -> RoomCoverSticker {
        RoomCoverSticker(id: id, imageURL: imageURL, color: color)
    }
}

public struct RoomCover: Equatable, Sendable {

    public var imageURL: URL?
    public var sticker: RoomCoverSticker?

    public init(imageURL: URL? = nil, sticker: RoomCoverSticker? = nil) {
        self.imageURL = imageURL
        self.sticker = sticker
    }

    public static let none = RoomCover()

    public var isEmpty: Bool {
        imageURL == nil && sticker == nil
    }
}
