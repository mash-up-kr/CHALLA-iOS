import Foundation

public struct RoomCoverOptions: Equatable, Sendable {

    public let stickers: [RoomCoverStickerOption]
    public let colors: [RoomCoverColor]

    public init(stickers: [RoomCoverStickerOption], colors: [RoomCoverColor]) {
        self.stickers = stickers
        self.colors = colors
    }

    public static let empty = RoomCoverOptions(stickers: [], colors: [])
}

public extension RoomCoverOptions {

    static let preview: RoomCoverOptions = {
        let colors: [RoomCoverColor] = [
            RoomCoverColor(id: 1, name: "레몬에이드", hex: "D5F700"),
            RoomCoverColor(id: 2, name: "라즈베리", hex: "FF1887"),
            RoomCoverColor(id: 3, name: "오렌지", hex: "FF4D01"),
            RoomCoverColor(id: 4, name: "라임", hex: "22F662"),
            RoomCoverColor(id: 5, name: "사이다", hex: "10E6D8"),
            RoomCoverColor(id: 6, name: "블루베리", hex: "508EFF"),
            RoomCoverColor(id: 7, name: "아사이볼", hex: "C67AFF")
        ]
        let stickers = colors.map { RoomCoverStickerOption(id: $0.id, imageURL: previewImageURL(id: $0.id)) }
        return RoomCoverOptions(stickers: stickers, colors: colors)
    }()

    /// 그림은 서버에만 있어 프리뷰·데모도 실제 주소를 쓴다 — 오프라인이면 스티커만 비어 보인다.
    private static func previewImageURL(id: Int64) -> URL? {
        URL(string: "https://challa-storage.s3.ap-northeast-2.amazonaws.com/cover-stickers/\(id).svg")
    }
}
